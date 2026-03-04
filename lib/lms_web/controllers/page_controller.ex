defmodule LmsWeb.PageController do
  use LmsWeb, :controller

  def home(conn, _params) do
    conn
    |> put_layout(html: {LmsWeb.Layouts, :landing})
    |> assign(:hide_root_nav, true)
    |> assign(:page_title, "Empower Your Team with Training They'll Actually Complete")
    |> render(:home)
  end
end
