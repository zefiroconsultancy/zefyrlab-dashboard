defmodule Cosmos.Node do
  defmacro __using__(opts) do
    quote do
      use Supervisor
      require Logger

      defmodule Pool do
        use Cosmos.Node.Pool, name: :"#{unquote(opts)[:otp_app]}:#{__MODULE__}"
      end

      defmodule Websocket do
        use Cosmos.Node.Websocket, name: :"#{unquote(opts)[:otp_app]}:#{__MODULE__}"
      end

      def start_link(_opts \\ []) do
        Logger.info("#{__MODULE__} Starting")
        config = Application.get_env(unquote(opts)[:otp_app], __MODULE__, [])

        Supervisor.start_link(__MODULE__, Keyword.merge(unquote(opts), config), name: __MODULE__)
      end

      def init(opts) do
        grpc =
          opts |> Keyword.get(:grpc) ||
            throw("gRPC endpoint required for #{__MODULE__}")

        socket =
          opts |> Keyword.get(:websocket) ||
            throw("gRPC endpoint required for #{__MODULE__}")

        subscriptions =
          opts
          |> Keyword.get(:subscriptions, unquote(opts)[:subscriptions] || ["tm.event='NewBlock'"])

        publisher =
          opts
          |> Keyword.get(:publisher, unquote(opts)[:publisher])

        Supervisor.init(
          [
            {Pool, endpoint: grpc, poolboy: Keyword.get(opts, :poolboy, [])},
            {Websocket, endpoint: socket, subscriptions: subscriptions, publisher: publisher}
          ],
          strategy: :one_for_one
        )
      end

      defdelegate query(query_fn, req, opts \\ []), to: Pool
      defdelegate broadcast(tx_bytes, opts \\ []), to: Pool
      defdelegate simulate(tx_bytes, opts \\ []), to: Pool
    end
  end
end
