defmodule ZefyrlabWeb.Application do
  @moduledoc """
  ZefyrlabWeb Application - Phoenix LiveView dashboard
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Zefyrlab.Repo,
      ZefyrlabWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:zefyrlab_web, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ZefyrlabWeb.PubSub},
      ZefyrlabWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ZefyrlabWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ZefyrlabWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
