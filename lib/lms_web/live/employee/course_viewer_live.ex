defmodule LmsWeb.Employee.CourseViewerLive do
  use LmsWeb, :live_view

  alias Lms.Learning
  alias Lms.Training

  @impl true
  def mount(%{"course_id" => course_id}, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    enrollment = Learning.get_enrollment_for_user!(user_id, String.to_integer(course_id))
    course = Training.get_course_with_contents!(enrollment.course_id)
    completed_ids = Learning.completed_lesson_ids(enrollment)
    progress = Learning.calculate_progress(enrollment)
    initial_lesson = resume_lesson(course, enrollment)

    if initial_lesson && enrollment.last_lesson_id != initial_lesson.id do
      Learning.update_last_lesson(enrollment, initial_lesson.id)
    end

    socket =
      socket
      |> assign(:page_title, course.title)
      |> assign(:enrollment, enrollment)
      |> assign(:course, course)
      |> assign(:completed_ids, completed_ids)
      |> assign(:progress, progress)
      |> assign(:current_lesson, initial_lesson)
      |> assign(:sidebar_open, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_lesson", %{"id" => id}, socket) do
    lesson_id = String.to_integer(id)
    lesson = find_lesson(socket.assigns.course, lesson_id)
    Learning.update_last_lesson(socket.assigns.enrollment, lesson_id)

    socket =
      socket
      |> assign(:current_lesson, lesson)
      |> assign(:sidebar_open, false)

    {:noreply, socket}
  end

  def handle_event("mark_complete", _params, socket) do
    enrollment = socket.assigns.enrollment
    lesson = socket.assigns.current_lesson

    case Learning.complete_lesson(enrollment, lesson.id) do
      {:ok, %{enrollment: updated_enrollment}} ->
        completed_ids = MapSet.put(socket.assigns.completed_ids, lesson.id)
        progress = Learning.calculate_progress(enrollment)

        socket =
          socket
          |> assign(:completed_ids, completed_ids)
          |> assign(:progress, progress)
          |> assign(:enrollment, updated_enrollment)
          |> put_flash(:info, gettext("Lesson completed!"))

        {:noreply, socket}

      {:error, :lesson_progress, _changeset, _} ->
        {:noreply, put_flash(socket, :info, gettext("Lesson already completed."))}
    end
  end

  def handle_event("next_lesson", _params, socket) do
    case next_lesson(socket.assigns.course, socket.assigns.current_lesson) do
      nil ->
        {:noreply, socket}

      lesson ->
        Learning.update_last_lesson(socket.assigns.enrollment, lesson.id)
        {:noreply, assign(socket, :current_lesson, lesson)}
    end
  end

  def handle_event("prev_lesson", _params, socket) do
    case prev_lesson(socket.assigns.course, socket.assigns.current_lesson) do
      nil ->
        {:noreply, socket}

      lesson ->
        Learning.update_last_lesson(socket.assigns.enrollment, lesson.id)
        {:noreply, assign(socket, :current_lesson, lesson)}
    end
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}
  end

  defp resume_lesson(course, enrollment) do
    if enrollment.last_lesson_id do
      find_lesson(course, enrollment.last_lesson_id) || find_first_lesson(course)
    else
      find_first_lesson(course)
    end
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

  defp lesson_completed?(completed_ids, lesson_id) do
    MapSet.member?(completed_ids, lesson_id)
  end

  defp chapter_progress(completed_ids, chapter) do
    total = length(chapter.lessons)

    if total == 0 do
      {0, 0}
    else
      completed = Enum.count(chapter.lessons, &MapSet.member?(completed_ids, &1.id))
      {completed, total}
    end
  end

  defp render_lesson_content(nil), do: ""

  defp render_lesson_content(content) when is_map(content) do
    Lms.Training.LessonRenderer.render(content)
  end

  defp render_lesson_content(content) when is_binary(content), do: content

  defp format_progress(progress) do
    :erlang.float_to_binary(progress, decimals: 0) <> "%"
  end

  defp total_lessons(course) do
    Enum.reduce(course.chapters, 0, fn ch, acc -> acc + length(ch.lessons) end)
  end

  defp completed_count(completed_ids) do
    MapSet.size(completed_ids)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl">
        <%!-- Header with back link and progress --%>
        <div class="mb-6">
          <div class="flex items-center justify-between">
            <.link
              navigate={~p"/my-learning"}
              class="text-sm text-primary hover:underline inline-flex items-center gap-1"
            >
              <.icon name="hero-arrow-left" class="size-4" />
              {gettext("Back to My Learning")}
            </.link>
            <button
              phx-click="toggle_sidebar"
              class="lg:hidden btn btn-ghost btn-sm"
              aria-label={gettext("Toggle navigation")}
            >
              <.icon name="hero-bars-3" class="size-5" />
            </button>
          </div>
          <h1 class="text-2xl font-bold text-base-content mt-2">{@course.title}</h1>
          <div class="mt-3 flex items-center gap-3">
            <div class="flex-1 max-w-xs">
              <div class="w-full bg-base-300 rounded-full h-2.5">
                <div
                  class="bg-primary h-2.5 rounded-full transition-all"
                  style={"width: #{@progress}%"}
                >
                </div>
              </div>
            </div>
            <span class="text-sm text-base-content/70">
              {gettext("%{completed} of %{total} lessons",
                completed: completed_count(@completed_ids),
                total: total_lessons(@course)
              )} ({format_progress(@progress)})
            </span>
          </div>
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
                  <.chapter_progress_badge
                    completed_ids={@completed_ids}
                    chapter={chapter}
                  />
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
                  <span
                    :if={lesson_completed?(@completed_ids, lesson.id)}
                    class="text-success shrink-0"
                  >
                    <.icon name="hero-check-circle-solid" class="size-5" />
                  </span>
                  <span
                    :if={!lesson_completed?(@completed_ids, lesson.id)}
                    class="text-base-content/30 shrink-0"
                  >
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
              <%!-- Lesson title and complete button --%>
              <div class="flex items-start justify-between gap-4">
                <h2 class="text-xl font-bold text-base-content">{@current_lesson.title}</h2>
                <div :if={lesson_completed?(@completed_ids, @current_lesson.id)}>
                  <span class="badge badge-success gap-1">
                    <.icon name="hero-check" class="size-4" />
                    {gettext("Completed")}
                  </span>
                </div>
                <.button
                  :if={!lesson_completed?(@completed_ids, @current_lesson.id)}
                  variant="primary"
                  phx-click="mark_complete"
                >
                  <.icon name="hero-check" class="size-4 mr-1" />
                  {gettext("Mark as Complete")}
                </.button>
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

  defp chapter_progress_badge(assigns) do
    {completed, total} = chapter_progress(assigns.completed_ids, assigns.chapter)
    assigns = assign(assigns, :completed, completed)
    assigns = assign(assigns, :total, total)

    ~H"""
    <span class={[
      "text-xs px-1.5 py-0.5 rounded",
      @completed == @total && @total > 0 && "bg-success/10 text-success",
      !(@completed == @total && @total > 0) && "bg-base-200 text-base-content/50"
    ]}>
      {@completed}/{@total}
    </span>
    """
  end
end
