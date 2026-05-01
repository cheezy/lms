defmodule LmsWeb.UserSettingsController do
  use LmsWeb, :controller

  alias Lms.Accounts
  alias Lms.Repo
  alias LmsWeb.UserAuth

  plug :assign_changesets
  plug :assign_company

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def update(conn, %{"action" => "update_profile"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.update_user_profile(user, user_params) do
      {:ok, updated} ->
        conn
        |> put_session(:locale, updated.locale)
        |> put_flash(:info, gettext("Profile updated successfully."))
        |> redirect(to: ~p"/users/settings")

      {:error, changeset} ->
        render(conn, :edit, profile_changeset: changeset)
    end
  end

  def edit_password(conn, _params) do
    case require_sudo(conn) do
      {:error, conn} -> conn
      {:ok, conn} -> render(conn, :edit_password)
    end
  end

  def update_password(conn, %{"user" => user_params}) do
    case require_sudo(conn) do
      {:error, conn} ->
        conn

      {:ok, conn} ->
        user = conn.assigns.current_scope.user

        case Accounts.update_user_password(user, user_params) do
          {:ok, {user, _}} ->
            conn
            |> put_flash(:info, gettext("Password updated successfully."))
            |> put_session(:user_return_to, ~p"/users/settings")
            |> UserAuth.log_in_user(user)

          {:error, changeset} ->
            render(conn, :edit_password, password_changeset: changeset)
        end
    end
  end

  def edit_email(conn, _params) do
    case require_sudo(conn) do
      {:error, conn} -> conn
      {:ok, conn} -> render(conn, :edit_email)
    end
  end

  def update_email(conn, %{"user" => user_params}) do
    case require_sudo(conn) do
      {:error, conn} ->
        conn

      {:ok, conn} ->
        user = conn.assigns.current_scope.user

        case Accounts.change_user_email(user, user_params) do
          %{valid?: true} = changeset ->
            changeset
            |> Ecto.Changeset.apply_action!(:insert)
            |> Accounts.deliver_user_update_email_instructions(
              user.email,
              &url(~p"/users/settings/confirm-email/#{&1}")
            )

            conn
            |> put_flash(
              :info,
              gettext("A link to confirm your email change has been sent to the new address.")
            )
            |> redirect(to: ~p"/users/settings")

          changeset ->
            render(conn, :edit_email, email_changeset: %{changeset | action: :insert})
        end
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_scope.user, token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, gettext("Email changed successfully."))
        |> redirect(to: ~p"/users/settings")

      {:error, _} ->
        conn
        |> put_flash(:error, gettext("Email change link is invalid or it has expired."))
        |> redirect(to: ~p"/users/settings")
    end
  end

  # Inline sudo guard for credential-changing branches of update/2.
  # Returns {:ok, conn} when in sudo mode, or {:error, conn} with a redirect
  # already applied. The `with` form lets the action body run only on :ok.
  defp require_sudo(conn) do
    if Accounts.sudo_mode?(conn.assigns.current_scope.user, -10) do
      {:ok, conn}
    else
      redirected =
        conn
        |> put_flash(:error, gettext("You must re-authenticate to access this page."))
        |> redirect(to: ~p"/users/log-in")

      {:error, redirected}
    end
  end

  defp assign_changesets(conn, _opts) do
    user = conn.assigns.current_scope.user

    conn
    |> assign(:profile_changeset, Accounts.change_user_profile(user))
    |> assign(:email_changeset, Accounts.change_user_email(user))
    |> assign(:password_changeset, Accounts.change_user_password(user))
  end

  defp assign_company(conn, _opts) do
    user = conn.assigns.current_scope.user
    user = Repo.preload(user, :company)
    assign(conn, :user_with_company, user)
  end
end
