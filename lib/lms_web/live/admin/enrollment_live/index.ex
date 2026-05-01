defmodule LmsWeb.Admin.EnrollmentLive.Index do
  use LmsWeb, :live_view

  import LmsWeb.LiveHelpers,
    only: [format_progress: 1, maybe_put: 3, maybe_put: 4, pagination_range: 2]

  import LmsWeb.SharedComponents, only: [sort_indicator: 1]

  alias Lms.Learning

  @sort_fields ~w(employee course due_date)a
  @sort_orders ~w(asc desc)a

  @impl true
  def mount(_params, _session, socket) do
    company_id = socket.assigns.current_scope.user.company_id
    courses = Learning.list_published_courses(company_id)

    socket =
      socket
      |> assign(:page_title, gettext("Enrollments"))
      |> assign(:show_enroll_modal, false)
      |> assign(:courses, courses)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    company_id = socket.assigns.current_scope.user.company_id
    opts = parse_params(params)
    {enrollments, total_count} = Learning.list_enrollments_for_company(company_id, opts)
    total_pages = max(ceil(total_count / 20), 1)

    {:noreply, assign_enrollment_data(socket, enrollments, total_count, total_pages, opts)}
  end

  @impl true
  def handle_info(
        {LmsWeb.Admin.EnrollmentLive.EnrollFormComponent, {:enrolled, _count}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:show_enroll_modal, false)
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

  def handle_event("filter_course", %{"course_id" => course_id}, socket) do
    course_filter = if course_id == "", do: nil, else: String.to_integer(course_id)
    params = %{socket.assigns | course_filter: course_filter, page: 1}
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

  def handle_event("open_enroll_modal", _params, socket) do
    {:noreply, assign(socket, :show_enroll_modal, true)}
  end

  def handle_event("close_enroll_modal", _params, socket) do
    {:noreply, assign(socket, :show_enroll_modal, false)}
  end

  defp parse_params(params) do
    %{
      search: params["search"],
      course_id: parse_course_id(params["course_id"]),
      status: params["status"],
      sort_by: parse_sort_by(params["sort_by"]),
      sort_order: parse_sort_order(params["sort_order"]),
      page: parse_page(params["page"])
    }
  end

  defp assign_enrollment_data(socket, enrollments, total_count, total_pages, opts) do
    socket
    |> assign(:enrollments, enrollments)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> assign(:search, opts.search || "")
    |> assign(:course_filter, opts.course_id)
    |> assign(:status_filter, opts.status || "")
    |> assign(:sort_by, opts.sort_by)
    |> assign(:sort_order, opts.sort_order)
    |> assign(:page, opts.page)
  end

  defp parse_sort_by(nil), do: :employee

  defp parse_sort_by(field) when is_binary(field) do
    field_atom = String.to_existing_atom(field)
    if field_atom in @sort_fields, do: field_atom, else: :employee
  rescue
    ArgumentError -> :employee
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

  defp parse_course_id(nil), do: nil
  defp parse_course_id(""), do: nil

  defp parse_course_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, _} -> n
      _ -> nil
    end
  end

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  defp build_path(assigns) do
    params =
      %{}
      |> maybe_put(:search, assigns.search)
      |> maybe_put(:course_id, assigns.course_filter)
      |> maybe_put(:sort_by, to_string(assigns.sort_by), "employee")
      |> maybe_put(:sort_order, to_string(assigns.sort_order), "asc")
      |> maybe_put(:status, assigns.status_filter)
      |> maybe_put(:page, to_string(assigns.page), "1")

    ~p"/admin/enrollments?#{params}"
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      @status == :completed && "badge-success",
      @status == :in_progress && "badge-info",
      @status == :overdue && "badge-error",
      @status == :not_started && "badge-ghost"
    ]}>
      {format_status(@status)}
    </span>
    """
  end

  defp format_status(:not_started), do: gettext("Not Started")
  defp format_status(:in_progress), do: gettext("In Progress")
  defp format_status(:completed), do: gettext("Completed")
  defp format_status(:overdue), do: gettext("Overdue")

  defp format_due_date(nil), do: "—"
  defp format_due_date(date), do: Calendar.strftime(date, "%b %d, %Y")

  defp has_filters?(assigns) do
    assigns.search != "" || assigns.course_filter != nil || assigns.status_filter != ""
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-2xl font-bold text-base-content">{gettext("Enrollments")}</h1>
            <p class="mt-1 text-sm text-base-content/60">
              {gettext("Manage employee course enrollments and track progress.")}
            </p>
          </div>
          <.button variant="primary" phx-click="open_enroll_modal">
            <.icon name="hero-plus" class="size-4 mr-1" />
            {gettext("Enroll Employees")}
          </.button>
        </div>

        <%!-- Search and filter bar --%>
        <div class="flex flex-col sm:flex-row gap-3 mb-6">
          <form id="search-form" phx-change="search" phx-submit="search" class="flex-1">
            <.input
              type="text"
              name="search"
              value={@search}
              placeholder={gettext("Search by employee name or email...")}
              phx-debounce="300"
            />
          </form>
          <form id="course-filter-form" phx-change="filter_course" class="w-full sm:w-48">
            <select
              name="course_id"
              class="select select-bordered w-full bg-base-100 text-base-content border-base-300"
            >
              <option value="" selected={@course_filter == nil}>
                {gettext("All courses")}
              </option>
              <option
                :for={course <- @courses}
                value={course.id}
                selected={@course_filter == course.id}
              >
                {course.title}
              </option>
            </select>
          </form>
          <form id="status-filter-form" phx-change="filter_status" class="w-full sm:w-48">
            <select
              name="status"
              class="select select-bordered w-full bg-base-100 text-base-content border-base-300"
            >
              <option value="" selected={@status_filter == ""}>
                {gettext("All statuses")}
              </option>
              <option value="not_started" selected={@status_filter == "not_started"}>
                {gettext("Not Started")}
              </option>
              <option value="in_progress" selected={@status_filter == "in_progress"}>
                {gettext("In Progress")}
              </option>
              <option value="completed" selected={@status_filter == "completed"}>
                {gettext("Completed")}
              </option>
              <option value="overdue" selected={@status_filter == "overdue"}>
                {gettext("Overdue")}
              </option>
            </select>
          </form>
        </div>

        <%!-- Empty state --%>
        <div :if={@enrollments == [] && !has_filters?(assigns)} class="text-center py-12">
          <.icon name="hero-academic-cap" class="size-12 text-base-content/30 mx-auto mb-4" />
          <p class="text-base-content/60">
            {gettext("No enrollments yet. Enroll your first employees!")}
          </p>
        </div>

        <%!-- No results state --%>
        <div :if={@enrollments == [] && has_filters?(assigns)} class="text-center py-12">
          <.icon
            name="hero-magnifying-glass"
            class="size-12 text-base-content/30 mx-auto mb-4"
          />
          <p class="text-base-content/60">
            {gettext("No enrollments match your search criteria.")}
          </p>
        </div>

        <%!-- Enrollment table --%>
        <div :if={@enrollments != []} class="overflow-x-auto">
          <table class="table table-zebra" id="enrollments">
            <thead>
              <tr>
                <th
                  :for={
                    {label, field} <- [
                      {gettext("Employee"), :employee},
                      {gettext("Course"), :course},
                      {gettext("Due Date"), :due_date}
                    ]
                  }
                  phx-click="sort"
                  phx-value-field={field}
                  class="cursor-pointer select-none hover:bg-base-200 transition-colors"
                >
                  {label}
                  <.sort_indicator sort_by={@sort_by} sort_order={@sort_order} field={field} />
                </th>
                <th>{gettext("Progress")}</th>
                <th>{gettext("Status")}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={enrollment <- @enrollments}
                id={"enrollment-#{enrollment.id}"}
                class="hover:bg-base-200/50 transition-colors"
              >
                <td class="font-medium">
                  {enrollment.user.name || enrollment.user.email}
                </td>
                <td>{enrollment.course.title}</td>
                <td>{format_due_date(enrollment.due_date)}</td>
                <td>
                  <div class="flex items-center gap-2">
                    <div class="w-24 bg-base-300 rounded-full h-2">
                      <div
                        class="bg-primary h-2 rounded-full transition-all"
                        style={"width: #{enrollment.progress}%"}
                      >
                      </div>
                    </div>
                    <span class="text-sm text-base-content/70">
                      {format_progress(enrollment.progress)}
                    </span>
                  </div>
                </td>
                <td>
                  <.status_badge status={Learning.enrollment_status(enrollment, enrollment.progress)} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Pagination --%>
        <div :if={@total_pages > 1} class="flex items-center justify-between mt-6">
          <p class="text-sm text-base-content/60">
            {gettext("Showing page %{page} of %{total} (%{count} enrollments)",
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
          :if={@show_enroll_modal}
          module={LmsWeb.Admin.EnrollmentLive.EnrollFormComponent}
          id="enroll-form"
          current_scope={@current_scope}
        />
      </div>
    </Layouts.app>
    """
  end
end
