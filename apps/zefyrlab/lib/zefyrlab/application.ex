defmodule Zefyrlab.Application do
  @moduledoc """
  Zefyrlab Application - THORChain indexer and data provider
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {GRPC.Client.Supervisor, []},
      {Phoenix.PubSub, name: Zefyrlab.PubSub},
      {Task.Supervisor, name: Zefyrlab.TaskSupervisor},
      Zefyrlab.Node,
      Zefyrlab.Repo,
      Zefyrlab.NetworkMetrics
    ]

    opts = [strategy: :one_for_one, name: Zefyrlab.Supervisor]
    children = children ++ MagicAuth.children()
    Supervisor.start_link(children, opts)
  end
end
