defmodule LmsWeb.Admin.EmployeeLive.BulkUploadComponent do
  use LmsWeb, :live_component

  alias Lms.Accounts

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:step, :upload)
      |> assign(:validated_rows, [])
      |> assign(:results, nil)
      |> assign(:upload_error, nil)
      |> allow_upload(:csv,
        accept: ~w(.csv),
        max_entries: 1,
        max_file_size: 1_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl true
  def handle_event("parse_csv", _params, socket) do
    scope = socket.assigns.current_scope

    [csv_content] =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    validated_rows = Accounts.parse_and_validate_csv(scope, csv_content)

    if validated_rows == [] do
      {:noreply,
       socket
       |> assign(:upload_error, gettext("The CSV file is empty or contains only headers."))
       |> assign(:step, :upload)}
    else
      {:noreply,
       socket
       |> assign(:step, :preview)
       |> assign(:validated_rows, validated_rows)}
    end
  end

  @impl true
  def handle_event("confirm_invite", _params, socket) do
    scope = socket.assigns.current_scope
    validated_rows = socket.assigns.validated_rows

    {invited_count, skipped_count, _results} =
      Accounts.bulk_invite_employees(
        scope,
        validated_rows,
        &url(~p"/invitations/#{&1}")
      )

    {:noreply,
     socket
     |> assign(:step, :results)
     |> assign(:results, %{invited: invited_count, skipped: skipped_count})}
  end

  @impl true
  def handle_event("back_to_upload", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :upload)
     |> assign(:validated_rows, [])
     |> assign(:results, nil)
     |> assign(:upload_error, nil)}
  end

  @impl true
  def handle_event("done", _params, socket) do
    send(self(), {__MODULE__, :done})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal modal-open">
      <div class="modal-box bg-base-100 w-11/12 max-w-2xl max-h-[90vh] overflow-y-auto">
        <button
          type="button"
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
          phx-click="close_bulk_upload_modal"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>

        <h3 class="text-lg font-bold text-base-content mb-4">
          {gettext("Bulk Invite Employees")}
        </h3>

        <%= case @step do %>
          <% :upload -> %>
            <.upload_step uploads={@uploads} myself={@myself} upload_error={@upload_error} />
          <% :preview -> %>
            <.preview_step validated_rows={@validated_rows} myself={@myself} />
          <% :results -> %>
            <.results_step results={@results} myself={@myself} />
        <% end %>
      </div>
      <div class="modal-backdrop bg-base-200/90" phx-click="close_bulk_upload_modal"></div>
    </div>
    """
  end

  defp upload_step(assigns) do
    ~H"""
    <div>
      <p class="text-sm text-base-content/60 mb-4">
        {gettext("Upload a CSV file with columns: name, email")}
      </p>

      <div :if={@upload_error} class="alert alert-error mb-4 text-sm">
        <.icon name="hero-exclamation-circle" class="size-4" />
        {@upload_error}
      </div>

      <form
        id="csv-upload-form"
        phx-submit="parse_csv"
        phx-change="validate_upload"
        phx-target={@myself}
      >
        <div class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center">
          <.live_file_input upload={@uploads.csv} class="hidden" />

          <div :if={@uploads.csv.entries == []}>
            <.icon name="hero-arrow-up-tray" class="size-10 text-base-content/30 mx-auto mb-3" />
            <p class="text-base-content/60 mb-2">
              {gettext("Click or drag to upload a CSV file")}
            </p>
            <label for={@uploads.csv.ref} class="btn btn-outline btn-sm cursor-pointer">
              {gettext("Choose File")}
            </label>
          </div>

          <div :for={entry <- @uploads.csv.entries} class="flex items-center gap-3">
            <.icon name="hero-document-text" class="size-6 text-primary shrink-0" />
            <span class="text-base-content font-medium truncate min-w-0 flex-1">
              {entry.client_name}
            </span>
            <span class="text-sm text-base-content/60 shrink-0">
              {format_file_size(entry.client_size)}
            </span>
            <button
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              phx-target={@myself}
              class="btn btn-ghost btn-xs text-error shrink-0"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>

          <div :for={err <- upload_errors(@uploads.csv)} class="mt-2">
            <p class="text-error text-sm">{upload_error_to_string(err)}</p>
          </div>
        </div>

        <div class="modal-action">
          <button type="button" class="btn" phx-click="close_bulk_upload_modal">
            {gettext("Cancel")}
          </button>
          <.button
            variant="primary"
            phx-disable-with={gettext("Parsing...")}
            disabled={@uploads.csv.entries == []}
          >
            <.icon name="hero-arrow-up-tray" class="size-4 mr-1" />
            {gettext("Upload & Preview")}
          </.button>
        </div>
      </form>
    </div>
    """
  end

  defp preview_step(assigns) do
    valid_count = Enum.count(assigns.validated_rows, & &1.valid?)
    invalid_count = length(assigns.validated_rows) - valid_count
    assigns = assign(assigns, valid_count: valid_count, invalid_count: invalid_count)

    ~H"""
    <div>
      <div class="flex gap-3 mb-4">
        <div class="badge badge-success gap-1">
          <.icon name="hero-check-circle" class="size-3.5" />
          {gettext("%{count} valid", count: @valid_count)}
        </div>
        <div :if={@invalid_count > 0} class="badge badge-error gap-1">
          <.icon name="hero-exclamation-circle" class="size-3.5" />
          {gettext("%{count} invalid", count: @invalid_count)}
        </div>
      </div>

      <div class="overflow-x-auto max-h-64 overflow-y-auto">
        <table class="table table-sm table-zebra" id="csv-preview">
          <thead class="sticky top-0 bg-base-200">
            <tr>
              <th>{gettext("Name")}</th>
              <th>{gettext("Email")}</th>
              <th>{gettext("Status")}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{row, idx} <- Enum.with_index(@validated_rows)} id={"csv-row-#{idx}"}>
              <td>{row.name}</td>
              <td>{row.email}</td>
              <td>
                <span :if={row.valid?} class="badge badge-success badge-sm">
                  {gettext("Valid")}
                </span>
                <span
                  :if={not row.valid?}
                  class="badge badge-error badge-sm"
                  title={Enum.join(row.errors, ", ")}
                >
                  {Enum.join(row.errors, ", ")}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="modal-action">
        <button type="button" class="btn" phx-click="back_to_upload" phx-target={@myself}>
          {gettext("Back")}
        </button>
        <button
          :if={@valid_count > 0}
          type="button"
          class="btn btn-primary"
          phx-click="confirm_invite"
          phx-target={@myself}
          phx-disable-with={gettext("Sending invitations...")}
        >
          <.icon name="hero-paper-airplane" class="size-4 mr-1" />
          {gettext("Invite %{count} Employees", count: @valid_count)}
        </button>
      </div>
    </div>
    """
  end

  defp results_step(assigns) do
    ~H"""
    <div class="text-center py-6">
      <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-success/10 mb-4">
        <.icon name="hero-check-circle" class="size-7 text-success" />
      </div>

      <h4 class="text-lg font-semibold text-base-content mb-2">
        {gettext("Invitations Sent!")}
      </h4>

      <div class="flex justify-center gap-4 mb-4">
        <div class="stat place-items-center p-2">
          <div class="stat-value text-success text-2xl">{@results.invited}</div>
          <div class="stat-desc">{gettext("Invited")}</div>
        </div>
        <div :if={@results.skipped > 0} class="stat place-items-center p-2">
          <div class="stat-value text-warning text-2xl">{@results.skipped}</div>
          <div class="stat-desc">{gettext("Skipped")}</div>
        </div>
      </div>

      <div class="modal-action justify-center">
        <button type="button" class="btn btn-primary" phx-click="done" phx-target={@myself}>
          {gettext("Done")}
        </button>
      </div>
    </div>
    """
  end

  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"

  defp upload_error_to_string(:too_large), do: gettext("File is too large (max 1 MB)")
  defp upload_error_to_string(:not_accepted), do: gettext("Only CSV files are accepted")
  defp upload_error_to_string(:too_many_files), do: gettext("Only one file can be uploaded")
  defp upload_error_to_string(err), do: inspect(err)
end
