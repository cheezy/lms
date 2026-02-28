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
  alias Lms.Training.Lesson

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
  Marks a lesson as completed for an enrollment.

  Sets `completed_at` to the current UTC time.
  Returns `{:error, changeset}` if the lesson was already completed.
  """
  def complete_lesson(%Enrollment{} = enrollment, lesson_id) do
    %LessonProgress{}
    |> LessonProgress.changeset(%{
      enrollment_id: enrollment.id,
      lesson_id: lesson_id,
      completed_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()
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

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
end
