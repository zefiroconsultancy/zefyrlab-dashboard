defmodule Cosmos.MixProject do
  use Mix.Project

  def project do
    [
      app: :cosmos,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp deps do
    [
      # External dependencies (versions controlled by umbrella)
      {:protobuf, "~> 0.14.0"},
      {:grpc, "~> 0.11.5"},
      {:ex_secp256k1, "~> 0.7.6"},
      {:jason, "~> 1.2"},
      {:google_protos, "~> 0.4"},
      {:mox, "~> 1.1", only: :test},
      {:mock, "~> 0.3.0", only: :test},
      {:memoize, "~> 1.4.3"}
    ]
  end
end
