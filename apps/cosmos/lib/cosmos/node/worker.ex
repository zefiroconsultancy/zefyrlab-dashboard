defmodule Cosmos.Node.Worker do
  @moduledoc """
  Worker module for handling gRPC connections to ThorNode.

  This GenServer manages the lifecycle of gRPC connections to ThorNode endpoints,
  including connection pooling and failover between different endpoints.
  """
  require Logger
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(endpoint) do
    Process.flag(:trap_exit, true)

    send(self(), :connect)

    {:ok,
     %{
       endpoint: endpoint,
       connection: nil
     }}
  end

  def connect(addr) do
    if String.ends_with?(addr, ":443") do
      cred = GRPC.Credential.new(ssl: [verify: :verify_none])

      GRPC.Stub.connect(addr,
        interceptors: [{GRPC.Client.Interceptors.Logger, level: :debug}],
        cred: cred
      )
    else
      GRPC.Stub.connect(addr,
        interceptors: [{GRPC.Client.Interceptors.Logger, level: :debug}]
      )
    end
  end

  def handle_info({:gun_down, _pid, _protocol, _message, _}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:gun_data, _pid, _ref, :fin, message}, state) do
    {:stop, message, state}
  end

  def handle_info({:EXIT, _pid, message}, state) do
    {:stop, message, state}
  end

  def handle_info(:connect, %{endpoint: endpoint} = state) do
    case do_init(endpoint) do
      {:ok, connection} ->
        Logger.debug("gRPC Connected to #{connection.host}")
        {:noreply, %{state | connection: connection}}

      {:stop, reason} ->
        Logger.error("gRPC Failed to connect: #{reason}")
        {:stop, reason}
    end
  end

  defp do_init(endpoint) do
    case connect(endpoint) do
      {:ok, connection} ->
        Logger.debug("gRPC Connected to #{connection.host}")
        {:ok, connection}

      {:error, error} ->
        Logger.error("gRPC Failed for #{endpoint}, #{error}")
        {:stop, :no_connections}
    end
  end

  def handle_call(
        {:request, stub_fn, req},
        _,
        %{connection: %GRPC.Channel{} = channel} = state
      ) do
    stub_fn.(channel, req)
    |> case do
      {:ok, res} -> {:reply, {:ok, res}, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end
end
