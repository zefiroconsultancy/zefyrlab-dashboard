defmodule Zefyrlab.Oracle do
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("#{__MODULE__} started")

    children = [
      {__MODULE__.Listener, %__MODULE__.Listener.State{prices: %{}}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
