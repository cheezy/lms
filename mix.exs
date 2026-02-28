defmodule Lms.MixProject do
  use Mix.Project

  def project do
    [
      app: :lms,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: test_coverage(),
      usage_rules: usage_rules()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Lms.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:ecto_psql_extras, "~> 0.8"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:usage_rules, "~> 1.0", only: [:dev]},
      {:igniter, "~> 0.6", only: [:dev]},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:tidewave, "~> 0.2", only: :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind lms", "esbuild lms"],
      "assets.deploy": [
        "tailwind lms --minify",
        "esbuild lms --minify",
        "phx.digest"
      ],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  defp test_coverage do
    [
      ignore_modules: [
        Lms.AccountsFixtures,
        Lms.Application,
        Lms.DataCase,
        Lms.Repo,
        Lms.CompaniesFixtures,
        Lms.ConnCase,
        Lms.TrainingFixtures,
        LmsWeb.CoreComponents,
        LmsWeb.ErrorHTML,
        LmsWeb.Layouts,
        LmsWeb.PageController,
        LmsWeb.PageHTML,
        LmsWeb.Router,
        LmsWeb.Telemetry,
        # Placeholder LiveViews (stubs pending full implementation)
        LmsWeb.Admin.CompanyListLive,
        LmsWeb.CourseListLive,
        LmsWeb.DashboardLive,
        LmsWeb.Employee.MyLearningLive,
        # Generated HTML modules
        LmsWeb.UserRegistrationHTML,
        LmsWeb.UserSettingsHTML
      ]
    ]
  end

  defp usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: [
        ~r/^usage_rules/
      ],

      # or use skills
      skills: [
        location: ".claude/skills",
        # build skills that combine multiple usage rules
        build: [
          "phoenix-framework": [
            description:
              "Use this skill working with Phoenix Framework. Consult this when working with the web layer, controllers, views, liveviews etc.",
            # Include all Phoenix dependencies
            usage_rules: [:phoenix, ~r/^phoenix\//]
          ]
        ]
      ]
    ]
  end
end
