defmodule LmsWeb.CompanyRegistrationLive do
  use LmsWeb, :live_view

  alias Lms.Companies

  @impl true
  def mount(_params, _session, socket) do
    changeset = Companies.change_registration()

    socket =
      socket
      |> assign(:current_scope, nil)
      |> assign(:page_title, gettext("Register Your Company"))
      |> assign(:form, to_form(changeset, as: "registration"))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"registration" => params}, socket) do
    changeset =
      Companies.change_registration(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "registration"))}
  end

  @impl true
  def handle_event("save", %{"registration" => params}, socket) do
    case Companies.register_company(params) do
      {:ok, %{user: user}} ->
        token = Phoenix.Token.sign(socket.endpoint, "company_registration", user.id)

        {:noreply, redirect(socket, to: ~p"/users/registration-login?token=#{token}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "registration"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="text-center mb-8">
          <.link navigate={~p"/"} class="text-2xl font-bold text-primary tracking-tight">
            Uplift
          </.link>
          <h1 class="mt-4 text-xl font-semibold text-base-content">
            {gettext("Register Your Company")}
          </h1>
          <p class="mt-2 text-sm text-base-content/60">
            {gettext("Create your organization and admin account to get started.")}
          </p>
        </div>

        <div class="card bg-base-200 shadow-sm rounded-2xl">
          <div class="card-body">
            <.form
              for={@form}
              id="registration-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-1"
            >
              <div class="mb-2">
                <p class="text-xs font-semibold uppercase tracking-wider text-base-content/50 mb-3">
                  {gettext("Company")}
                </p>
                <.input
                  field={@form[:company_name]}
                  type="text"
                  label={gettext("Company name")}
                  placeholder={gettext("Acme Corporation")}
                  required
                />
              </div>

              <div class="divider my-1"></div>

              <div class="mb-2">
                <p class="text-xs font-semibold uppercase tracking-wider text-base-content/50 mb-3">
                  {gettext("Admin Account")}
                </p>
                <.input
                  field={@form[:name]}
                  type="text"
                  label={gettext("Full name")}
                  placeholder={gettext("Jane Smith")}
                  required
                />
                <.input
                  field={@form[:email]}
                  type="email"
                  label={gettext("Email")}
                  placeholder={gettext("admin@company.com")}
                  required
                />
                <.input
                  field={@form[:password]}
                  type="password"
                  label={gettext("Password")}
                  placeholder={gettext("Minimum 12 characters")}
                  required
                />
                <.input
                  field={@form[:password_confirmation]}
                  type="password"
                  label={gettext("Confirm password")}
                  required
                />
              </div>

              <.button
                variant="primary"
                class="btn btn-primary w-full mt-4"
                phx-disable-with={gettext("Registering...")}
              >
                {gettext("Create Account")}
              </.button>
            </.form>
          </div>
        </div>

        <p class="text-center text-sm text-base-content/60 mt-6">
          {gettext("Already have an account?")}
          <.link navigate={~p"/users/log-in"} class="font-semibold text-primary hover:underline">
            {gettext("Log in")}
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end
end
