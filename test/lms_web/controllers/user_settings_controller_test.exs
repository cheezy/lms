defmodule LmsWeb.UserSettingsControllerTest do
  use LmsWeb.ConnCase, async: true

  import Lms.AccountsFixtures

  alias Lms.Accounts

  setup :register_and_log_in_user

  describe "GET /users/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, ~p"/users/settings")
      response = html_response(conn, 200)
      assert response =~ "Settings"
    end

    test "redirects if user is not logged in" do
      conn = build_conn()
      conn = get(conn, ~p"/users/settings")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    @tag token_authenticated_at: :second |> DateTime.utc_now() |> DateTime.add(-11, :minute)
    test "is reachable for non-sudo users (sudo no longer required for view)", %{conn: conn} do
      conn = get(conn, ~p"/users/settings")
      response = html_response(conn, 200)
      assert response =~ "Account Settings"
      assert response =~ "Profile"
    end

    @tag token_authenticated_at: :second |> DateTime.utc_now() |> DateTime.add(-11, :minute)
    test "PUT update_password redirects to log-in when not in sudo mode", %{conn: conn} do
      conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_password",
          "user" => %{
            "password" => "brand new password",
            "password_confirmation" => "brand new password"
          }
        })

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "re-authenticate"
    end

    @tag token_authenticated_at: :second |> DateTime.utc_now() |> DateTime.add(-11, :minute)
    test "GET email change page redirects to log-in when not in sudo mode", %{conn: conn} do
      conn = get(conn, ~p"/users/settings/email")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "re-authenticate"
    end

    @tag token_authenticated_at: :second |> DateTime.utc_now() |> DateTime.add(-11, :minute)
    test "PUT email change redirects to log-in when not in sudo mode", %{conn: conn} do
      conn =
        put(conn, ~p"/users/settings/email", %{
          "user" => %{"email" => "newaddress@example.com"}
        })

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "re-authenticate"
    end
  end

  describe "PUT /users/settings (change password form)" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      new_password_conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_password",
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_password",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "Settings"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"

      assert get_session(old_password_conn, :user_token) == get_session(conn, :user_token)
    end
  end

  describe "GET /users/settings/email" do
    test "renders the dedicated email change page", %{conn: conn} do
      conn = get(conn, ~p"/users/settings/email")
      response = html_response(conn, 200)
      assert response =~ "Change Email"
      assert response =~ "New email"
      assert response =~ "Send confirmation link"
      assert response =~ ~p"/users/settings"
    end
  end

  describe "PUT /users/settings/email" do
    @tag :capture_log
    test "sends confirmation link for valid new email", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/users/settings/email", %{
          "user" => %{"email" => unique_user_email()}
        })

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "A link to confirm your email"

      # Email is unchanged until the user clicks the confirmation link
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders email page with errors on invalid data", %{conn: conn} do
      conn =
        put(conn, ~p"/users/settings/email", %{
          "user" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "Change Email"
      assert response =~ "must have the @ sign and no spaces"
    end
  end

  describe "GET /users/settings/confirm-email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, ~p"/users/settings/confirm-email/#{token}")
      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Email changed successfully"

      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, ~p"/users/settings/confirm-email/#{token}")

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, ~p"/users/settings/confirm-email/oops")
      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"

      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, ~p"/users/settings/confirm-email/#{token}")
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "PUT /users/settings (update profile form)" do
    test "updates the user name and locale and sets session locale", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_profile",
          "user" => %{"name" => "Jane Doe", "locale" => "fr"}
        })

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Profile updated"
      assert get_session(conn, :locale) == "fr"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.name == "Jane Doe"
      assert updated_user.locale == "fr"
    end

    test "rejects invalid locale values", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/users/settings", %{
          "action" => "update_profile",
          "user" => %{"name" => "Jane", "locale" => "de"}
        })

      response = html_response(conn, 200)
      assert response =~ "Account Settings"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.locale == "en"
      assert is_nil(updated_user.name)
    end

    test "renders profile form on settings page", %{conn: conn} do
      conn = get(conn, ~p"/users/settings")
      response = html_response(conn, 200)
      assert response =~ "Profile"
      assert response =~ "Full name"
      assert response =~ "Preferred language"
      assert response =~ "English"
      assert response =~ "Français"
      assert response =~ "Save Profile"
    end

    test "renders read-only Account Info card", %{conn: conn} do
      conn = get(conn, ~p"/users/settings")
      response = html_response(conn, 200)
      assert response =~ "Account Info"
      assert response =~ "Role"
      assert response =~ "Company"
      assert response =~ "Member since"
      assert response =~ "Email status"
    end

    test "settings page is reachable WITHOUT sudo mode", %{user: user} do
      # Force the user out of sudo mode by aging their session token
      token = Accounts.generate_user_session_token(user)
      Lms.AccountsFixtures.override_token_authenticated_at(token, ~U[2020-01-01 00:00:00Z])

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_token: token})
        |> get(~p"/users/settings")

      assert html_response(conn, 200) =~ "Account Settings"
    end
  end
end
