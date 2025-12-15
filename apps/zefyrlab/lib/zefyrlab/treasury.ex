defmodule Zefyrlab.Treasury do
  @moduledoc """
  Handles treasury bin scheduling and updates.
  """

  use Supervisor

  import Ecto.Query

  alias Zefyrlab.Resolution
  alias Zefyrlab.Repo
  alias Zefyrlab.Treasury.Bin

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    config = Application.get_env(:zefyrlab, :treasury, [])
    validators = Keyword.get(config, :validators, [])
    providers = Keyword.get(config, :providers, [])

    Resolution.resolutions()
    |> Enum.map(&Supervisor.child_spec({Bin, &1}, id: &1))
    |> Enum.concat([
      Supervisor.child_spec(
        {__MODULE__.Indexer, %{validators: validators, providers: providers}},
        id: :treasury_indexer
      )
    ])
    |> Supervisor.init(strategy: :one_for_one)
  end

  def insert_bin(time, resolution) do
    now = DateTime.utc_now()

    new =
      from(c in Bin,
        where: c.resolution == ^resolution,
        order_by: [desc: c.bin]
      )
      |> Repo.all()
      |> Enum.map(&Bin.default(&1, time, now))

    Repo.insert_all(Bin, new, on_conflict: :nothing, returning: true)
  end

  def update_bins(entry, time) do
    result = time
    |> Resolution.active()
    |> Enum.map(&to_bin(entry, &1))
    |> Bin.update()

    # Broadcast to LiveView subscribers
    Phoenix.PubSub.broadcast(
      Zefyrlab.PubSub,
      "dashboard:metrics",
      {:metrics_updated, %{}}
    )

    result
  end

  defp to_bin(entry, {resolution, bin}) do
    now = DateTime.utc_now()

    entry
    |> Map.merge(%{
      id: Bin.id(resolution, bin),
      resolution: resolution,
      bin: bin,
      inserted_at: now,
      updated_at: now
    })
  end
end
