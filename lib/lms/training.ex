defmodule Lms.Training do
  @moduledoc """
  The Training context.

  Manages courses, chapters, and lessons for the learning management system.
  """

  import Ecto.Query, warn: false
  alias Lms.Repo

  alias Lms.Training.Chapter
  alias Lms.Training.Course
  alias Lms.Training.Lesson

  ## Courses

  @doc """
  Returns the list of courses for a given company.

  ## Options

    * `:status` - Filter by status atom (e.g., `:draft`, `:published`, `:archived`)
  """
  def list_courses(company_id, opts \\ %{}) do
    Course
    |> where([c], c.company_id == ^company_id)
    |> maybe_filter_status(opts[:status])
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
  end

  @doc """
  Gets a single course.

  Raises `Ecto.NoResultsError` if the Course does not exist.
  """
  def get_course!(id), do: Repo.get!(Course, id)

  @doc """
  Gets a single course with its chapters and lessons preloaded.

  Raises `Ecto.NoResultsError` if the Course does not exist.
  """
  def get_course_with_contents!(id) do
    Course
    |> Repo.get!(id)
    |> Repo.preload(
      chapters: {
        from(ch in Chapter, order_by: ch.position),
        lessons: from(l in Lesson, order_by: l.position)
      }
    )
  end

  @doc """
  Creates a course.
  """
  def create_course(attrs \\ %{}) do
    %Course{}
    |> Course.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a course.
  """
  def update_course(%Course{} = course, attrs) do
    course
    |> Course.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a course.
  """
  def delete_course(%Course{} = course) do
    Repo.delete(course)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking course changes.
  """
  def change_course(%Course{} = course, attrs \\ %{}) do
    Course.changeset(course, attrs)
  end

  @doc """
  Publishes a draft course by setting its status to `:published`.

  Returns `{:error, :not_draft}` if the course is not in draft status.
  """
  def publish_course(%Course{status: :draft} = course) do
    course
    |> Ecto.Changeset.change(%{status: :published})
    |> Repo.update()
  end

  def publish_course(%Course{}), do: {:error, :not_draft}

  @doc """
  Archives a published course by setting its status to `:archived`.

  Returns `{:error, :not_published}` if the course is not in published status.
  """
  def archive_course(%Course{status: :published} = course) do
    course
    |> Ecto.Changeset.change(%{status: :archived})
    |> Repo.update()
  end

  def archive_course(%Course{}), do: {:error, :not_published}

  ## Chapters

  @doc """
  Lists chapters for a given course, ordered by position.
  """
  def list_chapters(course_id) do
    Chapter
    |> where([ch], ch.course_id == ^course_id)
    |> order_by([ch], asc: ch.position)
    |> Repo.all()
  end

  @doc """
  Gets a single chapter.

  Raises `Ecto.NoResultsError` if the Chapter does not exist.
  """
  def get_chapter!(id), do: Repo.get!(Chapter, id)

  @doc """
  Creates a chapter. Automatically assigns the next position if not provided.
  """
  def create_chapter(attrs \\ %{}) do
    attrs = maybe_assign_position(attrs, :course_id, Chapter)

    %Chapter{}
    |> Chapter.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a chapter.
  """
  def update_chapter(%Chapter{} = chapter, attrs) do
    chapter
    |> Chapter.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a chapter.
  """
  def delete_chapter(%Chapter{} = chapter) do
    Repo.delete(chapter)
  end

  @doc """
  Deletes a chapter and reorders remaining chapters in the course.
  """
  def delete_chapter_and_reorder(%Chapter{} = chapter) do
    Repo.transaction(fn ->
      {:ok, _} = Repo.delete(chapter)

      remaining_ids =
        Chapter
        |> where([ch], ch.course_id == ^chapter.course_id and ch.id != ^chapter.id)
        |> order_by([ch], asc: ch.position)
        |> select([ch], ch.id)
        |> Repo.all()

      {:ok, _} = reorder_chapters(chapter.course_id, remaining_ids)
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking chapter changes.
  """
  def change_chapter(%Chapter{} = chapter, attrs \\ %{}) do
    Chapter.changeset(chapter, attrs)
  end

  ## Lessons

  @doc """
  Lists lessons for a given chapter, ordered by position.
  """
  def list_lessons(chapter_id) do
    Lesson
    |> where([l], l.chapter_id == ^chapter_id)
    |> order_by([l], asc: l.position)
    |> Repo.all()
  end

  @doc """
  Gets a single lesson.

  Raises `Ecto.NoResultsError` if the Lesson does not exist.
  """
  def get_lesson!(id), do: Repo.get!(Lesson, id)

  @doc """
  Creates a lesson. Automatically assigns the next position if not provided.
  """
  def create_lesson(attrs \\ %{}) do
    attrs = maybe_assign_position(attrs, :chapter_id, Lesson)

    %Lesson{}
    |> Lesson.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a lesson.
  """
  def update_lesson(%Lesson{} = lesson, attrs) do
    lesson
    |> Lesson.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a lesson.
  """
  def delete_lesson(%Lesson{} = lesson) do
    Repo.delete(lesson)
  end

  @doc """
  Deletes a lesson and reorders remaining lessons in the chapter.
  """
  def delete_lesson_and_reorder(%Lesson{} = lesson) do
    Repo.transaction(fn ->
      {:ok, _} = Repo.delete(lesson)

      remaining_ids =
        Lesson
        |> where([l], l.chapter_id == ^lesson.chapter_id and l.id != ^lesson.id)
        |> order_by([l], asc: l.position)
        |> select([l], l.id)
        |> Repo.all()

      {:ok, _} = reorder_lessons(lesson.chapter_id, remaining_ids)
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lesson changes.
  """
  def change_lesson(%Lesson{} = lesson, attrs \\ %{}) do
    Lesson.changeset(lesson, attrs)
  end

  @doc """
  Moves a lesson to a different chapter. Reorders lessons in both the
  old and new chapters.
  """
  def move_lesson_to_chapter(%Lesson{} = lesson, new_chapter_id) do
    old_chapter_id = lesson.chapter_id

    Repo.transaction(fn ->
      # Assign lesson to new chapter with next position
      next_pos = next_position(Lesson, :chapter_id, new_chapter_id)

      {:ok, updated} =
        lesson
        |> Ecto.Changeset.change(%{chapter_id: new_chapter_id, position: next_pos})
        |> Repo.update()

      # Reorder remaining lessons in old chapter
      old_remaining =
        Lesson
        |> where([l], l.chapter_id == ^old_chapter_id and l.id != ^lesson.id)
        |> order_by([l], asc: l.position)
        |> select([l], l.id)
        |> Repo.all()

      {:ok, _} = reorder_lessons(old_chapter_id, old_remaining)

      updated
    end)
  end

  ## Position Management

  @doc """
  Reorders chapters within a course by updating their positions.

  Takes a list of chapter IDs in the desired order. All chapters must
  belong to the given course.
  """
  def reorder_chapters(course_id, chapter_ids) when is_list(chapter_ids) do
    reorder_items(Chapter, :course_id, course_id, chapter_ids)
  end

  @doc """
  Reorders lessons within a chapter by updating their positions.

  Takes a list of lesson IDs in the desired order. All lessons must
  belong to the given chapter.
  """
  def reorder_lessons(chapter_id, lesson_ids) when is_list(lesson_ids) do
    reorder_items(Lesson, :chapter_id, chapter_id, lesson_ids)
  end

  ## Private helpers

  defp maybe_assign_position(attrs, parent_key, schema) do
    attrs = normalize_attrs(attrs)

    if Map.has_key?(attrs, :position) do
      attrs
    else
      parent_id = attrs[parent_key]
      next_position = next_position(schema, parent_key, parent_id)
      Map.put(attrs, :position, next_position)
    end
  end

  defp next_position(_schema, _parent_key, nil), do: 0

  defp next_position(schema, parent_key, parent_id) do
    schema
    |> where([s], field(s, ^parent_key) == ^parent_id)
    |> select([s], max(s.position))
    |> Repo.one()
    |> case do
      nil -> 0
      max_pos -> max_pos + 1
    end
  end

  defp reorder_items(schema, parent_key, parent_id, ids) do
    offset = 1_000_000

    Repo.transaction(fn ->
      # First, shift all positions by a large offset to avoid unique constraint violations
      schema
      |> where([s], field(s, ^parent_key) == ^parent_id)
      |> Repo.update_all(inc: [position: offset])

      # Then assign final positions
      ids
      |> Enum.with_index()
      |> Enum.each(fn {id, index} ->
        schema
        |> where([s], s.id == ^id and field(s, ^parent_key) == ^parent_id)
        |> Repo.update_all(set: [position: index])
      end)
    end)
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, ""), do: query
  defp maybe_filter_status(query, status), do: where(query, [c], c.status == ^status)

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
end
