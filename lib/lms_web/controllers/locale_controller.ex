defmodule LmsWeb.LocaleController do
  use LmsWeb, :controller

  alias Lms.Accounts

  @allowed_locales ~w(en fr)

  def update(conn, %{"locale" => locale}) do
    locale = if locale in @allowed_locales, do: locale, else: "en"

    maybe_persist_locale(conn, locale)

    conn
    |> put_session(:locale, locale)
    |> redirect(to: redirect_path(conn))
  end

  def update(conn, _params) do
    conn
    |> redirect(to: redirect_path(conn))
  end

  defp maybe_persist_locale(%{assigns: %{current_scope: %{user: user}}} = _conn, locale)
       when not is_nil(user) do
    Accounts.update_user_locale(user, %{locale: locale})
  end

  defp maybe_persist_locale(_conn, _locale), do: :ok

  defp redirect_path(conn) do
    case get_req_header(conn, "referer") do
      [referer | _] ->
        uri = URI.parse(referer)
        path = uri.path || "/"
        if uri.query, do: "#{path}?#{uri.query}", else: path

      [] ->
        ~p"/"
    end
  end
end
