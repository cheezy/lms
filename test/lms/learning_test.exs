defmodule Lms.LearningTest do
  use Lms.DataCase, async: true

  import Lms.CompaniesFixtures
  import Lms.AccountsFixtures
  import Lms.TrainingFixtures
  import Lms.LearningFixtures

  alias Lms.Learning
  alias Lms.Learning.Enrollment
  alias Lms.Learning.LessonProgress

  defp create_course_with_lessons(_context \\ %{}) do
    company = company_fixture()
    creator = user_fixture(%{company: company})
    course = course_fixture(%{company: company, creator: creator})
    chapter = chapter_fixture(%{course: course})
    lesson1 = lesson_fixture(%{chapter: chapter})
    lesson2 = lesson_fixture(%{chapter: chapter})

    %{
      company: company,
      course: course,
      chapter: chapter,
      lesson1: lesson1,
      lesson2: lesson2
    }
  end

  describe "enroll_employee/1" do
    test "with valid attrs creates an enrollment" do
      user = user_fixture()
      course = course_fixture()

      assert {:ok, %Enrollment{} = enrollment} =
               Learning.enroll_employee(%{user_id: user.id, course_id: course.id})

      assert enrollment.user_id == user.id
      assert enrollment.course_id == course.id
      assert enrollment.enrolled_at
      assert enrollment.due_date == nil
      assert enrollment.completed_at == nil
    end

    test "with optional due_date" do
      user = user_fixture()
      course = course_fixture()
      due_date = ~D[2026-12-31]

      assert {:ok, %Enrollment{} = enrollment} =
               Learning.enroll_employee(%{
                 user_id: user.id,
                 course_id: course.id,
                 due_date: due_date
               })

      assert enrollment.due_date == due_date
    end

    test "auto-sets enrolled_at if not provided" do
      user = user_fixture()
      course = course_fixture()

      assert {:ok, %Enrollment{} = enrollment} =
               Learning.enroll_employee(%{user_id: user.id, course_id: course.id})

      assert enrollment.enrolled_at
    end

    test "prevents duplicate enrollment for same user and course" do
      user = user_fixture()
      course = course_fixture()

      assert {:ok, _enrollment} =
               Learning.enroll_employee(%{user_id: user.id, course_id: course.id})

      assert {:error, changeset} =
               Learning.enroll_employee(%{user_id: user.id, course_id: course.id})

      assert errors_on(changeset)[:user_id]
    end

    test "with missing user_id returns error changeset" do
      course = course_fixture()

      assert {:error, changeset} = Learning.enroll_employee(%{course_id: course.id})
      assert errors_on(changeset)[:user_id]
    end

    test "with missing course_id returns error changeset" do
      user = user_fixture()

      assert {:error, changeset} = Learning.enroll_employee(%{user_id: user.id})
      assert errors_on(changeset)[:course_id]
    end
  end

  describe "list_enrollments/1" do
    test "returns all enrollments" do
      enrollment = enrollment_fixture()

      enrollments = Learning.list_enrollments()
      assert length(enrollments) == 1
      assert hd(enrollments).id == enrollment.id
    end

    test "filters by user_id" do
      user = user_fixture()
      enrollment = enrollment_fixture(%{user: user})
      _other_enrollment = enrollment_fixture()

      enrollments = Learning.list_enrollments(%{user_id: user.id})
      assert length(enrollments) == 1
      assert hd(enrollments).id == enrollment.id
    end

    test "filters by course_id" do
      course = course_fixture()
      enrollment = enrollment_fixture(%{course: course})
      _other_enrollment = enrollment_fixture()

      enrollments = Learning.list_enrollments(%{course_id: course.id})
      assert length(enrollments) == 1
      assert hd(enrollments).id == enrollment.id
    end

    test "preloads user and course" do
      enrollment_fixture()

      [enrollment] = Learning.list_enrollments()
      assert %Lms.Accounts.User{} = enrollment.user
      assert %Lms.Training.Course{} = enrollment.course
    end

    test "returns empty list when no enrollments match" do
      assert [] == Learning.list_enrollments(%{user_id: -1})
    end
  end

  describe "get_enrollment!/1" do
    test "returns the enrollment" do
      enrollment = enrollment_fixture()

      fetched = Learning.get_enrollment!(enrollment.id)
      assert fetched.id == enrollment.id
    end

    test "raises for non-existent enrollment" do
      assert_raise Ecto.NoResultsError, fn ->
        Learning.get_enrollment!(-1)
      end
    end
  end

  describe "get_enrollment_with_progress!/1" do
    test "returns enrollment with preloaded associations" do
      enrollment = enrollment_fixture()

      fetched = Learning.get_enrollment_with_progress!(enrollment.id)
      assert fetched.id == enrollment.id
      assert %Lms.Accounts.User{} = fetched.user
      assert %Lms.Training.Course{} = fetched.course
      assert fetched.lesson_progress == []
    end

    test "preloads lesson progress records" do
      %{course: course, lesson1: lesson} = create_course_with_lessons()
      user = user_fixture()
      enrollment = enrollment_fixture(%{user: user, course: course})

      {:ok, _progress} = Learning.complete_lesson(enrollment, lesson.id)

      fetched = Learning.get_enrollment_with_progress!(enrollment.id)
      assert length(fetched.lesson_progress) == 1
      assert hd(fetched.lesson_progress).lesson_id == lesson.id
    end
  end

  describe "calculate_progress/1" do
    test "returns 0.0 when course has no lessons" do
      enrollment = enrollment_fixture()

      assert Learning.calculate_progress(enrollment) == 0.0
    end

    test "returns 0.0 when no lessons are completed" do
      %{course: course} = create_course_with_lessons()
      user = user_fixture()
      enrollment = enrollment_fixture(%{user: user, course: course})

      assert Learning.calculate_progress(enrollment) == 0.0
    end

    test "returns correct percentage for partial completion" do
      %{course: course, lesson1: lesson1} = create_course_with_lessons()
      user = user_fixture()
      enrollment = enrollment_fixture(%{user: user, course: course})

      {:ok, _} = Learning.complete_lesson(enrollment, lesson1.id)

      assert Learning.calculate_progress(enrollment) == 50.0
    end

    test "returns 100.0 when all lessons are completed" do
      %{course: course, lesson1: lesson1, lesson2: lesson2} = create_course_with_lessons()
      user = user_fixture()
      enrollment = enrollment_fixture(%{user: user, course: course})

      {:ok, _} = Learning.complete_lesson(enrollment, lesson1.id)
      {:ok, _} = Learning.complete_lesson(enrollment, lesson2.id)

      assert Learning.calculate_progress(enrollment) == 100.0
    end

    test "counts lessons across multiple chapters" do
      company = company_fixture()
      creator = user_fixture(%{company: company})
      course = course_fixture(%{company: company, creator: creator})
      chapter1 = chapter_fixture(%{course: course})
      chapter2 = chapter_fixture(%{course: course})
      lesson1 = lesson_fixture(%{chapter: chapter1})
      _lesson2 = lesson_fixture(%{chapter: chapter2})

      user = user_fixture(%{company: company})
      enrollment = enrollment_fixture(%{user: user, course: course})

      {:ok, _} = Learning.complete_lesson(enrollment, lesson1.id)

      assert Learning.calculate_progress(enrollment) == 50.0
    end
  end

  describe "complete_lesson/2" do
    test "marks a lesson as completed" do
      %{course: course, lesson1: lesson} = create_course_with_lessons()
      user = user_fixture()
      enrollment = enrollment_fixture(%{user: user, course: course})

      assert {:ok, %LessonProgress{} = progress} =
               Learning.complete_lesson(enrollment, lesson.id)

      assert progress.enrollment_id == enrollment.id
      assert progress.lesson_id == lesson.id
      assert progress.completed_at
    end

    test "prevents completing the same lesson twice" do
      %{course: course, lesson1: lesson} = create_course_with_lessons()
      user = user_fixture()
      enrollment = enrollment_fixture(%{user: user, course: course})

      assert {:ok, _progress} = Learning.complete_lesson(enrollment, lesson.id)
      assert {:error, changeset} = Learning.complete_lesson(enrollment, lesson.id)
      assert errors_on(changeset)[:enrollment_id]
    end
  end

  describe "delete_enrollment/1" do
    test "deletes the enrollment" do
      enrollment = enrollment_fixture()

      assert {:ok, %Enrollment{}} = Learning.delete_enrollment(enrollment)

      assert_raise Ecto.NoResultsError, fn ->
        Learning.get_enrollment!(enrollment.id)
      end
    end

    test "cascades deletion to lesson progress" do
      %{course: course, lesson1: lesson} = create_course_with_lessons()
      user = user_fixture()
      enrollment = enrollment_fixture(%{user: user, course: course})
      {:ok, _progress} = Learning.complete_lesson(enrollment, lesson.id)

      assert {:ok, _} = Learning.delete_enrollment(enrollment)
      assert Repo.all(LessonProgress) == []
    end
  end

  describe "change_enrollment/2" do
    test "returns a changeset" do
      enrollment = enrollment_fixture()

      assert %Ecto.Changeset{} = Learning.change_enrollment(enrollment)
    end
  end
end
