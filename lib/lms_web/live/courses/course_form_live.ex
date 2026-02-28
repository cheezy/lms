defmodule LmsWeb.Courses.CourseFormLive do
  use LmsWeb, :live_view

  alias Lms.Training
  alias Lms.Training.Course

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> allow_upload(:cover_image,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 1,
        max_file_size: 5_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    course = %Course{company_id: socket.assigns.current_scope.user.company_id}
    changeset = Training.change_course(course)

    socket
    |> assign(:page_title, gettext("New Course"))
    |> assign(:course, course)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    course = Training.get_course!(id)
    changeset = Training.change_course(course)

    socket
    |> assign(:page_title, gettext("Edit Course"))
    |> assign(:course, course)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("validate", %{"course" => course_params}, socket) do
    changeset =
      socket.assigns.course
      |> Training.change_course(course_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :cover_image, ref)}
  end

  def handle_event("save", %{"course" => course_params}, socket) do
    cover_image_path = consume_cover_image(socket)

    course_params =
      if cover_image_path do
        Map.put(course_params, "cover_image", cover_image_path)
      else
        course_params
      end

    save_course(socket, socket.assigns.live_action, course_params)
  end

  defp save_course(socket, :new, course_params) do
    course_params =
      course_params
      |> Map.put("company_id", socket.assigns.current_scope.user.company_id)
      |> Map.put("creator_id", socket.assigns.current_scope.user.id)

    case Training.create_course(course_params) do
      {:ok, _course} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Course created successfully."))
         |> push_navigate(to: ~p"/courses")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_course(socket, :edit, course_params) do
    case Training.update_course(socket.assigns.course, course_params) do
      {:ok, _course} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Course updated successfully."))
         |> push_navigate(to: ~p"/courses")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp consume_cover_image(socket) do
    uploaded_entries =
      consume_uploaded_entries(socket, :cover_image, fn %{path: path}, entry ->
        dest = Path.join(["priv/static/uploads", "#{entry.uuid}-#{entry.client_name}"])
        File.cp!(path, dest)
        {:ok, ~p"/uploads/#{Path.basename(dest)}"}
      end)

    List.first(uploaded_entries)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <div class="mb-8">
          <.link navigate={~p"/courses"} class="text-sm text-base-content/60 hover:text-base-content">
            <.icon name="hero-arrow-left" class="size-4 inline mr-1" />
            {gettext("Back to courses")}
          </.link>
          <h1 class="text-2xl font-bold text-base-content mt-2">{@page_title}</h1>
        </div>

        <div class="card bg-base-100 border border-base-300 p-6">
          <.form
            for={@form}
            id="course-form"
            phx-change="validate"
            phx-submit="save"
            multipart
          >
            <.input field={@form[:title]} type="text" label={gettext("Title")} required />
            <.input
              field={@form[:description]}
              type="textarea"
              label={gettext("Description")}
              rows="4"
            />

            <%!-- Cover image upload --%>
            <div class="fieldset mb-4">
              <label class="label mb-1">{gettext("Cover Image")}</label>

              <%!-- Show existing cover image --%>
              <div
                :if={@course.cover_image && @uploads.cover_image.entries == []}
                class="mb-3 rounded-lg overflow-hidden border border-base-300 max-w-xs"
              >
                <img src={@course.cover_image} alt={gettext("Current cover")} class="w-full" />
              </div>

              <%!-- Upload preview --%>
              <div :for={entry <- @uploads.cover_image.entries} class="mb-3">
                <div class="rounded-lg overflow-hidden border border-base-300 max-w-xs">
                  <.live_img_preview entry={entry} class="w-full" />
                </div>
                <div class="flex items-center gap-2 mt-2">
                  <progress value={entry.progress} max="100" class="progress progress-primary w-48">
                    {entry.progress}%
                  </progress>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="btn btn-ghost btn-xs text-error"
                  >
                    <.icon name="hero-x-mark" class="size-4" />
                  </button>
                </div>
                <p
                  :for={err <- upload_errors(@uploads.cover_image, entry)}
                  class="text-sm text-error mt-1"
                >
                  {upload_error_to_string(err)}
                </p>
              </div>

              <div class="flex items-center gap-3">
                <label class="btn btn-outline btn-sm cursor-pointer">
                  <.icon name="hero-photo" class="size-4 mr-1" />
                  {gettext("Choose image")}
                  <.live_file_input upload={@uploads.cover_image} class="hidden" />
                </label>
                <span class="text-xs text-base-content/40">
                  {gettext("JPG, PNG, GIF, WebP. Max 5MB.")}
                </span>
              </div>

              <p
                :for={err <- upload_errors(@uploads.cover_image)}
                class="text-sm text-error mt-1"
              >
                {upload_error_to_string(err)}
              </p>
            </div>

            <div class="flex items-center justify-end gap-3 mt-6 pt-4 border-t border-base-300">
              <.link navigate={~p"/courses"} class="btn btn-ghost">
                {gettext("Cancel")}
              </.link>
              <.button variant="primary" phx-disable-with={gettext("Saving...")}>
                {gettext("Save Course")}
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp upload_error_to_string(:too_large), do: gettext("File is too large (max 5MB)")
  defp upload_error_to_string(:not_accepted), do: gettext("Unsupported file type")
  defp upload_error_to_string(:too_many_files), do: gettext("Only one file allowed")
  defp upload_error_to_string(_), do: gettext("Upload error")
end
