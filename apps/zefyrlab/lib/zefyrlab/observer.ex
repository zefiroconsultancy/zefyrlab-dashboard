defmodule Zefyrlab.Observer do
  @moduledoc """
  A simple behaviour module for creating blockchain observers that automatically
  subscribe to NewBlock events.

  ## Usage

      defmodule MyApp.BlockObserver do
        use Zefyrlab.Observer

        def handle_new_block(%{header: %{height: height}} = block, state) do
          # Process block data
          {:noreply, state}
        end
      end
  """

  @callback handle_new_block(block :: map(), state :: term()) ::
              {:noreply, new_state :: term()} | {:stop, reason :: term(), new_state :: term()}

  @pubsub_topic "zefyrlab:blocks"

  def pubsub_topic, do: @pubsub_topic

  defmacro __using__(_opts) do
    quote do
      use GenServer
      require Logger

      @behaviour Zefyrlab.Observer

      def start_link(init_arg \\ []) do
        GenServer.start_link(__MODULE__, init_arg)
      end

      @impl true
      def init(state) do
        Phoenix.PubSub.subscribe(Zefyrlab.PubSub, Zefyrlab.Observer.pubsub_topic())
        {:ok, state}
      end

      @impl true
      def handle_info(
            %{header: %{chain_id: chain_id, height: height, time: time}} = message,
            state
          ) do
        Logger.debug("#{__MODULE__} processing block #{height} on #{chain_id}")

        try do
          handle_new_block(message, state)
        rescue
          error ->
            Logger.error("#{__MODULE__} error processing block #{height}: #{inspect(error)}")
            {:noreply, state}
        end
      end

      # Allow other handle_info patterns to be defined by the implementing module
      def handle_info(message, state) do
        Logger.warning("Unhandled message in #{__MODULE__}: #{inspect(message)}")
        {:noreply, state}
      end

      # Make handle_info overridable so implementing modules can add their own patterns
      defoverridable handle_info: 2
    end
  end
end
