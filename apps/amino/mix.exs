defmodule Amino.MixProject do
  use Mix.Project

  def project do
    [
      app: :amino,
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
      {:protobuf, "~> 0.14.0"}
    ]
  end
end
