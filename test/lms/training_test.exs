defmodule Lms.TrainingTest do
  use Lms.DataCase, async: true

  import Lms.CompaniesFixtures
  import Lms.AccountsFixtures
  import Lms.TrainingFixtures

  alias Lms.Training
  alias Lms.Training.Chapter
  alias Lms.Training.Course
  alias Lms.Training.Lesson

  ## Courses

  describe "Course.statuses/0" do
    test "returns the list of valid statuses" do
      assert Course.statuses() == [:draft, :published, :archived]
    end
  end

  describe "list_courses/1" do
    test "returns all courses for a company" do
      company = company_fixture()
      course = course_fixture(%{company: company})

      assert Training.list_courses(company.id) == [course]
    end

    test "does not return courses from other companies" do
      company1 = company_fixture()
      company2 = company_fixture()
      course_fixture(%{company: company1})

      assert Training.list_courses(company2.id) == []
    end
  end

  describe "get_course!/1" do
    test "returns the course with given id" do
      course = course_fixture()
      assert Training.get_course!(course.id) == course
    end

    test "raises if course does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Training.get_course!(0) end
    end
  end

  describe "get_course_with_contents!/1" do
    test "returns the course with chapters and lessons preloaded" do
      course = course_fixture()
      chapter = chapter_fixture(%{course: course, position: 0})
      lesson = lesson_fixture(%{chapter: chapter, position: 0})

      result = Training.get_course_with_contents!(course.id)

      assert result.id == course.id
      assert length(result.chapters) == 1
      assert hd(result.chapters).id == chapter.id
      assert length(hd(result.chapters).lessons) == 1
      assert hd(hd(result.chapters).lessons).id == lesson.id
    end

    test "returns chapters and lessons ordered by position" do
      course = course_fixture()
      ch2 = chapter_fixture(%{course: course, position: 1})
      ch1 = chapter_fixture(%{course: course, position: 0})
      lesson_fixture(%{chapter: ch1, position: 1, title: "Second"})
      lesson_fixture(%{chapter: ch1, position: 0, title: "First"})

      result = Training.get_course_with_contents!(course.id)

      assert [first_ch, second_ch] = result.chapters
      assert first_ch.id == ch1.id
      assert second_ch.id == ch2.id
      assert [first_lesson, second_lesson] = first_ch.lessons
      assert first_lesson.title == "First"
      assert second_lesson.title == "Second"
    end
  end

  describe "create_course/1" do
    test "with valid attrs creates a course" do
      company = company_fixture()
      creator = user_fixture()

      attrs = %{
        title: "Elixir Basics",
        description: "Learn the fundamentals",
        company_id: company.id,
        creator_id: creator.id
      }

      assert {:ok, %Course{} = course} = Training.create_course(attrs)
      assert course.title == "Elixir Basics"
      assert course.description == "Learn the fundamentals"
      assert course.status == :draft
      assert course.company_id == company.id
      assert course.creator_id == creator.id
    end

    test "with invalid attrs returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Training.create_course(%{})
    end

    test "validates required fields" do
      assert {:error, changeset} = Training.create_course(%{description: "no title"})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "defaults status to draft" do
      company = company_fixture()
      attrs = %{title: "Test", company_id: company.id}

      assert {:ok, course} = Training.create_course(attrs)
      assert course.status == :draft
    end

    test "validates status enum values" do
      company = company_fixture()
      attrs = %{title: "Test", company_id: company.id, status: :invalid}

      assert {:error, changeset} = Training.create_course(attrs)
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "update_course/2" do
    test "with valid attrs updates the course" do
      course = course_fixture()
      attrs = %{title: "Updated Title", status: :published}

      assert {:ok, %Course{} = updated} = Training.update_course(course, attrs)
      assert updated.title == "Updated Title"
      assert updated.status == :published
    end

    test "with invalid attrs returns error changeset" do
      course = course_fixture()
      assert {:error, %Ecto.Changeset{}} = Training.update_course(course, %{title: ""})
    end
  end

  describe "delete_course/1" do
    test "deletes the course" do
      course = course_fixture()
      assert {:ok, %Course{}} = Training.delete_course(course)
      assert_raise Ecto.NoResultsError, fn -> Training.get_course!(course.id) end
    end

    test "cascade deletes chapters and lessons" do
      course = course_fixture()
      chapter = chapter_fixture(%{course: course, position: 0})
      lesson = lesson_fixture(%{chapter: chapter, position: 0})

      assert {:ok, %Course{}} = Training.delete_course(course)

      assert_raise Ecto.NoResultsError, fn -> Training.get_chapter!(chapter.id) end
      assert_raise Ecto.NoResultsError, fn -> Training.get_lesson!(lesson.id) end
    end
  end

  describe "change_course/2" do
    test "returns a changeset" do
      course = course_fixture()
      assert %Ecto.Changeset{} = Training.change_course(course)
    end
  end

  ## Chapters

  describe "list_chapters/1" do
    test "returns chapters for a course ordered by position" do
      course = course_fixture()
      ch2 = chapter_fixture(%{course: course, position: 1})
      ch1 = chapter_fixture(%{course: course, position: 0})

      assert Training.list_chapters(course.id) == [ch1, ch2]
    end

    test "does not return chapters from other courses" do
      course1 = course_fixture()
      course2 = course_fixture()
      chapter_fixture(%{course: course1, position: 0})

      assert Training.list_chapters(course2.id) == []
    end
  end

  describe "get_chapter!/1" do
    test "returns the chapter with given id" do
      chapter = chapter_fixture()
      assert Training.get_chapter!(chapter.id) == chapter
    end
  end

  describe "create_chapter/1" do
    test "with valid attrs creates a chapter" do
      course = course_fixture()
      attrs = %{title: "Getting Started", course_id: course.id, position: 0}

      assert {:ok, %Chapter{} = chapter} = Training.create_chapter(attrs)
      assert chapter.title == "Getting Started"
      assert chapter.position == 0
      assert chapter.course_id == course.id
    end

    test "with invalid attrs returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Training.create_chapter(%{})
    end

    test "auto-assigns position when not provided" do
      course = course_fixture()
      {:ok, ch1} = Training.create_chapter(%{title: "First", course_id: course.id})
      {:ok, ch2} = Training.create_chapter(%{title: "Second", course_id: course.id})

      assert ch1.position == 0
      assert ch2.position == 1
    end

    test "validates position is non-negative" do
      course = course_fixture()
      attrs = %{title: "Test", course_id: course.id, position: -1}

      assert {:error, changeset} = Training.create_chapter(attrs)
      assert %{position: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end
  end

  describe "update_chapter/2" do
    test "with valid attrs updates the chapter" do
      chapter = chapter_fixture()
      assert {:ok, %Chapter{} = updated} = Training.update_chapter(chapter, %{title: "Updated"})
      assert updated.title == "Updated"
    end

    test "with invalid attrs returns error changeset" do
      chapter = chapter_fixture()
      assert {:error, %Ecto.Changeset{}} = Training.update_chapter(chapter, %{title: ""})
    end
  end

  describe "delete_chapter/1" do
    test "deletes the chapter" do
      chapter = chapter_fixture()
      assert {:ok, %Chapter{}} = Training.delete_chapter(chapter)
      assert_raise Ecto.NoResultsError, fn -> Training.get_chapter!(chapter.id) end
    end

    test "cascade deletes lessons" do
      chapter = chapter_fixture()
      lesson = lesson_fixture(%{chapter: chapter, position: 0})

      assert {:ok, %Chapter{}} = Training.delete_chapter(chapter)
      assert_raise Ecto.NoResultsError, fn -> Training.get_lesson!(lesson.id) end
    end
  end

  describe "change_chapter/2" do
    test "returns a changeset" do
      chapter = chapter_fixture()
      assert %Ecto.Changeset{} = Training.change_chapter(chapter)
    end
  end

  ## Lessons

  describe "list_lessons/1" do
    test "returns lessons for a chapter ordered by position" do
      chapter = chapter_fixture()
      l2 = lesson_fixture(%{chapter: chapter, position: 1})
      l1 = lesson_fixture(%{chapter: chapter, position: 0})

      assert Training.list_lessons(chapter.id) == [l1, l2]
    end

    test "does not return lessons from other chapters" do
      ch1 = chapter_fixture()
      ch2 = chapter_fixture()
      lesson_fixture(%{chapter: ch1, position: 0})

      assert Training.list_lessons(ch2.id) == []
    end
  end

  describe "get_lesson!/1" do
    test "returns the lesson with given id" do
      lesson = lesson_fixture()
      assert Training.get_lesson!(lesson.id) == lesson
    end
  end

  describe "create_lesson/1" do
    test "with valid attrs creates a lesson" do
      chapter = chapter_fixture()

      attrs = %{
        title: "Introduction",
        content: %{"type" => "doc", "content" => [%{"type" => "paragraph"}]},
        chapter_id: chapter.id,
        position: 0
      }

      assert {:ok, %Lesson{} = lesson} = Training.create_lesson(attrs)
      assert lesson.title == "Introduction"
      assert lesson.content == %{"type" => "doc", "content" => [%{"type" => "paragraph"}]}
      assert lesson.position == 0
      assert lesson.chapter_id == chapter.id
    end

    test "with invalid attrs returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Training.create_lesson(%{})
    end

    test "stores content as map for TipTap JSON" do
      chapter = chapter_fixture()

      tiptap_content = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "heading",
            "attrs" => %{"level" => 1},
            "content" => [%{"type" => "text", "text" => "Hello"}]
          },
          %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "World"}]}
        ]
      }

      attrs = %{title: "Test", content: tiptap_content, chapter_id: chapter.id, position: 0}

      assert {:ok, lesson} = Training.create_lesson(attrs)
      assert lesson.content == tiptap_content
    end

    test "auto-assigns position when not provided" do
      chapter = chapter_fixture()
      {:ok, l1} = Training.create_lesson(%{title: "First", chapter_id: chapter.id})
      {:ok, l2} = Training.create_lesson(%{title: "Second", chapter_id: chapter.id})

      assert l1.position == 0
      assert l2.position == 1
    end

    test "validates position is non-negative" do
      chapter = chapter_fixture()
      attrs = %{title: "Test", chapter_id: chapter.id, position: -1}

      assert {:error, changeset} = Training.create_lesson(attrs)
      assert %{position: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end
  end

  describe "update_lesson/2" do
    test "with valid attrs updates the lesson" do
      lesson = lesson_fixture()
      new_content = %{"type" => "doc", "content" => [%{"type" => "paragraph"}]}

      assert {:ok, %Lesson{} = updated} =
               Training.update_lesson(lesson, %{title: "Updated", content: new_content})

      assert updated.title == "Updated"
      assert updated.content == new_content
    end

    test "with invalid attrs returns error changeset" do
      lesson = lesson_fixture()
      assert {:error, %Ecto.Changeset{}} = Training.update_lesson(lesson, %{title: ""})
    end
  end

  describe "delete_lesson/1" do
    test "deletes the lesson" do
      lesson = lesson_fixture()
      assert {:ok, %Lesson{}} = Training.delete_lesson(lesson)
      assert_raise Ecto.NoResultsError, fn -> Training.get_lesson!(lesson.id) end
    end
  end

  describe "change_lesson/2" do
    test "returns a changeset" do
      lesson = lesson_fixture()
      assert %Ecto.Changeset{} = Training.change_lesson(lesson)
    end
  end

  ## Position Management

  describe "reorder_chapters/2" do
    test "reorders chapters by updating positions" do
      course = course_fixture()
      ch1 = chapter_fixture(%{course: course, position: 0})
      ch2 = chapter_fixture(%{course: course, position: 1})
      ch3 = chapter_fixture(%{course: course, position: 2})

      assert {:ok, _} = Training.reorder_chapters(course.id, [ch3.id, ch1.id, ch2.id])

      chapters = Training.list_chapters(course.id)
      assert [first, second, third] = chapters
      assert first.id == ch3.id
      assert first.position == 0
      assert second.id == ch1.id
      assert second.position == 1
      assert third.id == ch2.id
      assert third.position == 2
    end
  end

  describe "reorder_lessons/2" do
    test "reorders lessons by updating positions" do
      chapter = chapter_fixture()
      l1 = lesson_fixture(%{chapter: chapter, position: 0})
      l2 = lesson_fixture(%{chapter: chapter, position: 1})
      l3 = lesson_fixture(%{chapter: chapter, position: 2})

      assert {:ok, _} = Training.reorder_lessons(chapter.id, [l3.id, l1.id, l2.id])

      lessons = Training.list_lessons(chapter.id)
      assert [first, second, third] = lessons
      assert first.id == l3.id
      assert first.position == 0
      assert second.id == l1.id
      assert second.position == 1
      assert third.id == l2.id
      assert third.position == 2
    end
  end

  ## Publishing and archiving

  describe "publish_course/1" do
    test "publishes a draft course" do
      course = course_fixture(%{status: :draft})
      assert {:ok, published} = Training.publish_course(course)
      assert published.status == :published
    end

    test "returns error when course is not draft" do
      course = course_fixture(%{status: :published})
      assert {:error, :not_draft} = Training.publish_course(course)
    end

    test "returns error when course is archived" do
      course = course_fixture(%{status: :published})
      {:ok, archived} = Training.archive_course(course)
      assert {:error, :not_draft} = Training.publish_course(archived)
    end
  end

  describe "archive_course/1" do
    test "archives a published course" do
      course = course_fixture(%{status: :published})
      assert {:ok, archived} = Training.archive_course(course)
      assert archived.status == :archived
    end

    test "returns error when course is not published" do
      course = course_fixture(%{status: :draft})
      assert {:error, :not_published} = Training.archive_course(course)
    end

    test "returns error when course is already archived" do
      course = course_fixture(%{status: :published})
      {:ok, archived} = Training.archive_course(course)
      assert {:error, :not_published} = Training.archive_course(archived)
    end
  end

  describe "list_courses/2 with status filter" do
    test "filters courses by status" do
      company = company_fixture()
      _draft = course_fixture(%{company: company, status: :draft})
      published = course_fixture(%{company: company, status: :published})

      courses = Training.list_courses(company.id, %{status: :published})
      assert length(courses) == 1
      assert hd(courses).id == published.id
    end

    test "returns all courses when no status filter" do
      company = company_fixture()
      course_fixture(%{company: company, status: :draft})
      course_fixture(%{company: company, status: :published})

      courses = Training.list_courses(company.id)
      assert length(courses) == 2
    end

    test "filters with empty string status returns all courses" do
      company = company_fixture()
      course_fixture(%{company: company, status: :draft})
      course_fixture(%{company: company, status: :published})

      courses = Training.list_courses(company.id, %{status: ""})
      assert length(courses) == 2
    end

    test "returns courses ordered by updated_at descending" do
      company = company_fixture()
      course1 = course_fixture(%{company: company, title: "First"})
      _course2 = course_fixture(%{company: company, title: "Second"})

      # Manually set course1's updated_at to be 1 hour in the future
      future =
        DateTime.utc_now(:second)
        |> DateTime.add(3600, :second)

      Course
      |> where([c], c.id == ^course1.id)
      |> Lms.Repo.update_all(set: [updated_at: future])

      courses = Training.list_courses(company.id)
      assert hd(courses).id == course1.id
    end
  end

  ## Edge cases

  describe "edge cases" do
    test "course without chapters is valid" do
      course = course_fixture()
      result = Training.get_course_with_contents!(course.id)
      assert result.chapters == []
    end

    test "chapter without lessons is valid" do
      chapter = chapter_fixture()
      loaded = chapter |> Lms.Repo.preload(:lessons)
      assert loaded.lessons == []
    end

    test "very long title is rejected" do
      company = company_fixture()
      long_title = String.duplicate("a", 256)

      assert {:error, changeset} =
               Training.create_course(%{title: long_title, company_id: company.id})

      assert %{title: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "create_chapter with keyword list attrs" do
      course = course_fixture()
      attrs = [title: "Keyword Chapter", course_id: course.id]

      assert {:ok, %Chapter{} = chapter} = Training.create_chapter(attrs)
      assert chapter.title == "Keyword Chapter"
      assert chapter.position == 0
    end

    test "create_lesson with keyword list attrs" do
      chapter = chapter_fixture()
      attrs = [title: "Keyword Lesson", chapter_id: chapter.id]

      assert {:ok, %Lesson{} = lesson} = Training.create_lesson(attrs)
      assert lesson.title == "Keyword Lesson"
      assert lesson.position == 0
    end

    test "create_chapter without parent_id gets position 0" do
      assert {:error, changeset} = Training.create_chapter(%{title: "No Parent"})
      # Without course_id, it should fail on validation but position gets 0
      assert %{course_id: _} = errors_on(changeset)
    end

    test "create_lesson without parent_id gets position 0" do
      assert {:error, changeset} = Training.create_lesson(%{title: "No Parent"})
      assert %{chapter_id: _} = errors_on(changeset)
    end

    test "change_course with attrs" do
      course = course_fixture()
      changeset = Training.change_course(course, %{title: "New Title"})
      assert %Ecto.Changeset{} = changeset
      assert Ecto.Changeset.get_change(changeset, :title) == "New Title"
    end

    test "change_chapter with attrs" do
      chapter = chapter_fixture()
      changeset = Training.change_chapter(chapter, %{title: "New Title"})
      assert %Ecto.Changeset{} = changeset
      assert Ecto.Changeset.get_change(changeset, :title) == "New Title"
    end

    test "change_lesson with attrs" do
      lesson = lesson_fixture()
      changeset = Training.change_lesson(lesson, %{title: "New Title"})
      assert %Ecto.Changeset{} = changeset
      assert Ecto.Changeset.get_change(changeset, :title) == "New Title"
    end

    test "reorder_chapters with empty list" do
      course = course_fixture()
      assert {:ok, _} = Training.reorder_chapters(course.id, [])
    end

    test "reorder_lessons with empty list" do
      chapter = chapter_fixture()
      assert {:ok, _} = Training.reorder_lessons(chapter.id, [])
    end
  end
end
