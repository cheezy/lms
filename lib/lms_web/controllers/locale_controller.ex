defmodule LmsWeb.LocaleController do
  use LmsWeb, :controller

  @allowed_locales ~w(en fr)

  def update(conn, %{"locale" => locale}) do
    locale = if locale in @allowed_locales, do: locale, else: "en"

    conn
    |> put_session(:locale, locale)
    |> redirect(to: redirect_path(conn))
  end

  def update(conn, _params) do
    conn
    |> redirect(to: redirect_path(conn))
  end

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
