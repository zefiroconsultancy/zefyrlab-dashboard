defmodule Cosmwasm.MixProject do
  use Mix.Project

  def project do
    [
      app: :cosmwasm,
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
      {:grpc, "~> 0.9"}
    ]
  end
end
