defmodule LmsWeb.InvitationLive.Accept do
  use LmsWeb, :live_view

  alias Lms.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_invitation_token(token) do
      nil ->
        message =
          if Accounts.invitation_already_accepted?(token) do
            gettext("This invitation has already been accepted. Please log in.")
          else
            gettext("Invitation link is invalid or has expired.")
          end

        {:ok,
         socket
         |> put_flash(:error, message)
         |> redirect(to: ~p"/users/log-in")}

      user ->
        changeset = Accounts.change_user_password(user)

        socket =
          socket
          |> assign(:current_scope, nil)
          |> assign(:user, user)
          |> assign(:token, token)
          |> assign(:page_title, gettext("Set Your Password"))
          |> assign(:form, to_form(changeset))

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.accept_invitation(socket.assigns.user, params) do
      {:ok, user} ->
        token = Phoenix.Token.sign(LmsWeb.Endpoint, "invitation_login", user.id)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Account activated successfully!"))
         |> redirect(to: ~p"/users/invitation-login?token=#{token}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="text-center mb-8">
          <.link navigate={~p"/"} class="text-2xl font-bold text-primary tracking-tight">
            Uplift
          </.link>
          <h1 class="mt-4 text-xl font-semibold text-base-content">
            {gettext("Welcome to Uplift")}
          </h1>
          <p class="mt-2 text-sm text-base-content/60">
            {gettext("Welcome, %{name}! Set a password to activate your account.",
              name: @user.name
            )}
          </p>
        </div>

        <div class="card bg-base-200 shadow-sm rounded-2xl">
          <div class="card-body">
            <div class="mb-4">
              <label class="label text-base-content font-medium text-sm">
                {gettext("Email")}
              </label>
              <div class="px-3 py-2 rounded-lg bg-base-300 text-base-content/70 text-sm">
                {@user.email}
              </div>
            </div>

            <.form
              for={@form}
              id="accept-invitation-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-1"
            >
              <.input
                field={@form[:password]}
                type="password"
                label={gettext("Password")}
                placeholder={gettext("Minimum 12 characters")}
                required
              />
              <.button
                variant="primary"
                class="btn btn-primary w-full mt-4"
                phx-disable-with={gettext("Activating...")}
              >
                {gettext("Activate Account")}
              </.button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
