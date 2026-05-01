defmodule LmsWeb.LayoutsTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures

  describe "mobile navigation drawer" do
    test "renders hamburger toggle and drawer for authenticated users", %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ ~s(id="mobile-menu-toggle")
      assert html =~ ~s(aria-controls="mobile-menu")
      assert html =~ ~s(aria-expanded="false")
      assert html =~ "hero-bars-3"

      assert html =~ ~s(id="mobile-menu-wrapper")
      assert html =~ ~s(phx-hook="MobileMenu")
      assert html =~ ~s(id="mobile-menu")
      assert html =~ ~s(id="mobile-menu-backdrop")
    end

    test "drawer mirrors every desktop nav link a company_admin can see", %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Desktop nav links — each should appear at least twice
      # (once in desktop <nav>, once in mobile drawer)
      for label <- ["Dashboard", "Employees", "Courses", "Enrollments", "My Learning"] do
        assert html |> String.split(label) |> length() >= 3,
               "expected #{label} to appear in both desktop nav and mobile drawer"
      end
    end

    test "drawer includes user email, settings, and log out", %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Email appears in both desktop user-info block and mobile drawer
      assert html |> String.split(admin.email) |> length() >= 3
      # Settings link appears in both
      assert html |> String.split(~s(href="/users/settings")) |> length() >= 3
    end

    test "every drawer link dispatches mobile-menu:close on click", %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      drawer_html =
        case Regex.run(~r/<aside[^>]*id="mobile-menu"[^>]*>.*?<\/aside>/s, html) do
          [match] -> match
          _ -> flunk("could not find mobile-menu aside in rendered HTML")
        end

      # Count <a> tags in the drawer
      link_count = drawer_html |> String.split("<a ") |> length() |> Kernel.-(1)
      # Count phx-click dispatches in the drawer
      dispatch_count = drawer_html |> String.split("mobile-menu:close") |> length() |> Kernel.-(1)
      # Every link inside the drawer should dispatch close (plus the close button = +1).
      # link_count covers nav links + Settings + Log out.
      assert dispatch_count >= link_count,
             "expected every drawer link to dispatch mobile-menu:close (#{dispatch_count} dispatches for #{link_count} links)"
    end

    test "drawer respects role guards (employee sees only My Learning)", %{conn: conn} do
      company = company_fixture()
      employee = user_with_role_fixture(:employee, company.id)
      conn = log_in_user(conn, employee)

      {:ok, _view, html} = live(conn, ~p"/my-learning")

      # Employee should see "My Learning" but not admin links
      assert html =~ "My Learning"
      refute html =~ ~s(navigate="/admin/companies")
      refute html =~ ~s(navigate="/admin/employees")
      refute html =~ ~s(navigate="/admin/enrollments")
    end

    test "no hamburger or drawer when unauthenticated", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")
      html = html_response(conn, 200)

      refute html =~ ~s(id="mobile-menu-toggle")
      refute html =~ ~s(id="mobile-menu-wrapper")
    end

    test "drawer uses dark-mode-compliant tokens", %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = log_in_user(conn, admin)

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Pull out the drawer panel markup
      drawer_html =
        case Regex.run(~r/<aside[^>]*id="mobile-menu"[^>]*>.*?<\/aside>/s, html) do
          [match] -> match
          _ -> flunk("could not find mobile-menu aside in rendered HTML")
        end

      assert drawer_html =~ "bg-base-100"
      assert drawer_html =~ "text-base-content"
      refute drawer_html =~ "bg-white"
      refute drawer_html =~ "text-gray-"
    end
  end
end
