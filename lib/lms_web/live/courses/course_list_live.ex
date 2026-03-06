defmodule LmsWeb.Courses.CourseListLive do
  use LmsWeb, :live_view

  alias Lms.Training

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("Courses"))
      |> assign(:view_mode, "grid")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = parse_status(params["status"])

    courses =
      Training.list_courses(
        socket.assigns.current_scope.user.company_id,
        %{status: status}
      )

    socket =
      socket
      |> assign(:courses, courses)
      |> assign(:status_filter, params["status"] || "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    params = if status == "", do: %{}, else: %{status: status}
    {:noreply, push_patch(socket, to: ~p"/courses?#{params}")}
  end

  def handle_event("toggle_layout", %{"layout" => layout}, socket) do
    {:noreply, assign(socket, :view_mode, layout)}
  end

  def handle_event("publish", %{"id" => id}, socket) do
    course = Training.get_course!(id)

    case Training.publish_course(course) do
      {:ok, _course} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Course published successfully."))
         |> push_patch(to: build_path(socket.assigns))}

      {:error, :no_content} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Cannot publish: course needs at least one chapter with a lesson.")
         )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not publish course."))}
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    course = Training.get_course!(id)

    case Training.archive_course(course) do
      {:ok, _course} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Course archived successfully."))
         |> push_patch(to: build_path(socket.assigns))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not archive course."))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    course = Training.get_course!(id)

    case Training.delete_course(course) do
      {:ok, _course} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Course deleted successfully."))
         |> push_patch(to: build_path(socket.assigns))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Could not delete course."))}
    end
  end

  defp parse_status(nil), do: nil
  defp parse_status(""), do: nil

  defp parse_status(status) when is_binary(status) do
    String.to_existing_atom(status)
  rescue
    ArgumentError -> nil
  end

  defp build_path(assigns) do
    params =
      %{}
      |> maybe_put(:status, assigns.status_filter)

    ~p"/courses?#{params}"
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, ""), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp admin?(user) do
    user.role in [:company_admin, :system_admin]
  end

  defp status_badge_class(:draft), do: "badge-warning"
  defp status_badge_class(:published), do: "badge-success"
  defp status_badge_class(:archived), do: "badge-neutral"
  defp status_badge_class(_), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl">
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-2xl font-bold text-base-content">{gettext("Courses")}</h1>
            <p class="mt-1 text-sm text-base-content/60">
              {gettext("Manage your training courses.")}
            </p>
          </div>
          <.button variant="primary" navigate={~p"/courses/new"}>
            <.icon name="hero-plus" class="size-4 mr-1" />
            {gettext("New Course")}
          </.button>
        </div>

        <%!-- Filter and layout controls --%>
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 mb-6">
          <form id="status-filter-form" phx-change="filter_status" class="w-full sm:w-48">
            <select
              name="status"
              class="select select-bordered w-full bg-base-100 text-base-content border-base-300"
            >
              <option value="" selected={@status_filter == ""}>
                {gettext("All statuses")}
              </option>
              <option value="draft" selected={@status_filter == "draft"}>
                {gettext("Draft")}
              </option>
              <option value="published" selected={@status_filter == "published"}>
                {gettext("Published")}
              </option>
              <option value="archived" selected={@status_filter == "archived"}>
                {gettext("Archived")}
              </option>
            </select>
          </form>

          <div class="flex gap-1 border border-base-300 rounded-lg p-0.5">
            <button
              phx-click="toggle_layout"
              phx-value-layout="grid"
              class={[
                "btn btn-sm btn-ghost",
                @view_mode == "grid" && "btn-active"
              ]}
            >
              <.icon name="hero-squares-2x2" class="size-4" />
            </button>
            <button
              phx-click="toggle_layout"
              phx-value-layout="list"
              class={[
                "btn btn-sm btn-ghost",
                @view_mode == "list" && "btn-active"
              ]}
            >
              <.icon name="hero-list-bullet" class="size-4" />
            </button>
          </div>
        </div>

        <%!-- Empty state --%>
        <div
          :if={@courses == [] && @status_filter == ""}
          class="text-center py-16"
        >
          <.icon
            name="hero-academic-cap"
            class="size-16 text-base-content/20 mx-auto mb-4"
          />
          <h3 class="text-lg font-semibold text-base-content mb-1">
            {gettext("No courses yet")}
          </h3>
          <p class="text-base-content/60 mb-6">
            {gettext("Create your first course to get started.")}
          </p>
          <.button variant="primary" navigate={~p"/courses/new"}>
            <.icon name="hero-plus" class="size-4 mr-1" />
            {gettext("New Course")}
          </.button>
        </div>

        <%!-- No results for filter --%>
        <div
          :if={@courses == [] && @status_filter != ""}
          class="text-center py-16"
        >
          <.icon
            name="hero-funnel"
            class="size-12 text-base-content/20 mx-auto mb-4"
          />
          <p class="text-base-content/60">
            {gettext("No courses match the selected filter.")}
          </p>
        </div>

        <%!-- Grid layout --%>
        <div
          :if={@courses != [] && @view_mode == "grid"}
          class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6"
        >
          <div
            :for={course <- @courses}
            id={"course-#{course.id}"}
            class="card bg-base-100 border border-base-300 shadow-sm rounded-2xl hover:-translate-y-0.5 hover:shadow-md transition-all"
          >
            <figure class="h-40 bg-base-200 overflow-hidden">
              <img
                :if={course.cover_image}
                src={course.cover_image}
                alt={course.title}
                class="w-full h-full object-cover"
              />
              <div
                :if={!course.cover_image}
                class="flex items-center justify-center w-full h-full"
              >
                <.icon
                  name="hero-photo"
                  class="size-12 text-base-content/20"
                />
              </div>
            </figure>
            <div class="card-body p-4">
              <div class="flex items-start justify-between gap-2">
                <h2 class="card-title text-base font-semibold text-base-content line-clamp-2">
                  {course.title}
                </h2>
                <span class={["badge badge-sm shrink-0", status_badge_class(course.status)]}>
                  {course.status}
                </span>
              </div>
              <p :if={course.description} class="text-sm text-base-content/60 line-clamp-2 mt-1">
                {course.description}
              </p>
              <div class="text-xs text-base-content/40 mt-2">
                {gettext("0 enrolled")}
              </div>
              <div class="card-actions mt-3 pt-3 border-t border-base-300">
                <.link navigate={~p"/courses/#{course.id}/editor"} class="btn btn-ghost btn-xs">
                  <.icon name="hero-book-open" class="size-3.5" />
                  {gettext("Content")}
                </.link>
                <.link navigate={~p"/courses/#{course.id}/edit"} class="btn btn-ghost btn-xs">
                  <.icon name="hero-pencil" class="size-3.5" />
                  {gettext("Edit")}
                </.link>
                <.link navigate={~p"/courses/#{course.id}/preview"} class="btn btn-ghost btn-xs">
                  <.icon name="hero-eye" class="size-3.5" />
                  {gettext("Preview")}
                </.link>
                <button
                  :if={course.status == :draft}
                  phx-click="publish"
                  phx-value-id={course.id}
                  data-confirm={gettext("Publish this course?")}
                  class="btn btn-ghost btn-xs text-success"
                >
                  <.icon name="hero-check-circle" class="size-3.5" />
                  {gettext("Publish")}
                </button>
                <button
                  :if={course.status == :published && admin?(@current_scope.user)}
                  phx-click="archive"
                  phx-value-id={course.id}
                  data-confirm={gettext("Archive this course?")}
                  class="btn btn-ghost btn-xs text-warning"
                >
                  <.icon name="hero-archive-box" class="size-3.5" />
                  {gettext("Archive")}
                </button>
                <button
                  :if={course.status == :draft}
                  phx-click="delete"
                  phx-value-id={course.id}
                  data-confirm={gettext("Delete this course? This cannot be undone.")}
                  class="btn btn-ghost btn-xs text-error"
                >
                  <.icon name="hero-trash" class="size-3.5" />
                  {gettext("Delete")}
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- List layout --%>
        <div :if={@courses != [] && @view_mode == "list"} class="overflow-x-auto">
          <table class="table table-zebra" id="courses-table">
            <thead>
              <tr>
                <th>{gettext("Course")}</th>
                <th>{gettext("Status")}</th>
                <th>{gettext("Enrolled")}</th>
                <th>
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :for={course <- @courses} id={"course-row-#{course.id}"}>
                <td>
                  <div class="flex items-center gap-3">
                    <div class="avatar">
                      <div class="w-12 h-12 rounded-lg bg-base-200 overflow-hidden">
                        <img
                          :if={course.cover_image}
                          src={course.cover_image}
                          alt={course.title}
                          class="w-full h-full object-cover"
                        />
                        <div
                          :if={!course.cover_image}
                          class="flex items-center justify-center w-full h-full"
                        >
                          <.icon name="hero-photo" class="size-5 text-base-content/20" />
                        </div>
                      </div>
                    </div>
                    <div>
                      <div class="font-semibold text-base-content">{course.title}</div>
                      <div
                        :if={course.description}
                        class="text-sm text-base-content/60 line-clamp-1"
                      >
                        {course.description}
                      </div>
                    </div>
                  </div>
                </td>
                <td>
                  <span class={["badge badge-sm", status_badge_class(course.status)]}>
                    {course.status}
                  </span>
                </td>
                <td class="text-base-content/60">0</td>
                <td>
                  <div class="flex gap-1">
                    <.link
                      navigate={~p"/courses/#{course.id}/editor"}
                      class="btn btn-ghost btn-xs"
                    >
                      <.icon name="hero-book-open" class="size-3.5" />
                      {gettext("Content")}
                    </.link>
                    <.link
                      navigate={~p"/courses/#{course.id}/edit"}
                      class="btn btn-ghost btn-xs"
                    >
                      <.icon name="hero-pencil" class="size-3.5" />
                      {gettext("Edit")}
                    </.link>
                    <.link
                      navigate={~p"/courses/#{course.id}/preview"}
                      class="btn btn-ghost btn-xs"
                    >
                      <.icon name="hero-eye" class="size-3.5" />
                      {gettext("Preview")}
                    </.link>
                    <button
                      :if={course.status == :draft}
                      phx-click="publish"
                      phx-value-id={course.id}
                      data-confirm={gettext("Publish this course?")}
                      class="btn btn-ghost btn-xs text-success"
                    >
                      {gettext("Publish")}
                    </button>
                    <button
                      :if={course.status == :published && admin?(@current_scope.user)}
                      phx-click="archive"
                      phx-value-id={course.id}
                      data-confirm={gettext("Archive this course?")}
                      class="btn btn-ghost btn-xs text-warning"
                    >
                      {gettext("Archive")}
                    </button>
                    <button
                      :if={course.status == :draft}
                      phx-click="delete"
                      phx-value-id={course.id}
                      data-confirm={gettext("Delete this course? This cannot be undone.")}
                      class="btn btn-ghost btn-xs text-error"
                    >
                      {gettext("Delete")}
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
