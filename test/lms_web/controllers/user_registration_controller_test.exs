defmodule LmsWeb.UserRegistrationControllerTest do
  use LmsWeb.ConnCase, async: true

  import Lms.AccountsFixtures

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)
      assert response =~ "Create your account"
      assert response =~ ~p"/users/log-in"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")

      assert redirected_to(conn) == ~p"/my-learning"
    end
  end

  describe "POST /users/register" do
    test "creates account and logs the user in immediately", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes(email: email)
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/my-learning"
      assert conn.assigns.flash["info"] =~ "Account created"
    end

    test "render errors for invalid email", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"email" => "with spaces", "password" => valid_user_password()}
        })

      response = html_response(conn, 200)
      assert response =~ "Create your account"
      assert response =~ "must have the @ sign and no spaces"
    end

    test "does not log the user in when registration fails", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"email" => unique_user_email()}
        })

      refute get_session(conn, :user_token)
      response = html_response(conn, 200)
      assert response =~ "Create your account"
    end
  end
end
