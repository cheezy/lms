defmodule LmsWeb.DashboardLive do
  use LmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col items-center justify-center py-12">
        <.icon name="hero-chart-bar" class="size-16 text-base-content opacity-30 mb-4" />
        <h1 class="text-2xl font-bold text-base-content">{gettext("Company Dashboard")}</h1>
        <p class="mt-2 text-base-content opacity-60">
          {gettext("Dashboard features coming soon.")}
        </p>
      </div>
    </Layouts.app>
    """
  end
end
