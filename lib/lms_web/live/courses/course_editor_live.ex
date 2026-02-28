defmodule LmsWeb.Courses.CourseEditorLive do
  use LmsWeb, :live_view

  alias Lms.Training

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    course = Training.get_course_with_contents!(id)
    company_id = socket.assigns.current_scope.user.company_id

    if course.company_id != company_id do
      {:ok,
       socket
       |> put_flash(:error, gettext("Course not found."))
       |> push_navigate(to: ~p"/courses")}
    else
      socket =
        socket
        |> assign(:page_title, course.title)
        |> assign(:course, course)
        |> assign(:archived, course.status == :archived)
        |> assign(:selected_lesson, nil)
        |> assign(:editing, nil)
        |> assign(:adding, nil)
        |> assign(:expanded_chapters, expand_all(course))
        |> assign(:form, nil)
        |> assign(:editor_content, nil)

      {:ok, socket}
    end
  end

  # -- Chapter CRUD events --

  @impl true
  def handle_event("add_chapter", _params, socket) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:adding, :chapter)
       |> assign(:form, to_form(Training.change_chapter(%Training.Chapter{}, %{}), as: :chapter))}
    end
  end

  def handle_event("save_new_chapter", %{"chapter" => params}, socket) do
    attrs = %{title: params["title"], course_id: socket.assigns.course.id}

    case Training.create_chapter(attrs) do
      {:ok, _chapter} ->
        {:noreply,
         socket
         |> assign(:adding, nil)
         |> assign(:form, nil)
         |> reload_course()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :chapter))}
    end
  end

  def handle_event("edit_chapter", %{"id" => id}, socket) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      chapter = Training.get_chapter!(id)
      form = to_form(Training.change_chapter(chapter, %{}), as: :chapter)

      {:noreply,
       socket
       |> assign(:editing, {:chapter, String.to_integer(id)})
       |> assign(:form, form)}
    end
  end

  def handle_event("update_chapter", %{"chapter" => params}, socket) do
    {:chapter, chapter_id} = socket.assigns.editing
    chapter = Training.get_chapter!(chapter_id)

    case Training.update_chapter(chapter, params) do
      {:ok, _chapter} ->
        {:noreply,
         socket
         |> assign(:editing, nil)
         |> assign(:form, nil)
         |> reload_course()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :chapter))}
    end
  end

  def handle_event("delete_chapter", %{"id" => id}, socket) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      chapter = Training.get_chapter!(id)
      {:ok, _} = Training.delete_chapter_and_reorder(chapter)

      selected = socket.assigns.selected_lesson

      socket =
        if selected && selected.chapter_id == chapter.id do
          socket
          |> assign(:selected_lesson, nil)
          |> assign(:editor_content, nil)
        else
          socket
        end

      {:noreply,
       socket
       |> put_flash(:info, gettext("Chapter deleted."))
       |> reload_course()}
    end
  end

  # -- Lesson CRUD events --

  def handle_event("add_lesson", %{"chapter-id" => chapter_id}, socket) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:adding, {:lesson, String.to_integer(chapter_id)})
       |> assign(:form, to_form(Training.change_lesson(%Training.Lesson{}, %{}), as: :lesson))}
    end
  end

  def handle_event("save_new_lesson", %{"lesson" => params}, socket) do
    {:lesson, chapter_id} = socket.assigns.adding
    attrs = %{title: params["title"], chapter_id: chapter_id}

    case Training.create_lesson(attrs) do
      {:ok, _lesson} ->
        {:noreply,
         socket
         |> assign(:adding, nil)
         |> assign(:form, nil)
         |> reload_course()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :lesson))}
    end
  end

  def handle_event("edit_lesson_title", %{"id" => id}, socket) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      lesson = Training.get_lesson!(id)
      form = to_form(Training.change_lesson(lesson, %{}), as: :lesson)

      {:noreply,
       socket
       |> assign(:editing, {:lesson, String.to_integer(id)})
       |> assign(:form, form)}
    end
  end

  def handle_event("update_lesson_title", %{"lesson" => params}, socket) do
    {:lesson, lesson_id} = socket.assigns.editing
    lesson = Training.get_lesson!(lesson_id)

    case Training.update_lesson(lesson, params) do
      {:ok, _lesson} ->
        {:noreply,
         socket
         |> assign(:editing, nil)
         |> assign(:form, nil)
         |> reload_course()
         |> maybe_refresh_selected_lesson()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :lesson))}
    end
  end

  def handle_event("delete_lesson", %{"id" => id}, socket) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      lesson = Training.get_lesson!(id)
      {:ok, _} = Training.delete_lesson_and_reorder(lesson)

      socket =
        if socket.assigns.selected_lesson && socket.assigns.selected_lesson.id == lesson.id do
          socket
          |> assign(:selected_lesson, nil)
          |> assign(:editor_content, nil)
        else
          socket
        end

      {:noreply,
       socket
       |> put_flash(:info, gettext("Lesson deleted."))
       |> reload_course()}
    end
  end

  # -- Selection and content editing --

  def handle_event("select_lesson", %{"id" => id}, socket) do
    lesson = Training.get_lesson!(id)

    {:noreply,
     socket
     |> assign(:selected_lesson, lesson)
     |> assign(:editor_content, lesson.content)
     |> assign(:editing, nil)
     |> assign(:adding, nil)
     |> assign(:form, nil)}
  end

  def handle_event("editor_updated", %{"content" => content_json}, socket) do
    case Jason.decode(content_json) do
      {:ok, content} ->
        {:noreply, assign(socket, :editor_content, content)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("save_content", _params, socket) do
    lesson = socket.assigns.selected_lesson
    content = socket.assigns.editor_content

    case Training.update_lesson(lesson, %{content: content}) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:selected_lesson, updated)
         |> put_flash(:info, gettext("Lesson saved."))
         |> reload_course()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save lesson."))}
    end
  end

  # -- Reordering --

  def handle_event("move_chapter_up", %{"id" => id}, socket) do
    move_chapter(socket, String.to_integer(id), :up)
  end

  def handle_event("move_chapter_down", %{"id" => id}, socket) do
    move_chapter(socket, String.to_integer(id), :down)
  end

  def handle_event("move_lesson_up", %{"id" => id}, socket) do
    move_lesson(socket, String.to_integer(id), :up)
  end

  def handle_event("move_lesson_down", %{"id" => id}, socket) do
    move_lesson(socket, String.to_integer(id), :down)
  end

  def handle_event(
        "move_lesson_to_chapter",
        %{"lesson-id" => lesson_id, "chapter-id" => chapter_id},
        socket
      ) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      lesson = Training.get_lesson!(lesson_id)
      new_chapter_id = String.to_integer(chapter_id)

      if lesson.chapter_id != new_chapter_id do
        {:ok, _} = Training.move_lesson_to_chapter(lesson, new_chapter_id)

        socket =
          if socket.assigns.selected_lesson && socket.assigns.selected_lesson.id == lesson.id do
            updated = Training.get_lesson!(lesson.id)
            assign(socket, :selected_lesson, updated)
          else
            socket
          end

        {:noreply, reload_course(socket)}
      else
        {:noreply, socket}
      end
    end
  end

  # -- Sidebar toggle --

  def handle_event("toggle_chapter", %{"id" => id}, socket) do
    chapter_id = String.to_integer(id)
    expanded = socket.assigns.expanded_chapters

    expanded =
      if MapSet.member?(expanded, chapter_id) do
        MapSet.delete(expanded, chapter_id)
      else
        MapSet.put(expanded, chapter_id)
      end

    {:noreply, assign(socket, :expanded_chapters, expanded)}
  end

  # -- Cancel editing/adding --

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing, nil)
     |> assign(:adding, nil)
     |> assign(:form, nil)}
  end

  # -- Render --

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-7xl">
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <.button navigate={~p"/courses"}>
              <.icon name="hero-arrow-left" class="size-4 mr-1" />
              {gettext("Back")}
            </.button>
            <div>
              <h1 class="text-xl font-bold text-base-content">{@course.title}</h1>
              <p class="text-sm text-base-content/60">
                {gettext("Course Editor")}
                <span :if={@archived} class="badge badge-error badge-sm ml-2">
                  {gettext("Archived — Read Only")}
                </span>
              </p>
            </div>
          </div>
        </div>

        <%!-- Main layout: sidebar + content --%>
        <div class="flex gap-6">
          <%!-- Sidebar --%>
          <div class="w-80 shrink-0">
            <div class="bg-base-200 rounded-lg p-4">
              <div class="flex items-center justify-between mb-4">
                <h2 class="font-semibold text-base-content">{gettext("Contents")}</h2>
                <button
                  :if={!@archived}
                  phx-click="add_chapter"
                  class="btn btn-ghost btn-xs text-primary"
                >
                  <.icon name="hero-plus" class="size-3.5" />
                  {gettext("Chapter")}
                </button>
              </div>

              <%!-- Empty state --%>
              <div :if={@course.chapters == []} class="text-center py-8">
                <.icon name="hero-book-open" class="size-8 text-base-content/30 mx-auto mb-2" />
                <p class="text-sm text-base-content/50">{gettext("No chapters yet.")}</p>
              </div>

              <%!-- Chapter list --%>
              <div :for={chapter <- @course.chapters} class="mb-2" id={"chapter-#{chapter.id}"}>
                <%!-- Chapter header --%>
                <div class="flex items-center gap-1 group">
                  <button
                    phx-click="toggle_chapter"
                    phx-value-id={chapter.id}
                    class="btn btn-ghost btn-xs px-1"
                  >
                    <.icon
                      name={
                        if MapSet.member?(@expanded_chapters, chapter.id),
                          do: "hero-chevron-down",
                          else: "hero-chevron-right"
                      }
                      class="size-3.5"
                    />
                  </button>

                  <%= if @editing == {:chapter, chapter.id} do %>
                    <.form
                      for={@form}
                      phx-submit="update_chapter"
                      class="flex-1 flex gap-1"
                    >
                      <.input
                        field={@form[:title]}
                        class="input input-xs input-bordered flex-1 bg-base-100"
                        phx-mounted={JS.focus()}
                      />
                      <button type="submit" class="btn btn-ghost btn-xs text-success">
                        <.icon name="hero-check" class="size-3.5" />
                      </button>
                      <button
                        type="button"
                        phx-click="cancel_edit"
                        class="btn btn-ghost btn-xs text-error"
                      >
                        <.icon name="hero-x-mark" class="size-3.5" />
                      </button>
                    </.form>
                  <% else %>
                    <span class="flex-1 text-sm font-medium text-base-content truncate">
                      {chapter.title}
                    </span>
                    <div :if={!@archived} class="hidden group-hover:flex items-center gap-0.5">
                      <button
                        phx-click="move_chapter_up"
                        phx-value-id={chapter.id}
                        class="btn btn-ghost btn-xs px-1"
                        title={gettext("Move up")}
                        disabled={chapter.position == 0}
                      >
                        <.icon name="hero-chevron-up" class="size-3" />
                      </button>
                      <button
                        phx-click="move_chapter_down"
                        phx-value-id={chapter.id}
                        class="btn btn-ghost btn-xs px-1"
                        title={gettext("Move down")}
                        disabled={chapter.position == length(@course.chapters) - 1}
                      >
                        <.icon name="hero-chevron-down" class="size-3" />
                      </button>
                      <button
                        phx-click="edit_chapter"
                        phx-value-id={chapter.id}
                        class="btn btn-ghost btn-xs px-1"
                        title={gettext("Edit")}
                      >
                        <.icon name="hero-pencil" class="size-3" />
                      </button>
                      <button
                        phx-click="delete_chapter"
                        phx-value-id={chapter.id}
                        data-confirm={gettext("Delete this chapter and all its lessons?")}
                        class="btn btn-ghost btn-xs px-1 text-error"
                        title={gettext("Delete")}
                      >
                        <.icon name="hero-trash" class="size-3" />
                      </button>
                    </div>
                  <% end %>
                </div>

                <%!-- Lessons list (when expanded) --%>
                <div
                  :if={MapSet.member?(@expanded_chapters, chapter.id)}
                  class="ml-6 mt-1 space-y-0.5"
                >
                  <div
                    :for={lesson <- chapter.lessons}
                    class="flex items-center gap-1 group/lesson"
                    id={"lesson-#{lesson.id}"}
                  >
                    <%= if @editing == {:lesson, lesson.id} do %>
                      <.form
                        for={@form}
                        phx-submit="update_lesson_title"
                        class="flex-1 flex gap-1"
                      >
                        <.input
                          field={@form[:title]}
                          class="input input-xs input-bordered flex-1 bg-base-100"
                          phx-mounted={JS.focus()}
                        />
                        <button type="submit" class="btn btn-ghost btn-xs text-success">
                          <.icon name="hero-check" class="size-3.5" />
                        </button>
                        <button
                          type="button"
                          phx-click="cancel_edit"
                          class="btn btn-ghost btn-xs text-error"
                        >
                          <.icon name="hero-x-mark" class="size-3.5" />
                        </button>
                      </.form>
                    <% else %>
                      <button
                        phx-click="select_lesson"
                        phx-value-id={lesson.id}
                        class={[
                          "flex-1 text-left text-sm px-2 py-1 rounded truncate transition-colors",
                          if(@selected_lesson && @selected_lesson.id == lesson.id,
                            do: "bg-primary/10 text-primary font-medium",
                            else: "text-base-content/70 hover:bg-base-300"
                          )
                        ]}
                      >
                        <.icon name="hero-document-text" class="size-3.5 inline mr-1" />
                        {lesson.title}
                      </button>
                      <div
                        :if={!@archived}
                        class="hidden group-hover/lesson:flex items-center gap-0.5"
                      >
                        <button
                          phx-click="move_lesson_up"
                          phx-value-id={lesson.id}
                          class="btn btn-ghost btn-xs px-1"
                          title={gettext("Move up")}
                          disabled={lesson.position == 0}
                        >
                          <.icon name="hero-chevron-up" class="size-3" />
                        </button>
                        <button
                          phx-click="move_lesson_down"
                          phx-value-id={lesson.id}
                          class="btn btn-ghost btn-xs px-1"
                          title={gettext("Move down")}
                          disabled={lesson.position == length(chapter.lessons) - 1}
                        >
                          <.icon name="hero-chevron-down" class="size-3" />
                        </button>
                        <button
                          phx-click="edit_lesson_title"
                          phx-value-id={lesson.id}
                          class="btn btn-ghost btn-xs px-1"
                          title={gettext("Edit")}
                        >
                          <.icon name="hero-pencil" class="size-3" />
                        </button>
                        <button
                          phx-click="delete_lesson"
                          phx-value-id={lesson.id}
                          data-confirm={gettext("Delete this lesson?")}
                          class="btn btn-ghost btn-xs px-1 text-error"
                          title={gettext("Delete")}
                        >
                          <.icon name="hero-trash" class="size-3" />
                        </button>
                      </div>
                    <% end %>
                  </div>

                  <%!-- Add lesson button --%>
                  <%= if @adding == {:lesson, chapter.id} do %>
                    <.form
                      for={@form}
                      phx-submit="save_new_lesson"
                      class="flex gap-1 mt-1"
                    >
                      <.input
                        field={@form[:title]}
                        placeholder={gettext("Lesson title...")}
                        class="input input-xs input-bordered flex-1 bg-base-100"
                        phx-mounted={JS.focus()}
                      />
                      <button type="submit" class="btn btn-ghost btn-xs text-success">
                        <.icon name="hero-check" class="size-3.5" />
                      </button>
                      <button
                        type="button"
                        phx-click="cancel_edit"
                        class="btn btn-ghost btn-xs text-error"
                      >
                        <.icon name="hero-x-mark" class="size-3.5" />
                      </button>
                    </.form>
                  <% else %>
                    <button
                      :if={!@archived}
                      phx-click="add_lesson"
                      phx-value-chapter-id={chapter.id}
                      class="btn btn-ghost btn-xs text-primary/60 w-full justify-start mt-1"
                    >
                      <.icon name="hero-plus" class="size-3" />
                      {gettext("Add lesson")}
                    </button>
                  <% end %>
                </div>
              </div>

              <%!-- Add chapter form (at bottom of sidebar) --%>
              <div :if={@adding == :chapter} class="mt-3 pt-3 border-t border-base-300">
                <.form for={@form} phx-submit="save_new_chapter" class="flex gap-1">
                  <.input
                    field={@form[:title]}
                    placeholder={gettext("Chapter title...")}
                    class="input input-xs input-bordered flex-1 bg-base-100"
                    phx-mounted={JS.focus()}
                  />
                  <button type="submit" class="btn btn-ghost btn-xs text-success">
                    <.icon name="hero-check" class="size-3.5" />
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_edit"
                    class="btn btn-ghost btn-xs text-error"
                  >
                    <.icon name="hero-x-mark" class="size-3.5" />
                  </button>
                </.form>
              </div>
            </div>
          </div>

          <%!-- Main content area --%>
          <div class="flex-1 min-w-0">
            <%= if @selected_lesson do %>
              <div class="bg-base-200 rounded-lg p-6">
                <div class="flex items-center justify-between mb-4">
                  <h2 class="text-lg font-semibold text-base-content">{@selected_lesson.title}</h2>
                  <%!-- Move to chapter dropdown --%>
                  <div :if={!@archived && length(@course.chapters) > 1} class="dropdown dropdown-end">
                    <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
                      <.icon name="hero-arrows-right-left" class="size-4 mr-1" />
                      {gettext("Move")}
                    </div>
                    <ul
                      tabindex="0"
                      class="dropdown-content menu bg-base-100 rounded-box z-10 w-56 p-2 shadow-lg border border-base-300"
                    >
                      <li
                        :for={chapter <- @course.chapters}
                        :if={chapter.id != @selected_lesson.chapter_id}
                      >
                        <button
                          phx-click="move_lesson_to_chapter"
                          phx-value-lesson-id={@selected_lesson.id}
                          phx-value-chapter-id={chapter.id}
                        >
                          {chapter.title}
                        </button>
                      </li>
                    </ul>
                  </div>
                </div>

                <%!-- TipTap rich text editor --%>
                <div
                  id={"editor-#{@selected_lesson.id}"}
                  phx-hook="TipTapEditor"
                  phx-update="ignore"
                  data-content={
                    Jason.encode!(@selected_lesson.content || %{"type" => "doc", "content" => []})
                  }
                  data-readonly={to_string(@archived)}
                >
                  <div
                    :if={!@archived}
                    data-toolbar
                    class="flex flex-wrap gap-0.5 p-2 bg-base-100 border border-base-300 rounded-t-lg"
                  >
                  </div>
                  <div data-editor></div>
                </div>

                <div :if={!@archived} class="mt-4 flex justify-end">
                  <button
                    type="button"
                    phx-click="save_content"
                    class="btn btn-primary"
                  >
                    <.icon name="hero-check" class="size-4 mr-1" />
                    {gettext("Save")}
                  </button>
                </div>

                <%!-- Read-only view for archived courses --%>
                <div :if={@archived} class="prose max-w-none mt-4">
                  <div class="text-sm text-base-content bg-base-100 p-4 rounded-lg">
                    {raw(render_lesson_content(@selected_lesson.content))}
                  </div>
                </div>
              </div>
            <% else %>
              <%!-- Empty state --%>
              <div class="bg-base-200 rounded-lg p-12 text-center">
                <.icon name="hero-document-text" class="size-16 text-base-content/20 mx-auto mb-4" />
                <p class="text-base-content/50 text-lg">
                  {gettext("Select a lesson to edit its content")}
                </p>
                <p :if={@course.chapters == []} class="text-base-content/40 text-sm mt-2">
                  {gettext("Start by adding a chapter in the sidebar")}
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # -- Private helpers --

  defp reload_course(socket) do
    course = Training.get_course_with_contents!(socket.assigns.course.id)
    assign(socket, :course, course)
  end

  defp maybe_refresh_selected_lesson(socket) do
    case socket.assigns.selected_lesson do
      nil ->
        socket

      lesson ->
        updated = Training.get_lesson!(lesson.id)
        assign(socket, :selected_lesson, updated)
    end
  end

  defp expand_all(course) do
    course.chapters
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  defp move_chapter(socket, chapter_id, direction) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      chapters = socket.assigns.course.chapters
      ids = Enum.map(chapters, & &1.id)
      index = Enum.find_index(ids, &(&1 == chapter_id))

      new_ids = swap(ids, index, direction)

      if new_ids != ids do
        {:ok, _} = Training.reorder_chapters(socket.assigns.course.id, new_ids)
        {:noreply, reload_course(socket)}
      else
        {:noreply, socket}
      end
    end
  end

  defp move_lesson(socket, lesson_id, direction) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      # Find the lesson's chapter
      chapter =
        Enum.find(socket.assigns.course.chapters, fn ch ->
          Enum.any?(ch.lessons, &(&1.id == lesson_id))
        end)

      if chapter do
        ids = Enum.map(chapter.lessons, & &1.id)
        index = Enum.find_index(ids, &(&1 == lesson_id))

        new_ids = swap(ids, index, direction)

        if new_ids != ids do
          {:ok, _} = Training.reorder_lessons(chapter.id, new_ids)
          {:noreply, reload_course(socket)}
        else
          {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    end
  end

  defp swap(list, index, :up) when index > 0 do
    list
    |> List.replace_at(index, Enum.at(list, index - 1))
    |> List.replace_at(index - 1, Enum.at(list, index))
  end

  defp swap(list, index, :down) when index < length(list) - 1 do
    list
    |> List.replace_at(index, Enum.at(list, index + 1))
    |> List.replace_at(index + 1, Enum.at(list, index))
  end

  defp swap(list, _index, _direction), do: list

  defp render_lesson_content(nil), do: ""

  defp render_lesson_content(content) when is_map(content) do
    Lms.Training.LessonRenderer.render(content)
  end

  defp render_lesson_content(content) when is_binary(content), do: content
end
