defmodule LmsWeb.Courses.CoursePreviewLive do
  use LmsWeb, :live_view

  alias Lms.Training

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    course = Training.get_course_with_contents!(id)
    user = socket.assigns.current_scope.user

    if user.role != :system_admin && course.company_id != user.company_id do
      {:ok,
       socket
       |> put_flash(:error, gettext("You don't have access to this course."))
       |> redirect(to: ~p"/courses")}
    else
      initial_lesson = find_first_lesson(course)

      socket =
        socket
        |> assign(:page_title, course.title)
        |> assign(:course, course)
        |> assign(:current_lesson, initial_lesson)
        |> assign(:sidebar_open, false)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("select_lesson", %{"id" => id}, socket) do
    lesson_id = String.to_integer(id)
    lesson = find_lesson(socket.assigns.course, lesson_id)

    socket =
      socket
      |> assign(:current_lesson, lesson)
      |> assign(:sidebar_open, false)

    {:noreply, socket}
  end

  def handle_event("next_lesson", _params, socket) do
    case next_lesson(socket.assigns.course, socket.assigns.current_lesson) do
      nil -> {:noreply, socket}
      lesson -> {:noreply, assign(socket, :current_lesson, lesson)}
    end
  end

  def handle_event("prev_lesson", _params, socket) do
    case prev_lesson(socket.assigns.course, socket.assigns.current_lesson) do
      nil -> {:noreply, socket}
      lesson -> {:noreply, assign(socket, :current_lesson, lesson)}
    end
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}
  end

  defp find_first_lesson(course) do
    case course.chapters do
      [chapter | _] ->
        case chapter.lessons do
          [lesson | _] -> lesson
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp find_lesson(course, lesson_id) do
    Enum.find_value(course.chapters, fn chapter ->
      Enum.find(chapter.lessons, &(&1.id == lesson_id))
    end)
  end

  defp next_lesson(course, current) do
    lessons = all_lessons(course)
    idx = Enum.find_index(lessons, &(&1.id == current.id))

    if idx && idx < length(lessons) - 1 do
      Enum.at(lessons, idx + 1)
    end
  end

  defp prev_lesson(course, current) do
    lessons = all_lessons(course)
    idx = Enum.find_index(lessons, &(&1.id == current.id))

    if idx && idx > 0 do
      Enum.at(lessons, idx - 1)
    end
  end

  defp all_lessons(course) do
    Enum.flat_map(course.chapters, & &1.lessons)
  end

  defp render_lesson_content(nil), do: ""

  defp render_lesson_content(content) when is_map(content) do
    Training.LessonRenderer.render(content)
  end

  defp render_lesson_content(content) when is_binary(content), do: content

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl">
        <%!-- Header with back link and preview badge --%>
        <div class="mb-6">
          <div class="flex items-center justify-between">
            <.link
              navigate={~p"/courses"}
              class="text-sm text-primary hover:underline inline-flex items-center gap-1"
            >
              <.icon name="hero-arrow-left" class="size-4" />
              {gettext("Back to Courses")}
            </.link>
            <div class="flex items-center gap-2">
              <span class="badge badge-outline badge-warning gap-1">
                <.icon name="hero-eye" class="size-3.5" />
                {gettext("Preview Mode")}
              </span>
              <button
                phx-click="toggle_sidebar"
                class="lg:hidden btn btn-ghost btn-sm"
                aria-label={gettext("Toggle navigation")}
              >
                <.icon name="hero-bars-3" class="size-5" />
              </button>
            </div>
          </div>
          <h1 class="text-2xl font-bold text-base-content mt-2">{@course.title}</h1>
          <p :if={@course.description} class="text-sm text-base-content/60 mt-1">
            {@course.description}
          </p>
        </div>

        <div class="flex gap-6 relative">
          <%!-- Mobile sidebar overlay --%>
          <div
            :if={@sidebar_open}
            class="fixed inset-0 bg-base-200/80 z-40 lg:hidden"
            phx-click="toggle_sidebar"
          >
          </div>

          <%!-- Sidebar: chapter/lesson navigation --%>
          <aside class={[
            "w-72 shrink-0 z-50",
            "lg:relative lg:block",
            @sidebar_open && "fixed inset-y-0 left-0 bg-base-100 shadow-xl p-4 overflow-y-auto",
            !@sidebar_open && "hidden lg:block"
          ]}>
            <div class="flex items-center justify-between mb-4 lg:hidden">
              <span class="font-semibold text-base-content">{gettext("Navigation")}</span>
              <button phx-click="toggle_sidebar" class="btn btn-ghost btn-sm">
                <.icon name="hero-x-mark" class="size-5" />
              </button>
            </div>
            <nav class="sticky top-4 space-y-4">
              <div :for={chapter <- @course.chapters} class="space-y-1">
                <div class="flex items-center justify-between px-3 py-1">
                  <h3 class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">
                    {chapter.title}
                  </h3>
                  <span class="text-xs px-1.5 py-0.5 rounded bg-base-200 text-base-content/50">
                    {length(chapter.lessons)}
                  </span>
                </div>
                <button
                  :for={lesson <- chapter.lessons}
                  phx-click="select_lesson"
                  phx-value-id={lesson.id}
                  class={[
                    "w-full text-left px-3 py-2 rounded-lg text-sm flex items-center gap-2 transition-colors",
                    @current_lesson && @current_lesson.id == lesson.id &&
                      "bg-primary/10 text-primary font-medium border-l-2 border-primary",
                    !(@current_lesson && @current_lesson.id == lesson.id) &&
                      "text-base-content/70 hover:bg-base-200"
                  ]}
                >
                  <span class="text-base-content/30 shrink-0">
                    <.icon name="hero-circle-stack" class="size-5" />
                  </span>
                  <span class="truncate">{lesson.title}</span>
                </button>
              </div>
            </nav>
          </aside>

          <%!-- Main content area --%>
          <main class="flex-1 min-w-0">
            <div :if={@current_lesson == nil} class="text-center py-12">
              <.icon name="hero-book-open" class="size-12 text-base-content/30 mx-auto mb-4" />
              <p class="text-base-content/60">{gettext("This course has no lessons yet.")}</p>
            </div>

            <div :if={@current_lesson} class="space-y-6">
              <%!-- Lesson title --%>
              <div class="flex items-start justify-between gap-4">
                <h2 class="text-xl font-bold text-base-content">{@current_lesson.title}</h2>
              </div>

              <%!-- Lesson content --%>
              <div class="prose prose-sm max-w-none text-base-content">
                {Phoenix.HTML.raw(render_lesson_content(@current_lesson.content))}
              </div>

              <%!-- Previous/Next navigation --%>
              <div class="flex items-center justify-between border-t border-base-300 pt-4 mt-8">
                <button
                  :if={prev_lesson(@course, @current_lesson)}
                  phx-click="prev_lesson"
                  class="btn btn-ghost btn-sm gap-1"
                >
                  <.icon name="hero-arrow-left" class="size-4" />
                  {gettext("Previous")}
                </button>
                <div :if={!prev_lesson(@course, @current_lesson)}></div>

                <button
                  :if={next_lesson(@course, @current_lesson)}
                  phx-click="next_lesson"
                  class="btn btn-ghost btn-sm gap-1"
                >
                  {gettext("Next")}
                  <.icon name="hero-arrow-right" class="size-4" />
                </button>
                <div :if={!next_lesson(@course, @current_lesson)}></div>
              </div>
            </div>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
