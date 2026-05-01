defmodule LmsWeb.Admin.CompanyListLive do
  use LmsWeb, :live_view

  alias Lms.Companies

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Companies"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    search = params["search"] || ""
    companies = Companies.list_companies_with_stats(%{search: search})

    socket
    |> assign(:search, search)
    |> assign(:companies, companies)
    |> assign(:selected_company, nil)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    company_data = Companies.get_company_with_stats!(id)
    search = socket.assigns[:search] || ""

    companies =
      socket.assigns[:companies] || Companies.list_companies_with_stats(%{search: search})

    socket
    |> assign(:search, search)
    |> assign(:companies, companies)
    |> assign(:selected_company, company_data)
    |> assign(:page_title, company_data.company.name)
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/companies?#{%{search: search}}")}
  end

  def handle_event("close_detail", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/companies")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-2xl font-bold text-base-content">
              {gettext("System Administration")}
            </h1>
            <p class="text-sm text-base-content/60 mt-1">
              {gettext("Manage all companies on the platform")}
            </p>
          </div>
          <span class="badge badge-primary badge-lg text-lg font-bold">
            {length(@companies)}
          </span>
        </div>

        <div class="mb-6">
          <form phx-change="search" phx-submit="search">
            <.input
              name="search"
              value={@search}
              placeholder={gettext("Search companies...")}
              phx-debounce="300"
            />
          </form>
        </div>

        <div :if={@companies == []} class="text-center py-12">
          <.icon
            name="hero-building-office-2"
            class="size-12 text-base-content/30 mx-auto mb-4"
          />
          <p class="text-base-content/60">
            {if @search != "",
              do: gettext("No companies match your search."),
              else: gettext("No companies registered yet.")}
          </p>
        </div>

        <%!-- Mobile card list (md:hidden); see desktop table below --%>
        <div :if={@companies != []} id="companies-cards" class="md:hidden space-y-3">
          <div
            :for={row <- @companies}
            id={"company-card-#{row.company.id}"}
            class="card bg-base-100 border border-base-300 p-4"
          >
            <.link
              patch={~p"/admin/companies/#{row.company.id}"}
              class="font-semibold text-primary hover:underline"
            >
              {row.company.name}
            </.link>
            <div class="mt-3 grid grid-cols-3 gap-2 text-sm">
              <div>
                <span class="block text-xs text-base-content/60 uppercase tracking-wide">
                  {gettext("Employees")}
                </span>
                <span class="badge badge-ghost badge-sm">{row.employee_count}</span>
              </div>
              <div>
                <span class="block text-xs text-base-content/60 uppercase tracking-wide">
                  {gettext("Courses")}
                </span>
                <span class="badge badge-ghost badge-sm">{row.course_count}</span>
              </div>
              <div>
                <span class="block text-xs text-base-content/60 uppercase tracking-wide">
                  {gettext("Enrollments")}
                </span>
                <span class="badge badge-ghost badge-sm">{row.enrollment_count}</span>
              </div>
            </div>
            <p class="mt-3 text-xs text-base-content/60">
              {gettext("Created")} {Calendar.strftime(row.company.inserted_at, "%b %d, %Y")}
            </p>
          </div>
        </div>

        <div :if={@companies != []} class="hidden md:block overflow-x-auto">
          <.table id="companies" rows={@companies} row_id={fn row -> "company-#{row.company.id}" end}>
            <:col :let={row} label={gettext("Company")}>
              <.link
                patch={~p"/admin/companies/#{row.company.id}"}
                class="font-medium text-primary hover:underline"
              >
                {row.company.name}
              </.link>
            </:col>
            <:col :let={row} label={gettext("Employees")}>
              <span class="badge badge-ghost badge-sm">{row.employee_count}</span>
            </:col>
            <:col :let={row} label={gettext("Courses")}>
              <span class="badge badge-ghost badge-sm">{row.course_count}</span>
            </:col>
            <:col :let={row} label={gettext("Enrollments")}>
              <span class="badge badge-ghost badge-sm">{row.enrollment_count}</span>
            </:col>
            <:col :let={row} label={gettext("Created")}>
              <span class="text-sm text-base-content/60">
                {Calendar.strftime(row.company.inserted_at, "%b %d, %Y")}
              </span>
            </:col>
            <:action :let={row}>
              <.link
                patch={~p"/admin/companies/#{row.company.id}"}
                class="text-primary hover:underline text-sm"
              >
                {gettext("View")}
              </.link>
            </:action>
          </.table>
        </div>

        <.company_detail :if={@selected_company} company_data={@selected_company} />
      </div>
    </Layouts.app>
    """
  end

  defp company_detail(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-base-200/80 z-40" phx-click="close_detail"></div>
    <div class="fixed inset-y-0 right-0 w-full max-w-lg bg-base-100 shadow-lg rounded-l-2xl z-50 overflow-y-auto">
      <div class="p-6">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-xl font-bold text-base-content">
            {@company_data.company.name}
          </h2>
          <.link patch={~p"/admin/companies"} class="btn btn-ghost btn-sm">
            <.icon name="hero-x-mark" class="size-5" />
          </.link>
        </div>

        <div class="space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <.stat_card
              label={gettext("Employees")}
              value={@company_data.employee_count}
              icon="hero-users"
            />
            <.stat_card
              label={gettext("Courses")}
              value={@company_data.course_count}
              icon="hero-academic-cap"
            />
            <.stat_card
              label={gettext("Enrollments")}
              value={@company_data.enrollment_count}
              icon="hero-clipboard-document-list"
            />
            <.stat_card
              label={gettext("Created")}
              value={Calendar.strftime(@company_data.company.inserted_at, "%b %Y")}
              icon="hero-calendar"
            />
          </div>

          <div class="divider"></div>

          <div class="space-y-2">
            <h3 class="text-sm font-semibold text-base-content/60 uppercase tracking-wider">
              {gettext("Details")}
            </h3>
            <dl class="space-y-3">
              <div>
                <dt class="text-xs text-base-content/50">{gettext("Slug")}</dt>
                <dd class="text-sm text-base-content">{@company_data.company.slug}</dd>
              </div>
              <div>
                <dt class="text-xs text-base-content/50">{gettext("Created At")}</dt>
                <dd class="text-sm text-base-content">
                  {Calendar.strftime(@company_data.company.inserted_at, "%B %d, %Y at %I:%M %p")}
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-2xl p-4">
      <div class="flex items-center gap-2 mb-1">
        <.icon name={@icon} class="size-4 text-primary" />
        <span class="text-xs text-base-content/50 uppercase tracking-wider">{@label}</span>
      </div>
      <span class="text-2xl font-bold text-base-content">{@value}</span>
    </div>
    """
  end
end
