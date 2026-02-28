defmodule LmsWeb.InvitationLive.Accept do
  use LmsWeb, :live_view

  alias Lms.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_invitation_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Invitation link is invalid or has expired."))
         |> redirect(to: ~p"/")}

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
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Account activated! Please log in."))
         |> redirect(to: ~p"/users/log-in")}

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
          <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-primary/10 mb-4">
            <.icon name="hero-envelope-open" class="size-7 text-primary" />
          </div>
          <h1 class="text-2xl font-bold text-base-content">
            {gettext("Set Your Password")}
          </h1>
          <p class="mt-2 text-sm text-base-content/60">
            {gettext("Welcome, %{name}! Set a password to activate your account.",
              name: @user.name
            )}
          </p>
        </div>

        <div class="card bg-base-200 shadow-sm">
          <div class="card-body">
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
