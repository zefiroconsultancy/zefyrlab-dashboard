defmodule Zefyrlab.Publisher do
  @behaviour Cosmos.Node.Publisher
  require Logger

  def publish(value) do
    with {:ok, block} <- Rujira.Thorchain.block(get_height(value)) do
      broadcast(block)
    end
  end

  def get_height(value) do
    value
    |> Map.get(:block)
    |> Map.get(:header)
    |> Map.get(:height)
  end

  def broadcast(%{header: %{height: height}} = block) do
    Logger.info("#{__MODULE__} broadcast block #{height}")

    Phoenix.PubSub.broadcast(
      Zefyrlab.PubSub,
      Zefyrlab.Observer.pubsub_topic(),
      block
    )
  end
end
