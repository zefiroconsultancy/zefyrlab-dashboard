defmodule Zefyrlab.Application do
  @moduledoc """
  Zefyrlab Application - THORChain indexer and data provider
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Zefyrlab.PubSub}
    ]

    opts = [strategy: :one_for_one, name: Zefyrlab.Supervisor]
    children = children ++ MagicAuth.children()
    Supervisor.start_link(children, opts)
  end
end
