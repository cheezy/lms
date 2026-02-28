defmodule LmsWeb.Courses.CourseFormLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures
  import Lms.TrainingFixtures

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    conn = log_in_user(conn, admin)
    %{conn: conn, company: company, admin: admin}
  end

  describe "New" do
    test "renders new course form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses/new")
      assert html =~ "New Course"
      assert html =~ "Title"
      assert html =~ "Description"
      assert html =~ "Save Course"
    end

    test "creates course with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/courses/new")

      view
      |> form("#course-form", course: %{title: "New Elixir Course", description: "Learn Elixir"})
      |> render_submit()

      assert_redirect(view, ~p"/courses")
    end

    test "shows validation errors with invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/courses/new")

      html =
        view
        |> form("#course-form", course: %{title: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "shows validation errors on submit with invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/courses/new")

      html =
        view
        |> form("#course-form", course: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "shows cover image upload area", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses/new")
      assert html =~ "Cover Image"
      assert html =~ "Choose image"
      assert html =~ "JPG, PNG, GIF, WebP"
    end

    test "has cancel link back to courses", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses/new")
      assert html =~ "Cancel"
      assert html =~ ~p"/courses"
    end
  end

  describe "Edit" do
    test "renders edit course form with existing data", %{conn: conn, company: company} do
      course =
        course_fixture(%{
          company: company,
          title: "Existing Course",
          description: "A description"
        })

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/edit")
      assert html =~ "Edit Course"
      assert html =~ "Existing Course"
      assert html =~ "A description"
    end

    test "updates course with valid data", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, title: "Old Title"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/edit")

      view
      |> form("#course-form", course: %{title: "Updated Title"})
      |> render_submit()

      assert_redirect(view, ~p"/courses")

      updated = Lms.Training.get_course!(course.id)
      assert updated.title == "Updated Title"
    end

    test "shows validation errors with invalid data", %{conn: conn, company: company} do
      course = course_fixture(%{company: company})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/edit")

      html =
        view
        |> form("#course-form", course: %{title: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "shows validation errors on submit with invalid data", %{conn: conn, company: company} do
      course = course_fixture(%{company: company})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/edit")

      html =
        view
        |> form("#course-form", course: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Cover image upload" do
    test "rejects oversized file", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/courses/new")

      # Upload a file that exceeds the 5MB limit
      cover =
        file_input(view, "#course-form", :cover_image, [
          %{
            name: "big.jpg",
            content: String.duplicate("x", 5_000_001),
            type: "image/jpeg"
          }
        ])

      render_upload(cover, "big.jpg")
      html = render(view)
      assert html =~ "too large"
    end

    test "rejects unsupported file type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/courses/new")

      cover =
        file_input(view, "#course-form", :cover_image, [
          %{
            name: "doc.pdf",
            content: "fake pdf content",
            type: "application/pdf"
          }
        ])

      render_upload(cover, "doc.pdf")
      html = render(view)
      assert html =~ "Unsupported file type" || html =~ "not accepted"
    end
  end

  describe "Authorization" do
    test "course creators can access the form", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      conn = log_in_user(conn, creator)

      {:ok, _view, html} = live(conn, ~p"/courses/new")
      assert html =~ "New Course"
    end

    test "employees cannot access the form" do
      company = company_fixture()
      employee = user_with_role_fixture(:employee, company.id)
      conn = build_conn() |> log_in_user(employee)

      {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} =
        live(conn, ~p"/courses/new")
    end
  end
end
