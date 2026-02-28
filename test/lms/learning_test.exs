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

  describe "enroll_employees/3" do
    test "enrolls multiple employees in a course" do
      course = course_fixture()
      user1 = user_fixture()
      user2 = user_fixture()

      {successful, failed} = Learning.enroll_employees([user1.id, user2.id], course.id)

      assert length(successful) == 2
      assert failed == []
    end

    test "skips already enrolled employees" do
      course = course_fixture()
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, _} = Learning.enroll_employee(%{user_id: user1.id, course_id: course.id})

      {successful, failed} = Learning.enroll_employees([user1.id, user2.id], course.id)

      assert length(successful) == 1
      assert length(failed) == 1
    end

    test "passes optional due_date" do
      course = course_fixture()
      user = user_fixture()
      due_date = ~D[2026-12-31]

      {[enrollment], []} =
        Learning.enroll_employees([user.id], course.id, %{due_date: due_date})

      assert enrollment.due_date == due_date
    end
  end

  describe "list_enrollments_for_company/2" do
    test "returns enrollments for a company" do
      %{company: company, course: course} = create_course_with_lessons()
      user = user_with_role_fixture(:employee, company.id)
      enrollment_fixture(%{user: user, course: course})

      {enrollments, count} = Learning.list_enrollments_for_company(company.id)

      assert count == 1
      assert length(enrollments) == 1
    end

    test "includes progress for each enrollment" do
      %{company: company, course: course, lesson1: lesson1} = create_course_with_lessons()
      user = user_with_role_fixture(:employee, company.id)
      enrollment = enrollment_fixture(%{user: user, course: course})
      {:ok, _} = Learning.complete_lesson(enrollment, lesson1.id)

      {[result], 1} = Learning.list_enrollments_for_company(company.id)

      assert result.progress == 50.0
    end

    test "filters by search term" do
      %{company: company, course: course} = create_course_with_lessons()
      user = user_with_role_fixture(:employee, company.id)

      {1, _} =
        Lms.Accounts.User
        |> Ecto.Query.from(where: [id: ^user.id])
        |> Repo.update_all(set: [name: "Alice Smith"])

      enrollment_fixture(%{user: user, course: course})

      other_user = user_with_role_fixture(:employee, company.id)

      {1, _} =
        Lms.Accounts.User
        |> Ecto.Query.from(where: [id: ^other_user.id])
        |> Repo.update_all(set: [name: "Bob Jones"])

      enrollment_fixture(%{user: other_user, course: course})

      {enrollments, _count} =
        Learning.list_enrollments_for_company(company.id, %{search: "Alice"})

      assert length(enrollments) == 1
    end

    test "filters by course_id" do
      %{company: company, course: course} = create_course_with_lessons()
      creator = user_with_role_fixture(:course_creator, company.id)
      other_course = course_fixture(%{company: company, creator: creator})
      user = user_with_role_fixture(:employee, company.id)

      enrollment_fixture(%{user: user, course: course})
      enrollment_fixture(%{user: user, course: other_course})

      {enrollments, _count} =
        Learning.list_enrollments_for_company(company.id, %{course_id: course.id})

      assert length(enrollments) == 1
    end

    test "paginates results" do
      %{company: company, course: course} = create_course_with_lessons()

      for _ <- 1..25 do
        user = user_with_role_fixture(:employee, company.id)
        enrollment_fixture(%{user: user, course: course})
      end

      {page1, 25} = Learning.list_enrollments_for_company(company.id, %{page: 1})
      {page2, 25} = Learning.list_enrollments_for_company(company.id, %{page: 2})

      assert length(page1) == 20
      assert length(page2) == 5
    end
  end

  describe "list_published_courses/1" do
    test "returns only published courses for a company" do
      company = company_fixture()
      creator = user_fixture(%{company: company})

      published = course_fixture(%{company: company, creator: creator, status: :published})
      _draft = course_fixture(%{company: company, creator: creator, status: :draft})

      courses = Learning.list_published_courses(company.id)

      assert length(courses) == 1
      assert hd(courses).id == published.id
    end
  end

  describe "enrollment_status/2" do
    test "returns :not_started when no progress" do
      enrollment = %Enrollment{completed_at: nil, due_date: nil}
      assert Learning.enrollment_status(enrollment, 0.0) == :not_started
    end

    test "returns :in_progress when some progress" do
      enrollment = %Enrollment{completed_at: nil, due_date: nil}
      assert Learning.enrollment_status(enrollment, 50.0) == :in_progress
    end

    test "returns :completed when completed_at is set" do
      enrollment = %Enrollment{completed_at: DateTime.utc_now(:second), due_date: nil}
      assert Learning.enrollment_status(enrollment, 100.0) == :completed
    end

    test "returns :overdue when past due_date and not completed" do
      enrollment = %Enrollment{completed_at: nil, due_date: ~D[2020-01-01]}
      assert Learning.enrollment_status(enrollment, 0.0) == :overdue
    end

    test "returns :completed even if past due_date when completed" do
      enrollment = %Enrollment{
        completed_at: DateTime.utc_now(:second),
        due_date: ~D[2020-01-01]
      }

      assert Learning.enrollment_status(enrollment, 100.0) == :completed
    end
  end

  describe "change_enrollment/2" do
    test "returns a changeset" do
      enrollment = enrollment_fixture()

      assert %Ecto.Changeset{} = Learning.change_enrollment(enrollment)
    end
  end
end
