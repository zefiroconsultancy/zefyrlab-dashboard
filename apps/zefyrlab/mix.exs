defmodule Zefyrlab.MixProject do
  use Mix.Project

  def project do
    [
      app: :zefyrlab,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Zefyrlab.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:thorchain, in_umbrella: true},
      {:rujira, in_umbrella: true},
      {:cosmos, in_umbrella: true},
      {:bandit, "~> 1.5"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.10"},
      {:google_protos, "~> 0.4"},
      {:grpc, "~> 0.9"},
      {:jason, "~> 1.2"},
      {:memoize, "~> 1.4"},
      {:mox, "~> 1.2"},
      {:phoenix, "~> 1.7.14"},
      {:phoenix_ecto, "~> 4.5"},
      {:poolboy, "~> 1.5.1"},
      {:postgrex, ">= 0.0.0"},
      {:protobuf, "~> 0.14.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:websockex, "~> 0.4.3"},
      {:magic_auth, "~> 0.2.0"},
      {:swoosh, "~> 1.16"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
