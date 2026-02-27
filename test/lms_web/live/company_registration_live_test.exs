defmodule LmsWeb.CompanyRegistrationLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures

  describe "company registration page" do
    test "renders the registration form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/companies/register")

      assert html =~ "Register Your Company"
      assert html =~ "Company name"
      assert html =~ "Full name"
      assert html =~ "Email"
      assert html =~ "Password"
      assert html =~ "Confirm password"
    end

    test "shows link to log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/companies/register")

      assert html =~ "Already have an account?"
      assert html =~ "Log in"
    end

    test "redirects authenticated users", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert {:error, {:redirect, _}} = live(conn, ~p"/companies/register")
    end
  end

  describe "registration form validation" do
    test "shows errors for blank fields", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/companies/register")

      result =
        lv
        |> form("#registration-form",
          registration: %{
            company_name: "",
            name: "",
            email: "",
            password: ""
          }
        )
        |> render_change()

      assert result =~ "can&#39;t be blank"
    end

    test "shows error for invalid email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/companies/register")

      result =
        lv
        |> form("#registration-form", registration: %{email: "invalid"})
        |> render_change()

      assert result =~ "must have the @ sign and no spaces"
    end

    test "shows error for short password", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/companies/register")

      result =
        lv
        |> form("#registration-form", registration: %{password: "short"})
        |> render_change()

      assert result =~ "should be at least 12 character(s)"
    end

    test "shows error for mismatched password confirmation", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/companies/register")

      result =
        lv
        |> form("#registration-form",
          registration: %{
            password: "long_password_123",
            password_confirmation: "different_password"
          }
        )
        |> render_change()

      assert result =~ "does not match password"
    end
  end

  describe "registration form submission" do
    test "creates company and redirects on success", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/companies/register")

      {:ok, conn} =
        lv
        |> form("#registration-form",
          registration: %{
            company_name: "New Company",
            name: "Admin User",
            email: "admin@newcompany.com",
            password: "long_password_123",
            password_confirmation: "long_password_123"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert redirected_to(conn) =~ ~p"/dashboard"
    end

    test "shows error when email already exists", %{conn: conn} do
      _existing = user_fixture(%{email: "taken@example.com"})

      {:ok, lv, _html} = live(conn, ~p"/companies/register")

      result =
        lv
        |> form("#registration-form",
          registration: %{
            company_name: "Another Company",
            name: "Admin User",
            email: "taken@example.com",
            password: "long_password_123",
            password_confirmation: "long_password_123"
          }
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end
end
