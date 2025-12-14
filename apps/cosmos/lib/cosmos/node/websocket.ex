defmodule Cosmos.Node.Websocket do
  defmacro __using__(opts) do
    quote do
      @moduledoc """
      WebSocket client for connecting to ThorNode's WebSocket endpoint.

      Integrates with Thornode.Sessions to track block-processing sessions.
      Uses 'broadcast first, then checkpoint' for at-least-once delivery semantics.
      """
      use WebSockex
      require Logger
      @name unquote(opts[:name])

      def start_link(opts) do
        endpoint = Keyword.get(opts, :endpoint)
        publisher = Keyword.get(opts, :publisher)
        subscriptions = Keyword.get(opts, :subscriptions)

        Logger.info("#{__MODULE__} Starting node websocket: #{endpoint}")

        case WebSockex.start_link(
               "#{endpoint}/websocket",
               __MODULE__,
               %{publisher: publisher, subscriptions: subscriptions},
               name: @name
             ) do
          {:ok, pid} ->
            subscriptions
            |> Enum.with_index()
            |> Enum.each(fn {subscription, id} ->
              do_subscribe(pid, id, subscription)
            end)

            {:ok, pid}

          {:error, reason} ->
            Logger.error("#{__MODULE__} Error connecting to websocket #{endpoint}")
            {:error, reason}
        end
      end

      def handle_connect(_conn, state) do
        Logger.info("#{__MODULE__} Connected")
        {:ok, state}
      end

      def handle_disconnect(%{conn: %{host: host}}, state) do
        Logger.error("#{__MODULE__} disconnected: #{host}")
        {:ok, state}
      end

      def handle_frame({:text, msg}, state) do
        with {:ok, %{id: id, result: %{data: %{type: t, value: v}}}} <-
               Jason.decode(msg, keys: :atoms) do
          Logger.debug("#{__MODULE__} Subscription #{id} event #{t}")
          :ok = state.publisher.publish(v)
          {:ok, state}
        else
          {:ok, %{id: id, jsonrpc: "2.0", result: %{}}} ->
            Logger.info("#{__MODULE__} Subscription #{id} successful")
            {:ok, state}

          {:error, %{message: message}} ->
            Logger.error("#{__MODULE__} #{message}")
            {:close, state}

          {:error, error} ->
            Logger.error("#{__MODULE__} #{inspect(error)}")
            {:close, state}

          other ->
            Logger.error("#{__MODULE__} #{inspect(other)}")
            {:close, state}
        end
      end

      def handle_cast({:send, {_type, msg} = frame}, state) do
        Logger.debug("#{__MODULE__} [send] #{msg}")

        {:reply, frame, state}
      end

      defp do_subscribe(pid, id, query) do
        message =
          Jason.encode!(%{
            jsonrpc: "2.0",
            method: "subscribe",
            id: id,
            params: %{
              query: query
            }
          })

        WebSockex.send_frame(pid, {:text, message})
      end
    end
  end
end
