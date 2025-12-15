defmodule ZefyrlabWeb.Application do
  @moduledoc """
  ZefyrlabWeb Application - Phoenix LiveView dashboard
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Ensure backend app (Repo, indexers, etc.) is running when web starts.
    case Application.ensure_all_started(:zefyrlab) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        raise "Failed to start :zefyrlab app: #{inspect(reason)}"
    end

    children = [
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
