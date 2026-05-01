defmodule LmsWeb.Admin.EmployeeLive.BulkUploadTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    conn = log_in_user(conn, admin)
    %{conn: conn, company: company, admin: admin}
  end

  describe "Bulk Upload Modal" do
    test "shows bulk upload button on employee list", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "Bulk Upload"
    end

    test "opens bulk upload modal when button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view |> element("button", "Bulk Upload") |> render_click()
      assert render(view) =~ "Bulk Invite Employees"
    end

    test "closes bulk upload modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view |> element("button", "Bulk Upload") |> render_click()
      assert render(view) =~ "Bulk Invite Employees"

      view |> element("button.btn-circle[phx-click='close_bulk_upload_modal']") |> render_click()
      refute render(view) =~ "Bulk Invite Employees"
    end
  end

  describe "CSV Upload and Preview" do
    test "uploads and previews valid CSV", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      csv_content =
        "name,email\nAlice Smith,alice-bulk@example.com\nBob Jones,bob-bulk@example.com"

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{
            name: "employees.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv, "employees.csv")

      html =
        view
        |> element("#csv-upload-form")
        |> render_submit()

      assert html =~ "2 valid"
      assert html =~ "Alice Smith"
      assert html =~ "alice-bulk@example.com"
      assert html =~ "Bob Jones"
    end

    test "shows validation errors for invalid rows", %{conn: conn, company: company} do
      existing = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      csv_content =
        "name,email\n,bad-email\nValid User,valid@example.com\nDuplicate,#{existing.email}"

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{
            name: "employees.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv, "employees.csv")

      html =
        view
        |> element("#csv-upload-form")
        |> render_submit()

      assert html =~ "1 valid"
      assert html =~ "2 invalid"
      assert html =~ "Name is required"
      assert html =~ "Invalid email format"
      assert html =~ "Employee already exists"
    end

    test "handles empty CSV (only headers)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      csv_content = "name,email"

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{
            name: "employees.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv, "employees.csv")

      html =
        view
        |> element("#csv-upload-form")
        |> render_submit()

      # Should show inline error and stay on upload step
      assert html =~ "empty or contains only headers"
    end

    test "detects duplicate emails within CSV", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      csv_content = "name,email\nAlice,dup@example.com\nBob,dup@example.com"

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{
            name: "employees.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv, "employees.csv")

      html =
        view
        |> element("#csv-upload-form")
        |> render_submit()

      assert html =~ "Duplicate email in CSV"
    end
  end

  describe "Confirm and Send Invitations" do
    test "sends invitations for valid rows on confirm", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      csv_content =
        "name,email\nAlice Confirm,alice-confirm@example.com\nBob Confirm,bob-confirm@example.com"

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{
            name: "employees.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv, "employees.csv")

      view
      |> element("#csv-upload-form")
      |> render_submit()

      html =
        view
        |> element("button", "Invite 2 Employees")
        |> render_click()

      assert html =~ "Invitations Sent"
      assert html =~ "2"
    end

    test "back_to_upload returns to upload step from preview", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      csv_content = "name,email\nAlice Back,alice-back@example.com"

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{name: "employees.csv", content: csv_content, type: "text/csv"}
        ])

      render_upload(csv, "employees.csv")

      view
      |> element("#csv-upload-form")
      |> render_submit()

      # Now in preview step - go back
      html =
        view
        |> element("button", "Back")
        |> render_click()

      # Should show upload step again
      assert html =~ "Click or drag to upload"
      refute html =~ "1 valid"
    end

    test "done button sends message and closes modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      csv_content = "name,email\nAlice Done,alice-done@example.com"

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{name: "employees.csv", content: csv_content, type: "text/csv"}
        ])

      render_upload(csv, "employees.csv")

      view
      |> element("#csv-upload-form")
      |> render_submit()

      view
      |> element("button", "Invite 1 Employees")
      |> render_click()

      # Click Done - this fires send(self(), {__MODULE__, :done})
      view
      |> element("button", "Done")
      |> render_click()

      # Allow parent process to handle the message and re-render
      html = render(view)
      refute html =~ "Invitations Sent!"
    end

    test "rejects upload of multiple files at once", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{name: "first.csv", content: "name,email\na,a@b.com", type: "text/csv"},
          %{name: "second.csv", content: "name,email\nb,b@c.com", type: "text/csv"}
        ])

      render_upload(csv, "first.csv")
      html = render(view)
      assert html =~ "Only one file can be uploaded" or html =~ "too_many_files"
    end

    test "displays file size in KB for files over 1024 bytes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      # Generate a CSV that's > 1024 bytes
      header = "name,email\n"

      rows =
        for i <- 1..50, into: "" do
          "User Number #{i},user-size-#{i}@example.com\n"
        end

      csv_content = header <> rows

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{name: "large.csv", content: csv_content, type: "text/csv"}
        ])

      render_upload(csv, "large.csv")
      html = render(view)
      assert html =~ "KB"
    end

    test "shows results with invited and skipped counts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      view |> element("button", "Bulk Upload") |> render_click()

      csv_content =
        "name,email\nValid User,valid-result@example.com\n,invalid-no-name@example.com"

      csv =
        file_input(view, "#csv-upload-form", :csv, [
          %{
            name: "employees.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv, "employees.csv")

      view
      |> element("#csv-upload-form")
      |> render_submit()

      html =
        view
        |> element("button", "Invite 1 Employees")
        |> render_click()

      assert html =~ "Invitations Sent"
      assert html =~ "Invited"
      assert html =~ "Skipped"
    end
  end
end
