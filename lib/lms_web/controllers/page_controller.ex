defmodule LmsWeb.PageController do
  use LmsWeb, :controller

  def home(conn, _params) do
    conn
    |> put_layout(html: {LmsWeb.Layouts, :landing})
    |> render(:home)
  end
end
