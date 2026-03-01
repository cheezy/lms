defmodule Lms.Learning do
  @moduledoc """
  The Learning context.

  Manages enrollments and lesson progress tracking for the learning management system.
  """

  import Ecto.Query, warn: false
  alias Lms.Repo

  alias Lms.Learning.Enrollment
  alias Lms.Learning.LessonProgress
  alias Lms.Training.Chapter
  alias Lms.Training.Course
  alias Lms.Training.Lesson

  @enrollments_per_page 20

  ## Enrollments

  @doc """
  Enrolls an employee in a course.

  Automatically sets `enrolled_at` to the current UTC time.
  Returns `{:error, changeset}` if the employee is already enrolled.
  """
  def enroll_employee(attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put_new(:enrolled_at, DateTime.utc_now(:second))

    %Enrollment{}
    |> Enrollment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Enrolls multiple employees in a course.

  Returns `{successful, failed}` where successful is a list of created enrollments
  and failed is a list of `{user_id, changeset}` tuples.
  Skips employees already enrolled (does not send duplicate notifications).
  """
  def enroll_employees(user_ids, course_id, opts \\ %{}) when is_list(user_ids) do
    due_date = opts[:due_date]

    Enum.reduce(user_ids, {[], []}, fn user_id, {ok_acc, err_acc} ->
      attrs = %{user_id: user_id, course_id: course_id, due_date: due_date}

      case enroll_employee(attrs) do
        {:ok, enrollment} -> {[enrollment | ok_acc], err_acc}
        {:error, changeset} -> {ok_acc, [{user_id, changeset} | err_acc]}
      end
    end)
  end

  @doc """
  Returns the list of enrollments.

  ## Options

    * `:user_id` - Filter by user ID
    * `:course_id` - Filter by course ID
  """
  def list_enrollments(opts \\ %{}) do
    Enrollment
    |> maybe_filter_by(:user_id, opts[:user_id])
    |> maybe_filter_by(:course_id, opts[:course_id])
    |> preload([:user, :course])
    |> order_by([e], desc: e.enrolled_at)
    |> Repo.all()
  end

  @doc """
  Lists enrollments for a company with search, filter, sort, and pagination.

  ## Options

    * `:search` - Search by employee name or email (case-insensitive)
    * `:course_id` - Filter by course ID
    * `:status` - Filter by derived status: "not_started", "in_progress", "completed", "overdue"
    * `:sort_by` - Sort field: `:employee`, `:course`, `:progress`, `:due_date` (default: `:employee`)
    * `:sort_order` - Sort direction: `:asc` or `:desc` (default: `:asc`)
    * `:page` - Page number (default: `1`)

  Returns `{enrollments, total_count}` where each enrollment has `:progress` virtual field set.
  """
  def list_enrollments_for_company(company_id, opts \\ %{}) do
    base_query = build_company_enrollment_query(company_id, opts)
    total_count = Repo.aggregate(base_query, :count, :id)
    enrollments = fetch_enrollments(base_query, opts)

    {enrollments, total_count}
  end

  defp build_company_enrollment_query(company_id, opts) do
    Enrollment
    |> join(:inner, [e], u in assoc(e, :user), as: :user)
    |> join(:inner, [e], c in assoc(e, :course), as: :course)
    |> where([e, user: u], u.company_id == ^company_id)
    |> maybe_search_enrollment(opts[:search])
    |> maybe_filter_by(:course_id, opts[:course_id])
  end

  defp fetch_enrollments(base_query, opts) do
    sort_by = opts[:sort_by] || :employee
    sort_order = opts[:sort_order] || :asc
    page = max(opts[:page] || 1, 1)
    offset = (page - 1) * @enrollments_per_page

    base_query
    |> apply_enrollment_sort(sort_by, sort_order)
    |> limit(^@enrollments_per_page)
    |> offset(^offset)
    |> preload([:user, :course, :lesson_progress])
    |> Repo.all()
    |> Enum.map(&Map.put(&1, :progress, calculate_progress(&1)))
    |> maybe_filter_status_in_memory(opts[:status])
  end

  @doc """
  Returns the list of published courses for a company.
  """
  def list_published_courses(company_id) do
    Course
    |> where([c], c.company_id == ^company_id and c.status == :published)
    |> order_by([c], asc: c.title)
    |> Repo.all()
  end

  @doc """
  Derives the enrollment status based on progress and dates.

  Returns one of: `:not_started`, `:in_progress`, `:completed`, `:overdue`
  """
  def enrollment_status(%Enrollment{} = enrollment, progress) do
    cond do
      enrollment.completed_at != nil -> :completed
      overdue?(enrollment) -> :overdue
      progress > 0.0 -> :in_progress
      true -> :not_started
    end
  end

  @doc """
  Lists enrollments for a user with course and progress data.

  Returns enrollments with `:progress` virtual field set, course preloaded,
  and `:last_activity` set to the most recent lesson completion timestamp.
  """
  def list_user_enrollments(user_id) do
    Enrollment
    |> where([e], e.user_id == ^user_id)
    |> preload([:course, :lesson_progress])
    |> order_by([e], desc: e.enrolled_at)
    |> Repo.all()
    |> Enum.map(fn enrollment ->
      enrollment
      |> Map.put(:progress, calculate_progress(enrollment))
      |> Map.put(:last_activity, last_activity(enrollment))
      |> Map.put(:total_lessons, count_course_lessons(enrollment.course_id))
      |> Map.put(:completed_lessons, count_completed_lessons(enrollment.id))
    end)
  end

  defp last_activity(%Enrollment{lesson_progress: progress}) when is_list(progress) do
    case progress do
      [] -> nil
      records -> records |> Enum.max_by(& &1.completed_at, DateTime) |> Map.get(:completed_at)
    end
  end

  defp last_activity(_), do: nil

  @doc """
  Gets a single enrollment with lesson progress preloaded.

  Raises `Ecto.NoResultsError` if the Enrollment does not exist.
  """
  def get_enrollment!(id) do
    Repo.get!(Enrollment, id)
  end

  @doc """
  Gets a single enrollment with lesson progress and course preloaded.

  Raises `Ecto.NoResultsError` if the Enrollment does not exist.
  """
  def get_enrollment_with_progress!(id) do
    Enrollment
    |> Repo.get!(id)
    |> Repo.preload([:user, :course, :lesson_progress])
  end

  @doc """
  Calculates the progress percentage for an enrollment.

  Returns a float between 0.0 and 100.0 representing the percentage
  of lessons completed. Returns 0.0 if the course has no lessons.

  Uses SQL aggregation to avoid N+1 queries.
  """
  def calculate_progress(%Enrollment{} = enrollment) do
    total_lessons = count_course_lessons(enrollment.course_id)
    completed_lessons = count_completed_lessons(enrollment.id)

    if total_lessons == 0 do
      0.0
    else
      completed_lessons / total_lessons * 100.0
    end
  end

  @doc """
  Marks a lesson as completed for an enrollment and checks for course completion.

  Uses `Ecto.Multi` to atomically create the LessonProgress record and
  set `enrollment.completed_at` when all lessons are done.

  Returns `{:ok, %{lesson_progress: progress, enrollment: enrollment}}` on success,
  or `{:error, :lesson_progress, changeset, _}` if the lesson was already completed.
  """
  def complete_lesson(%Enrollment{} = enrollment, lesson_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:lesson_progress, fn _changes ->
      LessonProgress.changeset(%LessonProgress{}, %{
        enrollment_id: enrollment.id,
        lesson_id: lesson_id,
        completed_at: DateTime.utc_now(:second)
      })
    end)
    |> Ecto.Multi.run(:enrollment, fn _repo, _changes ->
      check_course_completion(enrollment)
    end)
    |> Repo.transaction()
  end

  @doc """
  Checks if all lessons in a course are completed and sets enrollment.completed_at.

  Returns `{:ok, enrollment}`. If already completed or not all lessons done,
  returns the enrollment unchanged.
  """
  def check_course_completion(%Enrollment{} = enrollment) do
    if enrollment.completed_at != nil do
      {:ok, enrollment}
    else
      total = count_course_lessons(enrollment.course_id)
      completed = count_completed_lessons(enrollment.id)

      if total > 0 and completed >= total do
        enrollment
        |> Ecto.Changeset.change(%{completed_at: DateTime.utc_now(:second)})
        |> Repo.update()
      else
        {:ok, enrollment}
      end
    end
  end

  @doc """
  Gets the enrollment for a user and course.

  Raises `Ecto.NoResultsError` if no enrollment exists.
  """
  def get_enrollment_for_user!(user_id, course_id) do
    Enrollment
    |> where([e], e.user_id == ^user_id and e.course_id == ^course_id)
    |> preload([:course, :lesson_progress])
    |> Repo.one!()
  end

  @doc """
  Returns true if the given lesson has been completed for the enrollment.
  """
  def lesson_completed?(%Enrollment{} = enrollment, lesson_id) do
    LessonProgress
    |> where([lp], lp.enrollment_id == ^enrollment.id and lp.lesson_id == ^lesson_id)
    |> Repo.exists?()
  end

  @doc """
  Returns a MapSet of completed lesson IDs for the given enrollment.
  """
  def completed_lesson_ids(%Enrollment{} = enrollment) do
    LessonProgress
    |> where([lp], lp.enrollment_id == ^enrollment.id)
    |> select([lp], lp.lesson_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Updates the last viewed lesson for an enrollment.
  """
  def update_last_lesson(%Enrollment{} = enrollment, lesson_id) do
    enrollment
    |> Ecto.Changeset.change(%{last_lesson_id: lesson_id})
    |> Repo.update()
  end

  @doc """
  Deletes an enrollment and all associated lesson progress.
  """
  def delete_enrollment(%Enrollment{} = enrollment) do
    Repo.delete(enrollment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking enrollment changes.
  """
  def change_enrollment(%Enrollment{} = enrollment, attrs \\ %{}) do
    Enrollment.changeset(enrollment, attrs)
  end

  ## Private helpers

  defp count_course_lessons(course_id) do
    Lesson
    |> join(:inner, [l], c in Chapter, on: l.chapter_id == c.id)
    |> where([_l, c], c.course_id == ^course_id)
    |> select([l], count(l.id))
    |> Repo.one()
  end

  defp count_completed_lessons(enrollment_id) do
    LessonProgress
    |> where([lp], lp.enrollment_id == ^enrollment_id)
    |> select([lp], count(lp.id))
    |> Repo.one()
  end

  defp maybe_filter_by(query, _field, nil), do: query

  defp maybe_filter_by(query, :user_id, user_id) do
    where(query, [e], e.user_id == ^user_id)
  end

  defp maybe_filter_by(query, :course_id, course_id) do
    where(query, [e], e.course_id == ^course_id)
  end

  defp maybe_search_enrollment(query, nil), do: query
  defp maybe_search_enrollment(query, ""), do: query

  defp maybe_search_enrollment(query, search) do
    search_term = "%#{search}%"
    where(query, [e, user: u], ilike(u.name, ^search_term) or ilike(u.email, ^search_term))
  end

  defp apply_enrollment_sort(query, :employee, order) do
    order_by(query, [e, user: u], [{^order, u.name}])
  end

  defp apply_enrollment_sort(query, :course, order) do
    order_by(query, [e, user: _u, course: c], [{^order, c.title}])
  end

  defp apply_enrollment_sort(query, :due_date, order) do
    order_by(query, [e], [{^order, e.due_date}])
  end

  defp apply_enrollment_sort(query, _field, order) do
    order_by(query, [e, user: u], [{^order, u.name}])
  end

  defp maybe_filter_status_in_memory(enrollments, nil), do: enrollments
  defp maybe_filter_status_in_memory(enrollments, ""), do: enrollments

  defp maybe_filter_status_in_memory(enrollments, status) do
    status_atom = String.to_existing_atom(status)
    Enum.filter(enrollments, fn e -> enrollment_status(e, e.progress) == status_atom end)
  end

  defp overdue?(%Enrollment{due_date: nil}), do: false

  defp overdue?(%Enrollment{completed_at: completed_at}) when completed_at != nil, do: false

  defp overdue?(%Enrollment{due_date: due_date}) do
    Date.compare(due_date, Date.utc_today()) == :lt
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
end
