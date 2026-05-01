defmodule LmsWeb.UserSessionController do
  use LmsWeb, :controller

  alias Lms.Accounts
  alias LmsWeb.UserAuth

  plug :assign_hide_root_nav

  def new(conn, _params) do
    email = get_in(conn.assigns, [:current_scope, Access.key(:user), Access.key(:email)])
    form = Phoenix.Component.to_form(%{"email" => email}, as: "user")

    render(conn, :new, form: form)
  end

  # email + password login
  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      form = Phoenix.Component.to_form(user_params, as: "user")

      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> render(:new, form: form)
    end
  end

  def registration_login(conn, %{"token" => token}) do
    case Phoenix.Token.verify(conn, "company_registration", token, max_age: 60) do
      {:ok, user_id} ->
        user = Accounts.get_user!(user_id)

        conn
        |> assign(:current_scope, Lms.Accounts.Scope.for_user(user))
        |> put_flash(:info, "Company registered successfully!")
        |> UserAuth.log_in_user(user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Registration link is invalid or has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def invitation_login(conn, %{"token" => token}) do
    case Phoenix.Token.verify(conn, "invitation_login", token, max_age: 60) do
      {:ok, user_id} ->
        user = Accounts.get_user!(user_id)

        conn
        |> assign(:current_scope, Lms.Accounts.Scope.for_user(user))
        |> put_flash(:info, "Account activated successfully!")
        |> UserAuth.log_in_user(user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Login link is invalid or has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  defp assign_hide_root_nav(conn, _opts) do
    assign(conn, :hide_root_nav, true)
  end
end
