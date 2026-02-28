defmodule LmsWeb.Admin.EmployeeLive.Index do
  use LmsWeb, :live_view

  alias Lms.Accounts

  @impl true
  def mount(_params, _session, socket) do
    employees = Accounts.list_employees(socket.assigns.current_scope)

    socket =
      socket
      |> assign(:page_title, gettext("Employees"))
      |> assign(:employees, employees)
      |> assign(:show_invite_modal, false)

    {:ok, socket}
  end

  @impl true
  def handle_info({LmsWeb.Admin.EmployeeLive.InviteFormComponent, {:invited, _user}}, socket) do
    employees = Accounts.list_employees(socket.assigns.current_scope)

    {:noreply,
     socket
     |> assign(:employees, employees)
     |> assign(:show_invite_modal, false)}
  end

  @impl true
  def handle_event("open_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  @impl true
  def handle_event("close_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-2xl font-bold text-base-content">{gettext("Employees")}</h1>
            <p class="mt-1 text-sm text-base-content/60">
              {gettext("Manage your team members and send invitations.")}
            </p>
          </div>
          <.button variant="primary" phx-click="open_invite_modal">
            <.icon name="hero-plus" class="size-4 mr-1" />
            {gettext("Invite Employee")}
          </.button>
        </div>

        <div :if={@employees == []} class="text-center py-12">
          <.icon name="hero-users" class="size-12 text-base-content/30 mx-auto mb-4" />
          <p class="text-base-content/60">
            {gettext("No employees yet. Invite your first team member!")}
          </p>
        </div>

        <.table :if={@employees != []} id="employees" rows={@employees}>
          <:col :let={employee} label={gettext("Name")}>{employee.name}</:col>
          <:col :let={employee} label={gettext("Email")}>{employee.email}</:col>
          <:col :let={employee} label={gettext("Status")}>
            <span class={[
              "badge badge-sm",
              employee.status == :active && "badge-success",
              employee.status == :invited && "badge-warning"
            ]}>
              {employee.status}
            </span>
          </:col>
        </.table>

        <.live_component
          :if={@show_invite_modal}
          module={LmsWeb.Admin.EmployeeLive.InviteFormComponent}
          id="invite-form"
          current_scope={@current_scope}
        />
      </div>
    </Layouts.app>
    """
  end
end
