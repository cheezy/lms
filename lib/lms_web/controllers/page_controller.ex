defmodule LmsWeb.PageController do
  use LmsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
