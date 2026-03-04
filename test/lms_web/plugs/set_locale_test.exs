defmodule LmsWeb.Plugs.SetLocaleTest do
  use LmsWeb.ConnCase, async: true

  alias LmsWeb.Plugs.SetLocale

  describe "call/2" do
    test "sets locale to :fr when session has locale 'fr'", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{locale: "fr"})
        |> SetLocale.call([])

      assert Gettext.get_locale() == "fr"
      assert conn.assigns.locale == "fr"
    end

    test "sets locale to :en when session has locale 'en'", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{locale: "en"})
        |> SetLocale.call([])

      assert Gettext.get_locale() == "en"
      assert conn.assigns.locale == "en"
    end

    test "defaults to configured locale when no locale in session", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> SetLocale.call([])

      assert Gettext.get_locale() == "en"
      assert conn.assigns.locale == "en"
    end

    test "defaults to configured locale when session locale is invalid", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{locale: "zz"})
        |> SetLocale.call([])

      assert Gettext.get_locale() == "en"
      assert conn.assigns.locale == "en"
    end

    test "defaults to configured locale when session locale is nil", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{locale: nil})
        |> SetLocale.call([])

      assert Gettext.get_locale() == "en"
      assert conn.assigns.locale == "en"
    end
  end

  describe "init/1" do
    test "passes options through" do
      assert SetLocale.init(foo: :bar) == [foo: :bar]
    end
  end
end
