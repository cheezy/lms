defmodule LmsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LmsWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="bg-base-100 border-b border-base-300 sticky top-0 z-40">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex h-14 items-center justify-between">
          <%!-- Left: Uplift wordmark --%>
          <.link
            navigate={if @current_scope, do: ~p"/dashboard", else: ~p"/"}
            class="text-xl font-bold text-primary tracking-tight"
          >
            Uplift
          </.link>

          <%!-- Center: Role-based nav links (desktop) --%>
          <nav :if={@current_scope} class="hidden md:flex items-center gap-1">
            <.link
              :if={@current_scope.user.role == :system_admin}
              navigate={~p"/admin/companies"}
              class="px-3 py-2 text-sm font-medium text-base-content/70 hover:text-primary rounded-lg hover:bg-base-200 transition-colors"
            >
              Companies
            </.link>

            <.link
              :if={@current_scope.user.role in [:company_admin, :system_admin]}
              navigate={~p"/dashboard"}
              class="px-3 py-2 text-sm font-medium text-base-content/70 hover:text-primary rounded-lg hover:bg-base-200 transition-colors"
            >
              Dashboard
            </.link>

            <.link
              :if={@current_scope.user.role in [:company_admin, :system_admin]}
              navigate={~p"/admin/employees"}
              class="px-3 py-2 text-sm font-medium text-base-content/70 hover:text-primary rounded-lg hover:bg-base-200 transition-colors"
            >
              Employees
            </.link>

            <.link
              :if={@current_scope.user.role in [:course_creator, :company_admin, :system_admin]}
              navigate={~p"/courses"}
              class="px-3 py-2 text-sm font-medium text-base-content/70 hover:text-primary rounded-lg hover:bg-base-200 transition-colors"
            >
              Courses
            </.link>

            <.link
              :if={@current_scope.user.role in [:company_admin, :system_admin]}
              navigate={~p"/admin/enrollments"}
              class="px-3 py-2 text-sm font-medium text-base-content/70 hover:text-primary rounded-lg hover:bg-base-200 transition-colors"
            >
              Enrollments
            </.link>

            <.link
              :if={@current_scope.user.role == :employee}
              navigate={~p"/my-learning"}
              class="px-3 py-2 text-sm font-medium text-base-content/70 hover:text-primary rounded-lg hover:bg-base-200 transition-colors"
            >
              My Learning
            </.link>
          </nav>

          <%!-- Right: Theme toggle + user info --%>
          <div class="flex items-center gap-3">
            <.theme_toggle />
            <div :if={@current_scope} class="hidden sm:flex items-center gap-3">
              <span class="text-sm text-base-content/60">{@current_scope.user.email}</span>
              <.link
                href={~p"/users/settings"}
                class="text-sm text-base-content/70 hover:text-primary transition-colors"
              >
                Settings
              </.link>
              <.link
                href={~p"/users/log-out"}
                method="delete"
                class="text-sm text-base-content/70 hover:text-primary transition-colors"
              >
                Log out
              </.link>
            </div>
          </div>
        </div>
      </div>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders a minimal landing page layout without app chrome.

  This layout is used for the public landing page which has its own
  navigation and full-page sections.

  ## Examples

      <Layouts.landing flash={@flash}>
        <h1>Welcome</h1>
      </Layouts.landing>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_scope, :map, default: nil, doc: "the current scope (unused on landing page)"
  slot :inner_block

  def landing(assigns) do
    ~H"""
    <main>
      {render_slot(@inner_block) || @inner_content}
    </main>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
