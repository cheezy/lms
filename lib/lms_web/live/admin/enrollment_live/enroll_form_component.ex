defmodule LmsWeb.Admin.EnrollmentLive.EnrollFormComponent do
  use LmsWeb, :live_component

  alias Lms.Accounts
  alias Lms.Accounts.UserNotifier
  alias Lms.Learning

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:selected_user_ids, [])
     |> assign(:selected_course_id, nil)
     |> assign(:due_date, nil)}
  end

  @impl true
  def update(assigns, socket) do
    company_id = assigns.current_scope.user.company_id

    employees =
      Accounts.list_employees(assigns.current_scope, %{sort_by: :name, sort_order: :asc})
      |> elem(0)

    courses = Learning.list_published_courses(company_id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:employees, employees)
     |> assign(:courses, courses)}
  end

  @impl true
  def handle_event("toggle_employee", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = socket.assigns.selected_user_ids

    selected =
      if id in selected do
        List.delete(selected, id)
      else
        [id | selected]
      end

    {:noreply, assign(socket, :selected_user_ids, selected)}
  end

  def handle_event("select_course", %{"course_id" => ""}, socket) do
    {:noreply, assign(socket, :selected_course_id, nil)}
  end

  def handle_event("select_course", %{"course_id" => id}, socket) do
    {:noreply, assign(socket, :selected_course_id, String.to_integer(id))}
  end

  def handle_event("set_due_date", %{"due_date" => ""}, socket) do
    {:noreply, assign(socket, :due_date, nil)}
  end

  def handle_event("set_due_date", %{"due_date" => date}, socket) do
    {:noreply, assign(socket, :due_date, Date.from_iso8601!(date))}
  end

  def handle_event("enroll", _params, socket) do
    user_ids = socket.assigns.selected_user_ids
    course_id = socket.assigns.selected_course_id
    due_date = socket.assigns.due_date

    if user_ids == [] || course_id == nil do
      {:noreply, put_flash(socket, :error, gettext("Please select employees and a course."))}
    else
      {successful, _failed} =
        Learning.enroll_employees(user_ids, course_id, %{due_date: due_date})

      course = Enum.find(socket.assigns.courses, &(&1.id == course_id))

      for enrollment <- successful do
        user = Accounts.get_user!(enrollment.user_id)
        UserNotifier.deliver_enrollment_notification(user, course.title)
      end

      send(self(), {__MODULE__, {:enrolled, length(successful)}})

      {:noreply,
       socket
       |> put_flash(
         :info,
         gettext("%{count} employee(s) enrolled successfully.", count: length(successful))
       )
       |> push_navigate(to: ~p"/admin/enrollments")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal modal-open">
      <div class="modal-box bg-base-100 max-w-lg">
        <button
          type="button"
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
          phx-click="close_enroll_modal"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>

        <h3 class="text-lg font-bold text-base-content mb-4">
          {gettext("Enroll Employees")}
        </h3>

        <div class="space-y-4">
          <%!-- Course selection --%>
          <div>
            <label class="label text-base-content font-medium">
              {gettext("Course")}
            </label>
            <select
              name="course_id"
              phx-change="select_course"
              phx-target={@myself}
              class="select select-bordered w-full bg-base-100 text-base-content border-base-300"
            >
              <option value="">{gettext("Select a course...")}</option>
              <option
                :for={course <- @courses}
                value={course.id}
                selected={course.id == @selected_course_id}
              >
                {course.title}
              </option>
            </select>
          </div>

          <%!-- Due date --%>
          <div>
            <label class="label text-base-content font-medium">
              {gettext("Due date (optional)")}
            </label>
            <input
              type="date"
              name="due_date"
              value={@due_date}
              phx-change="set_due_date"
              phx-target={@myself}
              class="input input-bordered w-full bg-base-100 text-base-content border-base-300"
            />
          </div>

          <%!-- Employee multiselect --%>
          <div>
            <label class="label text-base-content font-medium">
              {gettext("Employees (%{count} selected)", count: length(@selected_user_ids))}
            </label>
            <div class="max-h-48 overflow-y-auto border border-base-300 rounded-lg">
              <div
                :for={employee <- @employees}
                class="flex items-center gap-3 px-3 py-2 hover:bg-base-200 transition-colors cursor-pointer"
                phx-click="toggle_employee"
                phx-value-id={employee.id}
                phx-target={@myself}
              >
                <input
                  type="checkbox"
                  checked={employee.id in @selected_user_ids}
                  class="checkbox checkbox-sm checkbox-primary"
                  tabindex="-1"
                />
                <div>
                  <p class="text-sm font-medium text-base-content">
                    {employee.name || employee.email}
                  </p>
                  <p :if={employee.name} class="text-xs text-base-content/60">
                    {employee.email}
                  </p>
                </div>
              </div>
              <div :if={@employees == []} class="px-3 py-4 text-center text-base-content/60">
                {gettext("No employees available.")}
              </div>
            </div>
          </div>

          <div class="modal-action">
            <button type="button" class="btn" phx-click="close_enroll_modal">
              {gettext("Cancel")}
            </button>
            <.button
              variant="primary"
              phx-click="enroll"
              phx-target={@myself}
              phx-disable-with={gettext("Enrolling...")}
              disabled={@selected_user_ids == [] || @selected_course_id == nil}
            >
              <.icon name="hero-academic-cap" class="size-4 mr-1" />
              {gettext("Enroll")}
            </.button>
          </div>
        </div>
      </div>
      <div class="modal-backdrop bg-base-200/90" phx-click="close_enroll_modal"></div>
    </div>
    """
  end
end
