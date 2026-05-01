defmodule LmsWeb.Admin.EmployeeLive.Index do
  use LmsWeb, :live_view

  import LmsWeb.LiveHelpers, only: [maybe_put: 3, maybe_put: 4, pagination_range: 2]
  import LmsWeb.SharedComponents, only: [sort_indicator: 1]

  alias Lms.Accounts

  @sort_fields ~w(name email status role)a
  @sort_orders ~w(asc desc)a

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("Employees"))
      |> assign(:show_invite_modal, false)
      |> assign(:show_bulk_upload_modal, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    opts = %{
      search: params["search"],
      sort_by: parse_sort_by(params["sort_by"]),
      sort_order: parse_sort_order(params["sort_order"]),
      status: params["status"],
      page: parse_page(params["page"])
    }

    {employees, total_count} =
      Accounts.list_employees(socket.assigns.current_scope, opts)

    total_pages = max(ceil(total_count / 20), 1)

    socket =
      socket
      |> assign(:employees, employees)
      |> assign(:total_count, total_count)
      |> assign(:total_pages, total_pages)
      |> assign(:search, opts.search || "")
      |> assign(:sort_by, opts.sort_by)
      |> assign(:sort_order, opts.sort_order)
      |> assign(:status_filter, opts.status || "")
      |> assign(:page, opts.page)

    {:noreply, socket}
  end

  @impl true
  def handle_info({LmsWeb.Admin.EmployeeLive.InviteFormComponent, {:invited, _user}}, socket) do
    {:noreply,
     socket
     |> assign(:show_invite_modal, false)
     |> push_patch(to: build_path(socket.assigns))}
  end

  def handle_info({LmsWeb.Admin.EmployeeLive.BulkUploadComponent, :done}, socket) do
    {:noreply,
     socket
     |> assign(:show_bulk_upload_modal, false)
     |> push_patch(to: build_path(socket.assigns))}
  end

  def handle_info({:email, _email}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    params = %{socket.assigns | search: search, page: 1}
    {:noreply, push_patch(socket, to: build_path(params))}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    params = %{socket.assigns | status_filter: status, page: 1}
    {:noreply, push_patch(socket, to: build_path(params))}
  end

  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    {sort_by, sort_order} =
      if socket.assigns.sort_by == field do
        {field, toggle_order(socket.assigns.sort_order)}
      else
        {field, :asc}
      end

    params = %{socket.assigns | sort_by: sort_by, sort_order: sort_order}
    {:noreply, push_patch(socket, to: build_path(params))}
  end

  def handle_event("page", %{"page" => page}, socket) do
    params = %{socket.assigns | page: String.to_integer(page)}
    {:noreply, push_patch(socket, to: build_path(params))}
  end

  def handle_event("open_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  def handle_event("close_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, false)}
  end

  def handle_event("open_bulk_upload_modal", _params, socket) do
    {:noreply, assign(socket, :show_bulk_upload_modal, true)}
  end

  def handle_event("close_bulk_upload_modal", _params, socket) do
    {:noreply, assign(socket, :show_bulk_upload_modal, false)}
  end

  @impl true
  def handle_event("resend_invitation", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.resend_invitation(user, &url(~p"/invitations/#{&1}")) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Invitation resent to %{email}.", email: user.email))
         |> push_patch(to: build_path(socket.assigns))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not resend invitation."))}
    end
  end

  def handle_event("promote", %{"id" => id}, socket) do
    change_role(socket, id, :course_creator, gettext("promoted to Course Creator"))
  end

  def handle_event("demote", %{"id" => id}, socket) do
    change_role(socket, id, :employee, gettext("demoted to Employee"))
  end

  defp change_role(socket, user_id, new_role, success_label) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_role(socket.assigns.current_scope, user, new_role) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("%{name} has been %{action}.",
             name: user.name || user.email,
             action: success_label
           )
         )
         |> push_patch(to: build_path(socket.assigns))}

      {:error, :cannot_change_own_role} ->
        {:noreply, put_flash(socket, :error, gettext("You cannot change your own role."))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not update role."))}
    end
  end

  defp parse_sort_by(nil), do: :name

  defp parse_sort_by(field) when is_binary(field) do
    field_atom = String.to_existing_atom(field)
    if field_atom in @sort_fields, do: field_atom, else: :name
  rescue
    ArgumentError -> :name
  end

  defp parse_sort_order(nil), do: :asc

  defp parse_sort_order(order) when is_binary(order) do
    order_atom = String.to_existing_atom(order)
    if order_atom in @sort_orders, do: order_atom, else: :asc
  rescue
    ArgumentError -> :asc
  end

  defp parse_page(nil), do: 1

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  defp build_path(assigns) do
    params =
      %{}
      |> maybe_put(:search, assigns.search)
      |> maybe_put(:sort_by, to_string(assigns.sort_by), "name")
      |> maybe_put(:sort_order, to_string(assigns.sort_order), "asc")
      |> maybe_put(:status, assigns.status_filter)
      |> maybe_put(:page, to_string(assigns.page), "1")

    ~p"/admin/employees?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-2xl font-bold text-base-content">{gettext("Employees")}</h1>
            <p class="mt-1 text-sm text-base-content/60">
              {gettext("Manage your team members and send invitations.")}
            </p>
          </div>
          <div class="flex gap-2">
            <button class="btn btn-outline btn-sm" phx-click="open_bulk_upload_modal">
              <.icon name="hero-arrow-up-tray" class="size-4 mr-1" />
              {gettext("Bulk Upload")}
            </button>
            <.button variant="primary" phx-click="open_invite_modal">
              <.icon name="hero-plus" class="size-4 mr-1" />
              {gettext("Invite Employee")}
            </.button>
          </div>
        </div>

        <%!-- Search and filter bar --%>
        <div class="flex flex-col sm:flex-row gap-3 mb-6">
          <form id="search-form" phx-change="search" phx-submit="search" class="flex-1">
            <.input
              type="text"
              name="search"
              value={@search}
              placeholder={gettext("Search by name or email...")}
              phx-debounce="300"
            />
          </form>
          <form id="status-filter-form" phx-change="filter_status" class="w-full sm:w-48">
            <select
              name="status"
              class="select select-bordered w-full bg-base-100 text-base-content border-base-300"
            >
              <option value="" selected={@status_filter == ""}>
                {gettext("All statuses")}
              </option>
              <option value="active" selected={@status_filter == "active"}>
                {gettext("Active")}
              </option>
              <option value="invited" selected={@status_filter == "invited"}>
                {gettext("Invited")}
              </option>
            </select>
          </form>
        </div>

        <%!-- Empty state --%>
        <div :if={@employees == [] && @search == "" && @status_filter == ""} class="text-center py-12">
          <.icon name="hero-users" class="size-12 text-base-content/30 mx-auto mb-4" />
          <p class="text-base-content/60">
            {gettext("No employees yet. Invite your first team member!")}
          </p>
        </div>

        <%!-- No results state --%>
        <div
          :if={@employees == [] && (@search != "" || @status_filter != "")}
          class="text-center py-12"
        >
          <.icon name="hero-magnifying-glass" class="size-12 text-base-content/30 mx-auto mb-4" />
          <p class="text-base-content/60">
            {gettext("No employees match your search criteria.")}
          </p>
        </div>

        <%!-- Employee table --%>
        <div :if={@employees != []} class="overflow-x-auto">
          <table class="table table-zebra" id="employees">
            <thead>
              <tr>
                <th
                  :for={
                    {label, field} <- [
                      {gettext("Name"), :name},
                      {gettext("Email"), :email},
                      {gettext("Status"), :status},
                      {gettext("Role"), :role}
                    ]
                  }
                  phx-click="sort"
                  phx-value-field={field}
                  class="cursor-pointer select-none hover:bg-base-200 transition-colors"
                >
                  {label}
                  <.sort_indicator sort_by={@sort_by} sort_order={@sort_order} field={field} />
                </th>
                <th>
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={employee <- @employees}
                id={"employee-#{employee.id}"}
                class="hover:bg-base-200/50 transition-colors"
              >
                <td class="font-medium">{employee.name || "—"}</td>
                <td>{employee.email}</td>
                <td>
                  <span class={[
                    "badge badge-sm",
                    employee.status == :active && "badge-success",
                    employee.status == :invited && "badge-info"
                  ]}>
                    {employee.status}
                  </span>
                </td>
                <td class="capitalize">{employee.role}</td>
                <td>
                  <div class="flex gap-1">
                    <button
                      :if={employee.status == :invited}
                      phx-click="resend_invitation"
                      phx-value-id={employee.id}
                      class="btn btn-ghost btn-xs text-primary"
                    >
                      <.icon name="hero-arrow-path" class="size-3.5 mr-1" />
                      {gettext("Resend")}
                    </button>
                    <button
                      :if={employee.role == :employee && employee.status == :active}
                      phx-click="promote"
                      phx-value-id={employee.id}
                      data-confirm={
                        gettext("Promote %{name} to Course Creator?",
                          name: employee.name || employee.email
                        )
                      }
                      class="btn btn-ghost btn-xs text-primary"
                    >
                      <.icon name="hero-arrow-up-circle" class="size-3.5 mr-1" />
                      {gettext("Promote")}
                    </button>
                    <button
                      :if={employee.role == :course_creator}
                      phx-click="demote"
                      phx-value-id={employee.id}
                      data-confirm={
                        gettext("Demote %{name} to Employee?",
                          name: employee.name || employee.email
                        )
                      }
                      class="btn btn-ghost btn-xs text-warning"
                    >
                      <.icon name="hero-arrow-down-circle" class="size-3.5 mr-1" />
                      {gettext("Demote")}
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Pagination --%>
        <div :if={@total_pages > 1} class="flex items-center justify-between mt-6">
          <p class="text-sm text-base-content/60">
            {gettext("Showing page %{page} of %{total} (%{count} employees)",
              page: @page,
              total: @total_pages,
              count: @total_count
            )}
          </p>
          <div class="join">
            <button
              :if={@page > 1}
              phx-click="page"
              phx-value-page={@page - 1}
              class="join-item btn btn-sm"
            >
              {gettext("Previous")}
            </button>
            <button
              :for={p <- pagination_range(@page, @total_pages)}
              phx-click="page"
              phx-value-page={p}
              class={["join-item btn btn-sm", p == @page && "btn-active"]}
            >
              {p}
            </button>
            <button
              :if={@page < @total_pages}
              phx-click="page"
              phx-value-page={@page + 1}
              class="join-item btn btn-sm"
            >
              {gettext("Next")}
            </button>
          </div>
        </div>

        <.live_component
          :if={@show_invite_modal}
          module={LmsWeb.Admin.EmployeeLive.InviteFormComponent}
          id="invite-form"
          current_scope={@current_scope}
        />

        <.live_component
          :if={@show_bulk_upload_modal}
          module={LmsWeb.Admin.EmployeeLive.BulkUploadComponent}
          id="bulk-upload"
          current_scope={@current_scope}
        />
      </div>
    </Layouts.app>
    """
  end
end
