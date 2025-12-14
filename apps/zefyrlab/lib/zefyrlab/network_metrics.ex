defmodule Zefyrlab.NetworkMetrics do
  @moduledoc """
  Handles queries for Network Metrics.
  """

  alias Zefyrlab.Resolution
  alias Zefyrlab.NetworkMetrics.Bin
  alias Zefyrlab.Repo

  require Logger

  import Ecto.Query

  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    Resolution.resolutions()
    |> Enum.map(&Supervisor.child_spec({Bin, &1}, id: &1))
    |> Enum.concat([Supervisor.child_spec({__MODULE__.Indexer, []}, id: :indexer)])
    |> Supervisor.init(strategy: :one_for_one)
  end

  # ----------------
  # Insert
  # ----------------

  def insert_bins(time, resolution) do
    now = DateTime.utc_now()

    new =
      from(c in Bin,
        where: c.resolution == ^resolution,
        order_by: [desc: c.bin]
      )
      |> Repo.all()
      |> Enum.map(&Bin.default(&1, time, now))

    Repo.insert_all(Bin, new,
      # Conflict will be hit if race condition has triggered insert before this is reached
      on_conflict: :nothing,
      returning: true
    )
  end

  def update_bins(entry, time) do
    time
    |> Resolution.active()
    |> Enum.map(&to_bin(entry, &1))
    |> Bin.update()
  end

  defp to_bin(entry, {resolution, bin}) do
    now = DateTime.utc_now()

    Map.merge(entry, %{
        id: Bin.id(resolution, bin),
        resolution: resolution,
        bin: bin,
        inserted_at: now,
        updated_at: now
      })
  end
end
