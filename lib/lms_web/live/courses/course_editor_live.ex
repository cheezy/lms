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
        |> assign(:sidebar_open, false)
        |> allow_upload(:image,
          accept: ~w(.jpg .jpeg .png .gif .webp),
          max_entries: 1,
          max_file_size: 5_000_000,
          auto_upload: true
        )

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
     |> assign(:form, nil)
     |> assign(:sidebar_open, false)}
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

  # -- Image upload --

  # sobelow_skip ["Traversal.FileModule"]
  def handle_event("upload_image", _params, socket) do
    lesson = socket.assigns.selected_lesson

    if lesson == nil || socket.assigns.archived do
      {:noreply, socket}
    else
      uploaded_urls =
        consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
          dest = upload_dest(entry)
          File.cp!(path, dest)

          {:ok, _image} =
            Training.create_lesson_image(%{
              filename: entry.client_name,
              file_path: dest,
              content_type: entry.client_type,
              file_size: entry.client_size,
              lesson_id: lesson.id
            })

          {:ok, ~p"/uploads/#{Path.basename(dest)}"}
        end)

      case uploaded_urls do
        [url | _] ->
          {:noreply, push_event(socket, "image_uploaded", %{url: url})}

        [] ->
          {:noreply, socket}
      end
    end
  end

  # -- Reordering --

  def handle_event("reorder_chapters", %{"ids" => ids}, socket) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      int_ids = Enum.map(ids, &String.to_integer/1)
      {:ok, _} = Training.reorder_chapters(socket.assigns.course.id, int_ids)
      {:noreply, reload_course(socket)}
    end
  end

  def handle_event("reorder_lessons", %{"chapter_id" => chapter_id, "ids" => ids}, socket) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      int_chapter_id = String.to_integer(chapter_id)
      int_ids = Enum.map(ids, &String.to_integer/1)
      {:ok, _} = Training.reorder_lessons(int_chapter_id, int_ids)
      {:noreply, reload_course(socket)}
    end
  end

  def handle_event(
        "move_lesson_to_chapter_and_reorder",
        %{
          "lesson_id" => lesson_id,
          "from_chapter_id" => from_chapter_id,
          "to_chapter_id" => to_chapter_id,
          "ids" => ids
        },
        socket
      ) do
    if socket.assigns.archived do
      {:noreply, socket}
    else
      int_lesson_id = String.to_integer(lesson_id)
      int_from = String.to_integer(from_chapter_id)
      int_to = String.to_integer(to_chapter_id)
      int_ids = Enum.map(ids, &String.to_integer/1)

      lesson = Training.get_lesson!(int_lesson_id)
      {:ok, _} = Training.move_lesson_to_chapter(lesson, int_to)
      {:ok, _} = Training.reorder_lessons(int_to, int_ids)

      # Reorder source chapter's remaining lessons
      remaining =
        int_from
        |> Training.list_lessons()
        |> Enum.map(& &1.id)

      {:ok, _} = Training.reorder_lessons(int_from, remaining)

      socket =
        if socket.assigns.selected_lesson &&
             socket.assigns.selected_lesson.id == int_lesson_id do
          updated = Training.get_lesson!(int_lesson_id)
          assign(socket, :selected_lesson, updated)
        else
          socket
        end

      {:noreply, reload_course(socket)}
    end
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

  # -- Sidebar toggle (mobile) --

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}
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
          <button
            phx-click="toggle_sidebar"
            class="lg:hidden btn btn-ghost btn-sm"
            aria-label={gettext("Toggle navigation")}
          >
            <.icon name="hero-bars-3" class="size-5" />
          </button>
        </div>

        <%!-- Main layout: sidebar + content --%>
        <div class="flex gap-6 relative">
          <%!-- Mobile sidebar overlay --%>
          <div
            :if={@sidebar_open}
            class="fixed inset-0 bg-base-200/80 z-40 lg:hidden"
            phx-click="toggle_sidebar"
            aria-hidden="true"
          >
          </div>

          <%!-- Sidebar --%>
          <div class={[
            "w-80 shrink-0 z-50",
            "lg:relative lg:block",
            @sidebar_open && "fixed inset-y-0 left-0 bg-base-100 shadow-xl overflow-y-auto",
            !@sidebar_open && "hidden lg:block"
          ]}>
            <div class="bg-base-200 rounded-2xl p-4">
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
              <div id="chapter-list" phx-hook={if(!@archived, do: "SortableChapters")}>
                <.chapter_item
                  :for={chapter <- @course.chapters}
                  chapter={chapter}
                  archived={@archived}
                  editing={@editing}
                  adding={@adding}
                  expanded_chapters={@expanded_chapters}
                  selected_lesson={@selected_lesson}
                  form={@form}
                />
              </div>

              <%!-- Add chapter form (at bottom of sidebar) --%>
              <div :if={@adding == :chapter} class="mt-3 pt-3 border-t border-base-300">
                <.inline_title_form
                  form={@form}
                  submit_event="save_new_chapter"
                  placeholder={gettext("Chapter title...")}
                />
              </div>
            </div>
          </div>

          <.editor_panel
            selected_lesson={@selected_lesson}
            course={@course}
            archived={@archived}
            uploads={@uploads}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  # -- Private function components --

  attr :form, :any, required: true
  attr :submit_event, :string, required: true
  attr :placeholder, :string, default: nil
  attr :class, :string, default: "flex gap-1"

  defp inline_title_form(assigns) do
    ~H"""
    <.form for={@form} phx-submit={@submit_event} class={@class}>
      <.input
        field={@form[:title]}
        placeholder={@placeholder}
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
    """
  end

  attr :selected_lesson, :any, required: true
  attr :course, :any, required: true
  attr :archived, :boolean, required: true
  attr :uploads, :any, required: true

  defp editor_panel(assigns) do
    ~H"""
    <div class="flex-1 min-w-0">
      <%= if @selected_lesson do %>
        <div class="bg-base-200 rounded-2xl p-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold text-base-content">{@selected_lesson.title}</h2>
            <.move_lesson_dropdown
              :if={!@archived && length(@course.chapters) > 1}
              selected_lesson={@selected_lesson}
              chapters={@course.chapters}
            />
          </div>

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

          <form
            :if={!@archived}
            id="image-upload-form"
            phx-change="upload_image"
            phx-submit="upload_image"
            class="hidden"
          >
            <.live_file_input upload={@uploads.image} />
          </form>

          <div
            :for={entry <- @uploads.image.entries}
            :if={entry.valid? == false}
            class="text-error text-sm mt-1"
          >
            {error_to_string(entry)}
          </div>

          <div :if={!@archived} class="mt-4 flex justify-end gap-2">
            <button
              type="button"
              phx-click={JS.dispatch("click", to: "#image-upload-form input[type=file]")}
              class="btn btn-ghost"
            >
              <.icon name="hero-photo" class="size-4 mr-1" />
              {gettext("Image")}
            </button>
            <button type="button" phx-click="save_content" class="btn btn-primary">
              <.icon name="hero-check" class="size-4 mr-1" />
              {gettext("Save")}
            </button>
          </div>

          <div :if={@archived} class="prose max-w-none mt-4">
            <div class="text-sm text-base-content bg-base-100 p-4 rounded-lg">
              {raw(render_lesson_content(@selected_lesson.content))}
            </div>
          </div>
        </div>
      <% else %>
        <div class="bg-base-200 rounded-2xl p-12 text-center">
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
    """
  end

  attr :chapter, :any, required: true
  attr :archived, :boolean, required: true
  attr :editing, :any, required: true
  attr :adding, :any, required: true
  attr :expanded_chapters, :any, required: true
  attr :selected_lesson, :any, required: true
  attr :form, :any, required: true

  defp chapter_item(assigns) do
    ~H"""
    <div class="mb-2" id={"chapter-#{@chapter.id}"} data-chapter-id={@chapter.id}>
      <%!-- Chapter header --%>
      <div class="flex items-center gap-1 group">
        <span
          :if={!@archived}
          data-drag-handle
          class="cursor-grab active:cursor-grabbing text-base-content/30 hover:text-base-content/60 px-0.5"
          title={gettext("Drag to reorder")}
        >
          <.icon name="hero-bars-3" class="size-3.5" />
        </span>
        <button
          phx-click="toggle_chapter"
          phx-value-id={@chapter.id}
          class="btn btn-ghost btn-xs px-1"
        >
          <.icon
            name={
              if MapSet.member?(@expanded_chapters, @chapter.id),
                do: "hero-chevron-down",
                else: "hero-chevron-right"
            }
            class="size-3.5"
          />
        </button>

        <%= if @editing == {:chapter, @chapter.id} do %>
          <.inline_title_form
            form={@form}
            submit_event="update_chapter"
            class="flex-1 flex gap-1"
          />
        <% else %>
          <span class="flex-1 text-sm font-medium text-base-content truncate">
            {@chapter.title}
          </span>
          <div :if={!@archived} class="hidden group-hover:flex items-center gap-0.5">
            <button
              phx-click="edit_chapter"
              phx-value-id={@chapter.id}
              class="btn btn-ghost btn-xs px-1"
              title={gettext("Edit")}
            >
              <.icon name="hero-pencil" class="size-3" />
            </button>
            <button
              phx-click="delete_chapter"
              phx-value-id={@chapter.id}
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
        :if={MapSet.member?(@expanded_chapters, @chapter.id)}
        id={"lessons-#{@chapter.id}"}
        data-chapter-id={@chapter.id}
        phx-hook={if(!@archived, do: "SortableLessons")}
        class="ml-6 mt-1 space-y-0.5"
      >
        <.lesson_item
          :for={lesson <- @chapter.lessons}
          lesson={lesson}
          archived={@archived}
          editing={@editing}
          selected_lesson={@selected_lesson}
          form={@form}
        />

        <%= if @adding == {:lesson, @chapter.id} do %>
          <.inline_title_form
            form={@form}
            submit_event="save_new_lesson"
            placeholder={gettext("Lesson title...")}
            class="flex gap-1 mt-1"
          />
        <% else %>
          <button
            :if={!@archived}
            phx-click="add_lesson"
            phx-value-chapter-id={@chapter.id}
            class="btn btn-ghost btn-xs text-primary/60 w-full justify-start mt-1"
          >
            <.icon name="hero-plus" class="size-3" />
            {gettext("Add lesson")}
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr :lesson, :any, required: true
  attr :archived, :boolean, required: true
  attr :editing, :any, required: true
  attr :selected_lesson, :any, required: true
  attr :form, :any, required: true

  defp lesson_item(assigns) do
    ~H"""
    <div
      class="flex items-center gap-1 group/lesson"
      id={"lesson-#{@lesson.id}"}
      data-lesson-id={@lesson.id}
    >
      <%= if @editing == {:lesson, @lesson.id} do %>
        <.inline_title_form
          form={@form}
          submit_event="update_lesson_title"
          class="flex-1 flex gap-1"
        />
      <% else %>
        <span
          :if={!@archived}
          data-drag-handle
          class="cursor-grab active:cursor-grabbing text-base-content/30 hover:text-base-content/60 px-0.5"
          title={gettext("Drag to reorder")}
        >
          <.icon name="hero-bars-3" class="size-3" />
        </span>
        <button
          phx-click="select_lesson"
          phx-value-id={@lesson.id}
          class={[
            "flex-1 text-left text-sm px-2 py-1 rounded truncate transition-colors",
            if(@selected_lesson && @selected_lesson.id == @lesson.id,
              do: "bg-primary/10 text-primary font-medium border-l-2 border-primary",
              else: "text-base-content/70 hover:bg-base-300"
            )
          ]}
        >
          <.icon name="hero-document-text" class="size-3.5 inline mr-1" />
          {@lesson.title}
        </button>
        <div :if={!@archived} class="hidden group-hover/lesson:flex items-center gap-0.5">
          <button
            phx-click="edit_lesson_title"
            phx-value-id={@lesson.id}
            class="btn btn-ghost btn-xs px-1"
            title={gettext("Edit")}
          >
            <.icon name="hero-pencil" class="size-3" />
          </button>
          <button
            phx-click="delete_lesson"
            phx-value-id={@lesson.id}
            data-confirm={gettext("Delete this lesson?")}
            class="btn btn-ghost btn-xs px-1 text-error"
            title={gettext("Delete")}
          >
            <.icon name="hero-trash" class="size-3" />
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  attr :selected_lesson, :any, required: true
  attr :chapters, :list, required: true

  defp move_lesson_dropdown(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
        <.icon name="hero-arrows-right-left" class="size-4 mr-1" />
        {gettext("Move")}
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box z-10 w-56 p-2 shadow-lg border border-base-300"
      >
        <li :for={chapter <- @chapters} :if={chapter.id != @selected_lesson.chapter_id}>
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
    """
  end

  # -- Private helpers --

  defp upload_dest(entry) do
    ext = Path.extname(entry.client_name)
    filename = "#{System.unique_integer([:positive])}#{ext}"
    Path.join(["priv/static/uploads", filename])
  end

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

  defp error_to_string(%{client_name: name, valid?: false}) do
    gettext("Error uploading %{name}: file must be an image under 5MB", name: name)
  end

  defp render_lesson_content(nil), do: ""

  defp render_lesson_content(content) when is_map(content) do
    Lms.Training.LessonRenderer.render(content)
  end

  defp render_lesson_content(content) when is_binary(content), do: content
end
