defmodule LmsWeb.DashboardLive do
  use LmsWeb, :live_view

  alias Lms.Companies

  @impl true
  def mount(_params, _session, socket) do
    company_id = socket.assigns.current_scope.user.company_id
    stats = load_stats(company_id)

    socket =
      socket
      |> assign(:page_title, gettext("Dashboard"))
      |> assign(:stats, stats)

    {:ok, socket}
  end

  defp load_stats(nil), do: empty_stats()
  defp load_stats(company_id), do: Companies.company_dashboard_stats(company_id)

  defp empty_stats do
    %{
      total_employees: 0,
      active_employees: 0,
      total_courses: 0,
      published_courses: 0,
      draft_courses: 0,
      total_enrollments: 0,
      completed_enrollments: 0,
      overdue_enrollments: 0,
      completion_rate: 0.0,
      recent_enrollments: [],
      recent_completions: []
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-base-content">
              {gettext("Dashboard")}
            </h1>
            <p class="text-sm text-base-content/60 mt-1">
              {gettext("Overview of your company's learning platform")}
            </p>
          </div>
        </div>

        <%!-- Stats Grid --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <.stat_card
            label={gettext("Total Employees")}
            value={@stats.total_employees}
            detail={gettext("%{count} active", count: @stats.active_employees)}
            icon="hero-users"
            color="primary"
          />
          <.stat_card
            label={gettext("Courses")}
            value={@stats.total_courses}
            detail={gettext("%{count} published", count: @stats.published_courses)}
            icon="hero-academic-cap"
            color="secondary"
          />
          <.stat_card
            label={gettext("Enrollments")}
            value={@stats.total_enrollments}
            detail={gettext("%{count} completed", count: @stats.completed_enrollments)}
            icon="hero-clipboard-document-list"
            color="accent"
          />
          <.stat_card
            label={gettext("Completion Rate")}
            value={format_rate(@stats.completion_rate)}
            detail={overdue_text(@stats.overdue_enrollments)}
            icon="hero-chart-bar"
            color={if @stats.overdue_enrollments > 0, do: "warning", else: "success"}
          />
        </div>

        <%!-- Quick Actions --%>
        <div>
          <h2 class="text-lg font-semibold text-base-content mb-3">
            {gettext("Quick Actions")}
          </h2>
          <div class="flex flex-wrap gap-3">
            <.link navigate={~p"/admin/employees"} class="btn btn-primary btn-sm gap-2">
              <.icon name="hero-user-plus" class="size-4" />
              {gettext("Add Employee")}
            </.link>
            <.link navigate={~p"/courses/new"} class="btn btn-secondary btn-sm gap-2">
              <.icon name="hero-plus" class="size-4" />
              {gettext("Create Course")}
            </.link>
            <.link navigate={~p"/admin/enrollments"} class="btn btn-accent btn-sm gap-2">
              <.icon name="hero-clipboard-document-list" class="size-4" />
              {gettext("Manage Enrollments")}
            </.link>
          </div>
        </div>

        <%!-- Activity Feed --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="bg-base-200 rounded-2xl p-5">
            <h3 class="text-base font-semibold text-base-content mb-4 flex items-center gap-2">
              <.icon name="hero-arrow-trending-up" class="size-5 text-primary" />
              {gettext("Recent Enrollments")}
            </h3>
            <div :if={@stats.recent_enrollments == []} class="text-sm text-base-content/50 py-4">
              {gettext("No enrollments yet.")}
            </div>
            <ul :if={@stats.recent_enrollments != []} class="divide-y divide-base-300">
              <li
                :for={enrollment <- @stats.recent_enrollments}
                class="flex items-center justify-between py-3 first:pt-0 last:pb-0"
              >
                <div class="min-w-0">
                  <p class="text-sm font-medium text-base-content truncate">
                    {enrollment.user.name || enrollment.user.email}
                  </p>
                  <p class="text-xs text-base-content/50 truncate">{enrollment.course.title}</p>
                </div>
                <span class="text-xs text-base-content/40 shrink-0 ml-2">
                  {format_relative_date(enrollment.enrolled_at)}
                </span>
              </li>
            </ul>
          </div>

          <div class="bg-base-200 rounded-2xl p-5">
            <h3 class="text-base font-semibold text-base-content mb-4 flex items-center gap-2">
              <.icon name="hero-check-badge" class="size-5 text-success" />
              {gettext("Recent Completions")}
            </h3>
            <div :if={@stats.recent_completions == []} class="text-sm text-base-content/50 py-4">
              {gettext("No completions yet.")}
            </div>
            <ul :if={@stats.recent_completions != []} class="divide-y divide-base-300">
              <li
                :for={enrollment <- @stats.recent_completions}
                class="flex items-center justify-between py-3 first:pt-0 last:pb-0"
              >
                <div class="min-w-0">
                  <p class="text-sm font-medium text-base-content truncate">
                    {enrollment.user.name || enrollment.user.email}
                  </p>
                  <p class="text-xs text-base-content/50 truncate">{enrollment.course.title}</p>
                </div>
                <span class="text-xs text-base-content/40 shrink-0 ml-2">
                  {format_relative_date(enrollment.completed_at)}
                </span>
              </li>
            </ul>
          </div>
        </div>

        <%!-- Navigation Links --%>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <.nav_card
            title={gettext("Employees")}
            description={gettext("Manage your team")}
            icon="hero-users"
            href={~p"/admin/employees"}
          />
          <.nav_card
            title={gettext("Courses")}
            description={gettext("Create and manage courses")}
            icon="hero-academic-cap"
            href={~p"/courses"}
          />
          <.nav_card
            title={gettext("Enrollments")}
            description={gettext("Track progress and completions")}
            icon="hero-clipboard-document-list"
            href={~p"/admin/enrollments"}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-2xl p-4 hover:-translate-y-0.5 hover:shadow-md transition-all">
      <div class="flex items-center gap-2 mb-2">
        <div class={"p-2 rounded-lg bg-#{@color}/10"}>
          <.icon name={@icon} class={"size-5 text-#{@color}"} />
        </div>
      </div>
      <p class="text-2xl font-bold text-base-content">{@value}</p>
      <p class="text-xs text-base-content/50 mt-1">{@label}</p>
      <p :if={@detail} class="text-xs text-base-content/40 mt-0.5">{@detail}</p>
    </div>
    """
  end

  defp nav_card(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="bg-base-200 rounded-2xl p-4 flex items-center gap-3 hover:bg-base-300 hover:-translate-y-0.5 hover:shadow-md transition-all group"
    >
      <.icon name={@icon} class="size-6 text-primary/60 group-hover:text-primary transition-colors" />
      <div>
        <p class="text-sm font-medium text-base-content">{@title}</p>
        <p class="text-xs text-base-content/50">{@description}</p>
      </div>
      <.icon name="hero-chevron-right" class="size-4 text-base-content/30 ml-auto" />
    </.link>
    """
  end

  defp format_rate(rate) do
    :erlang.float_to_binary(rate, decimals: 0) <> "%"
  end

  defp overdue_text(0), do: gettext("No overdue")
  defp overdue_text(count), do: gettext("%{count} overdue", count: count)

  defp format_relative_date(nil), do: ""

  defp format_relative_date(datetime) do
    days = DateTime.diff(DateTime.utc_now(), datetime, :day)

    cond do
      days == 0 -> gettext("Today")
      days == 1 -> gettext("Yesterday")
      days < 7 -> gettext("%{count}d ago", count: days)
      days < 30 -> gettext("%{count}w ago", count: div(days, 7))
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
