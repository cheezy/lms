defmodule LmsWeb.LocaleControllerTest do
  use LmsWeb.ConnCase, async: true

  import Lms.AccountsFixtures

  alias Lms.Accounts

  describe "POST /locale (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "persists locale to user record when authenticated", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("referer", "http://localhost/dashboard")
        |> post(~p"/locale", %{"locale" => "fr"})

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :locale) == "fr"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.locale == "fr"
    end
  end

  describe "POST /locale" do
    test "sets session locale to 'fr' and redirects to referer", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "http://localhost/dashboard")
        |> post(~p"/locale", %{"locale" => "fr"})

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :locale) == "fr"
    end

    test "sets session locale to 'en' and redirects to referer", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "http://localhost/my-learning")
        |> post(~p"/locale", %{"locale" => "en"})

      assert redirected_to(conn) == "/my-learning"
      assert get_session(conn, :locale) == "en"
    end

    test "rejects invalid locale and defaults to 'en'", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "http://localhost/dashboard")
        |> post(~p"/locale", %{"locale" => "zz"})

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :locale) == "en"
    end

    test "redirects to root when no referer header", %{conn: conn} do
      conn = post(conn, ~p"/locale", %{"locale" => "fr"})

      assert redirected_to(conn) == "/"
      assert get_session(conn, :locale) == "fr"
    end

    test "preserves query parameters from referer", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "http://localhost/courses?page=2")
        |> post(~p"/locale", %{"locale" => "fr"})

      assert redirected_to(conn) == "/courses?page=2"
    end

    test "redirects to root when locale param is missing", %{conn: conn} do
      conn = post(conn, ~p"/locale", %{})

      assert redirected_to(conn) == "/"
    end
  end
end
