defmodule LmsWeb.Employee.MyLearningLive do
  use LmsWeb, :live_view

  alias Lms.Learning

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    enrollments = Learning.list_user_enrollments(user_id)

    socket =
      socket
      |> assign(:page_title, gettext("My Learning"))
      |> assign(:enrollments, enrollments)

    {:ok, socket}
  end

  defp format_progress(progress) do
    :erlang.float_to_binary(progress, decimals: 0) <> "%"
  end

  defp status_label(enrollment) do
    status = Learning.enrollment_status(enrollment, enrollment.progress)

    case status do
      :not_started -> gettext("Not Started")
      :in_progress -> gettext("In Progress")
      :completed -> gettext("Completed")
      :overdue -> gettext("Overdue")
    end
  end

  defp status_class(enrollment) do
    status = Learning.enrollment_status(enrollment, enrollment.progress)

    case status do
      :not_started -> "badge-ghost"
      :in_progress -> "badge-info"
      :completed -> "badge-success"
      :overdue -> "badge-error"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{gettext("My Learning")}</h1>
          <p class="mt-1 text-sm text-base-content/60">
            {gettext("Track your course progress and continue learning.")}
          </p>
        </div>

        <div :if={@enrollments == []} class="text-center py-12">
          <.icon name="hero-book-open" class="size-12 text-base-content/30 mx-auto mb-4" />
          <p class="text-base-content/60">
            {gettext("You are not enrolled in any courses yet.")}
          </p>
        </div>

        <div :if={@enrollments != []} class="grid gap-4">
          <.link
            :for={enrollment <- @enrollments}
            navigate={~p"/my-learning/#{enrollment.course_id}"}
            class="block rounded-lg border border-base-300 bg-base-100 p-5 transition-all hover:shadow-md hover:border-primary/30"
          >
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <h3 class="text-lg font-semibold text-base-content truncate">
                  {enrollment.course.title}
                </h3>
                <p
                  :if={enrollment.course.description}
                  class="mt-1 text-sm text-base-content/60 line-clamp-2"
                >
                  {enrollment.course.description}
                </p>
              </div>
              <span class={"badge badge-sm #{status_class(enrollment)}"}>
                {status_label(enrollment)}
              </span>
            </div>

            <div class="mt-4">
              <div class="flex items-center justify-between mb-1">
                <span class="text-xs text-base-content/60">{gettext("Progress")}</span>
                <span class="text-xs font-medium text-base-content/70">
                  {format_progress(enrollment.progress)}
                </span>
              </div>
              <div class="w-full bg-base-300 rounded-full h-2">
                <div
                  class="bg-primary h-2 rounded-full transition-all"
                  style={"width: #{enrollment.progress}%"}
                >
                </div>
              </div>
            </div>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
