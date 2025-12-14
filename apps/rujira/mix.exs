defmodule Rujira.MixProject do
  use Mix.Project

  def project do
    [
      app: :rujira,
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
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test),
    do: ["lib", "test/support", "test/rujira_web/fragments", "test/fixtures"]

  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Internal umbrella dependencies
      {:amino, in_umbrella: true},
      {:cosmos, in_umbrella: true},
      {:cosmwasm, in_umbrella: true},
      {:tendermint, in_umbrella: true},
      {:thorchain, in_umbrella: true},
      # External dependencies (versions controlled by umbrella)
      {:google_protos, "~> 0.4"},
      {:grpc, "~> 0.9"},
      {:jason, "~> 1.2"},
      {:protobuf, "~> 0.14.0"},
      {:yaml_elixir, "~> 2.11.0"},
      {:memoize, "~> 1.4"},
      {:websockex, "~> 0.4"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      test: ["test"]
    ]
  end
end
