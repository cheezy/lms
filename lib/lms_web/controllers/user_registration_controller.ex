defmodule LmsWeb.UserRegistrationController do
  use LmsWeb, :controller

  alias Lms.Accounts
  alias Lms.Accounts.User
  alias LmsWeb.UserAuth

  plug :assign_hide_root_nav

  def new(conn, _params) do
    # Build a combined changeset that exposes email + password fields to the form.
    changeset =
      %User{}
      |> Accounts.change_user_email(%{})
      |> User.password_changeset(%{}, hash_password: false)

    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, gettext("Account created successfully."))
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  defp assign_hide_root_nav(conn, _opts) do
    assign(conn, :hide_root_nav, true)
  end
end
