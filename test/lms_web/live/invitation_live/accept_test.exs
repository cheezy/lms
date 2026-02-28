defmodule LmsWeb.InvitationLive.AcceptTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures

  alias Lms.Accounts

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    scope = Accounts.Scope.for_user(admin)
    {user, raw_token} = invited_user_fixture(scope)
    %{conn: conn, user: user, raw_token: raw_token, company: company}
  end

  describe "Accept invitation" do
    test "renders password form for valid token", %{conn: conn, raw_token: raw_token} do
      {:ok, _view, html} = live(conn, ~p"/invitations/#{raw_token}")
      assert html =~ "Set Your Password"
    end

    test "redirects for invalid token", %{conn: conn} do
      {:error, {:redirect, %{to: "/", flash: %{"error" => msg}}}} =
        live(conn, ~p"/invitations/invalid-token")

      assert msg =~ "invalid or has expired"
    end

    test "accepts invitation with valid password", %{
      conn: conn,
      raw_token: raw_token,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/invitations/#{raw_token}")

      view
      |> form("#accept-invitation-form", user: %{password: "valid password 123"})
      |> render_submit()

      flash = assert_redirect(view, ~p"/users/log-in")
      assert flash["info"] =~ "Account activated"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.status == :active
      assert updated_user.invitation_token == nil
      assert updated_user.invitation_accepted_at != nil
    end

    test "shows error for short password", %{conn: conn, raw_token: raw_token} do
      {:ok, view, _html} = live(conn, ~p"/invitations/#{raw_token}")

      html =
        view
        |> form("#accept-invitation-form", user: %{password: "short"})
        |> render_submit()

      assert html =~ "should be at least 12 character"
    end
  end
end
