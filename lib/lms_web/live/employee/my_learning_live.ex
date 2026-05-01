defmodule LmsWeb.Employee.MyLearningLive do
  use LmsWeb, :live_view

  import LmsWeb.LiveHelpers, only: [format_progress: 1]

  alias Lms.Learning

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    enrollments = Learning.list_user_enrollments(user_id)
    grouped = group_enrollments(enrollments)

    socket =
      socket
      |> assign(:page_title, gettext("My Learning"))
      |> assign(:in_progress, grouped.in_progress)
      |> assign(:not_started, grouped.not_started)
      |> assign(:completed, grouped.completed)
      |> assign(:has_enrollments, enrollments != [])

    {:ok, socket}
  end

  defp group_enrollments(enrollments) do
    grouped =
      Enum.group_by(enrollments, fn enrollment ->
        Learning.enrollment_status(enrollment, enrollment.progress)
      end)

    in_progress =
      Map.get(grouped, :in_progress, []) ++ Map.get(grouped, :overdue, [])

    not_started = Map.get(grouped, :not_started, [])
    completed = Map.get(grouped, :completed, [])

    %{
      in_progress: Enum.sort_by(in_progress, & &1.due_date, &due_date_sorter/2),
      not_started: Enum.sort_by(not_started, & &1.due_date, &due_date_sorter/2),
      completed: Enum.sort_by(completed, & &1.completed_at, {:desc, DateTime})
    }
  end

  defp due_date_sorter(nil, nil), do: true
  defp due_date_sorter(nil, _), do: false
  defp due_date_sorter(_, nil), do: true
  defp due_date_sorter(a, b), do: Date.compare(a, b) != :gt

  defp total_lessons(enrollment), do: enrollment.total_lessons

  defp completed_lessons(enrollment), do: enrollment.completed_lessons

  defp format_date(nil), do: nil
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_date(%Date{} = d), do: Calendar.strftime(d, "%b %d, %Y")

  defp overdue?(enrollment) do
    enrollment.due_date != nil and
      enrollment.completed_at == nil and
      Date.compare(enrollment.due_date, Date.utc_today()) == :lt
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8 flex items-center gap-4">
          <div class="rounded-2xl bg-primary/10 p-3">
            <.icon name="hero-book-open" class="size-8 text-primary" />
          </div>
          <div>
            <h1 class="text-2xl font-bold text-base-content">{gettext("My Learning")}</h1>
            <p class="mt-0.5 text-sm text-base-content/60">
              {gettext("Pick up where you left off and keep building your skills.")}
            </p>
          </div>
        </div>

        <div :if={!@has_enrollments} class="text-center py-12">
          <.icon name="hero-book-open" class="size-12 text-base-content/30 mx-auto mb-4" />
          <p class="text-base-content/60">
            {gettext("You are not enrolled in any courses yet.")}
          </p>
        </div>

        <div :if={@has_enrollments} class="space-y-10">
          <%!-- In Progress Section --%>
          <section :if={@in_progress != []}>
            <h2 class="text-lg font-semibold text-base-content mb-4 flex items-center gap-2">
              <.icon name="hero-play-circle" class="size-5 text-info" />
              {gettext("In Progress")}
              <span class="badge badge-sm badge-primary">{length(@in_progress)}</span>
            </h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <.course_card
                :for={enrollment <- @in_progress}
                enrollment={enrollment}
                variant={:in_progress}
              />
            </div>
          </section>

          <%!-- Not Started Section --%>
          <section :if={@not_started != []}>
            <h2 class="text-lg font-semibold text-base-content mb-4 flex items-center gap-2">
              <.icon name="hero-clock" class="size-5 text-base-content/50" />
              {gettext("Not Started")}
              <span class="badge badge-sm badge-primary">{length(@not_started)}</span>
            </h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <.course_card
                :for={enrollment <- @not_started}
                enrollment={enrollment}
                variant={:not_started}
              />
            </div>
          </section>

          <%!-- Completed Section --%>
          <section :if={@completed != []}>
            <h2 class="text-lg font-semibold text-base-content mb-4 flex items-center gap-2">
              <.icon name="hero-check-circle" class="size-5 text-success" />
              {gettext("Completed")}
              <span class="badge badge-sm badge-primary">{length(@completed)}</span>
            </h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <.course_card
                :for={enrollment <- @completed}
                enrollment={enrollment}
                variant={:completed}
              />
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp course_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/my-learning/#{@enrollment.course_id}"}
      class="group block rounded-2xl border border-base-300 bg-base-100 overflow-hidden hover:-translate-y-0.5 hover:shadow-md hover:border-primary/30 transition-all"
    >
      <%!-- Cover image --%>
      <div class="aspect-video bg-base-200 relative overflow-hidden">
        <img
          :if={@enrollment.course.cover_image}
          src={@enrollment.course.cover_image}
          alt={@enrollment.course.title}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
        />
        <div
          :if={!@enrollment.course.cover_image}
          class="w-full h-full flex items-center justify-center"
        >
          <.icon name="hero-academic-cap" class="size-12 text-base-content/20" />
        </div>
        <div
          :if={overdue?(@enrollment)}
          class="absolute top-2 right-2 badge badge-error badge-sm gap-1"
        >
          <.icon name="hero-exclamation-triangle" class="size-3" />
          {gettext("Overdue")}
        </div>
      </div>

      <%!-- Card body --%>
      <div class="p-4 space-y-3">
        <h3 class="font-semibold text-base-content line-clamp-2 leading-tight">
          {@enrollment.course.title}
        </h3>

        <%!-- In Progress details --%>
        <div :if={@variant == :in_progress} class="space-y-2">
          <div>
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs text-base-content/60">
                {gettext("%{completed} of %{total} lessons",
                  completed: completed_lessons(@enrollment),
                  total: total_lessons(@enrollment)
                )}
              </span>
              <span class="text-xs font-medium text-base-content/70">
                {format_progress(@enrollment.progress)}
              </span>
            </div>
            <div class="w-full bg-base-300 rounded-full h-2">
              <div
                class="bg-primary h-2 rounded-full transition-all"
                style={"width: #{@enrollment.progress}%"}
              >
              </div>
            </div>
          </div>
          <div class="flex items-center justify-between text-xs text-base-content/50">
            <span :if={@enrollment.last_activity}>
              {gettext("Last activity: %{date}", date: format_date(@enrollment.last_activity))}
            </span>
            <span :if={@enrollment.due_date}>
              {gettext("Due: %{date}", date: format_date(@enrollment.due_date))}
            </span>
          </div>
        </div>

        <%!-- Not Started details --%>
        <div :if={@variant == :not_started} class="text-xs text-base-content/50">
          <span :if={@enrollment.due_date}>
            {gettext("Due: %{date}", date: format_date(@enrollment.due_date))}
          </span>
          <span :if={!@enrollment.due_date}>
            {gettext("No due date")}
          </span>
        </div>

        <%!-- Completed details --%>
        <div :if={@variant == :completed} class="flex items-center gap-1 text-xs text-success">
          <.icon name="hero-check-circle" class="size-4" />
          <span>
            {gettext("Completed %{date}", date: format_date(@enrollment.completed_at))}
          </span>
        </div>
      </div>
    </.link>
    """
  end
end
