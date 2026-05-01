defmodule LmsWeb.Admin.EmployeeLive.InviteFormComponent do
  use LmsWeb, :live_component

  alias Lms.Accounts
  alias Lms.Accounts.User

  @impl true
  def mount(socket) do
    changeset = User.invitation_changeset(%User{}, %{})
    {:ok, assign(socket, form: to_form(changeset, as: "invite"))}
  end

  @impl true
  def handle_event("validate", %{"invite" => params}, socket) do
    changeset =
      %User{}
      |> User.invitation_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "invite"))}
  end

  @impl true
  def handle_event("save", %{"invite" => params}, socket) do
    scope = socket.assigns.current_scope

    case Accounts.deliver_employee_invitation(scope, params, &url(~p"/invitations/#{&1}")) do
      {:ok, user, _raw_token} ->
        send(self(), {__MODULE__, {:invited, user}})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Invitation sent to %{email}.", email: user.email))
         |> push_navigate(to: ~p"/admin/employees")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "invite"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal modal-open">
      <div class="modal-box bg-base-100 w-11/12 max-w-md max-h-[90vh] overflow-y-auto">
        <button
          type="button"
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
          phx-click="close_invite_modal"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>

        <h3 class="text-lg font-bold text-base-content mb-4">
          {gettext("Invite a New Employee")}
        </h3>

        <.form
          for={@form}
          id="invite-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="space-y-1"
        >
          <.input
            field={@form[:name]}
            type="text"
            label={gettext("Full name")}
            placeholder={gettext("Jane Smith")}
            required
          />
          <.input
            field={@form[:email]}
            type="email"
            label={gettext("Email address")}
            placeholder={gettext("jane@company.com")}
            required
          />
          <div class="modal-action">
            <button type="button" class="btn" phx-click="close_invite_modal">
              {gettext("Cancel")}
            </button>
            <.button variant="primary" phx-disable-with={gettext("Sending...")}>
              <.icon name="hero-paper-airplane" class="size-4 mr-1" />
              {gettext("Send Invitation")}
            </.button>
          </div>
        </.form>
      </div>
      <div class="modal-backdrop bg-base-200/90" phx-click="close_invite_modal"></div>
    </div>
    """
  end
end
