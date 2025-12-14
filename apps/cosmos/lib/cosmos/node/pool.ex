defmodule Cosmos.Node.Pool do
  defmacro __using__(opts) do
    quote do
      @moduledoc """
      Manages pools of gRPC worker processes for communicating with the Cosmos node.

      Provides separate pools for:
      - Query operations (read-only)
      - Transaction operations (broadcast/simulate)
      """

      use Supervisor
      require Logger

      alias Cosmos.Tx.V1beta1.BroadcastTxRequest
      alias Cosmos.Tx.V1beta1.SimulateRequest
      alias Cosmos.Tx.V1beta1.Service.Stub

      @timeout 10_000
      @query_pool_name :"#{unquote(opts[:name])}_query"
      @tx_pool_name :"#{unquote(opts[:name])}_tx"

      def start_link(opts \\ []) do
        Logger.info("Starting #{__MODULE__} link")
        Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
      end

      @impl true
      def init(opts) do
        endpoint = Keyword.get(opts, :endpoint)
        poolboy = Keyword.get(opts, :poolboy, [])
        query_pool = Keyword.get(opts, :query_pool, poolboy)
        tx_pool = Keyword.get(opts, :tx_pool, poolboy)

        # Query pool: optimized for read operations
        query_options =
          Keyword.merge(
            [
              name: {:local, @query_pool_name},
              worker_module: Cosmos.Node.Worker,
              size: 2,
              max_overflow: 3
            ],
            query_pool
          )

        # Transaction pool: dedicated for broadcast/simulate operations
        tx_options =
          Keyword.merge(
            [
              name: {:local, @tx_pool_name},
              worker_module: Cosmos.Node.Worker,
              size: 1,
              max_overflow: 1
            ],
            tx_pool
          )

        children = [
          :poolboy.child_spec(@query_pool_name, query_options, endpoint),
          :poolboy.child_spec(@tx_pool_name, tx_options, endpoint)
        ]

        Supervisor.init(children, strategy: :one_for_one)
      end

      def query(query_fn, req, opts \\ []) do
        :poolboy.transaction(@query_pool_name, fn worker_pid ->
          try do
            GenServer.call(worker_pid, {:request, query_fn, req}, @timeout)
          rescue
            error -> {:error, {:exception, error}}
          catch
            :exit, {:timeout, _} ->
              Logger.warning("#{__MODULE__} query timeout #{inspect(req)}")
              {:error, :timeout}

            :exit, reason ->
              {:error, {:exit, reason}}
          end
        end)
      end

      def broadcast(tx_bytes, opts \\ []) when is_binary(tx_bytes) do
        mode = to_broadcast_mode(Keyword.get(opts, :mode, :sync))
        request = %BroadcastTxRequest{tx_bytes: tx_bytes, mode: mode}

        :poolboy.transaction(@tx_pool_name, fn worker_pid ->
          try do
            GenServer.call(worker_pid, {:request, &Stub.broadcast_tx/3, request}, @timeout)
          rescue
            error -> {:error, {:exception, error}}
          catch
            :exit, {:timeout, _} ->
              Logger.warning("#{__MODULE__} broadcast timeout")
              {:error, :timeout}

            :exit, reason ->
              {:error, {:exit, reason}}
          end
        end)
        |> case do
          {:ok, response} -> extract_txhash(response)
          error -> error
        end
      end

      def simulate(tx_bytes, opts \\ []) when is_binary(tx_bytes) do
        request = %SimulateRequest{tx_bytes: tx_bytes}

        :poolboy.transaction(@tx_pool_name, fn worker_pid ->
          try do
            GenServer.call(worker_pid, {:request, &Stub.simulate/3, request}, @timeout)
          rescue
            error -> {:error, {:exception, error}}
          catch
            :exit, {:timeout, _} ->
              Logger.warning("#{__MODULE__} simulate timeout")
              {:error, :timeout}

            :exit, reason ->
              {:error, {:exit, reason}}
          end
        end)
      end

      defp to_broadcast_mode(:async), do: :BROADCAST_MODE_ASYNC
      defp to_broadcast_mode(:sync), do: :BROADCAST_MODE_SYNC
      defp to_broadcast_mode(:commit), do: :BROADCAST_MODE_BLOCK
      defp to_broadcast_mode(_), do: :BROADCAST_MODE_SYNC

      defp extract_txhash(%{tx_response: %{txhash: hash}})
           when is_binary(hash) and byte_size(hash) > 0,
           do: {:ok, hash}

      defp extract_txhash(%{tx_response: resp}) when is_map(resp),
        do: {:error, {:empty_txhash, resp}}

      defp extract_txhash(other), do: {:error, {:no_tx_response, other}}
    end
  end
end
