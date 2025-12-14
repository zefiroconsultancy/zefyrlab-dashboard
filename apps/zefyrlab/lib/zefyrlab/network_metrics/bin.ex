defmodule Zefyrlab.NetworkMetrics.Bin do
  @moduledoc """

  """

  use Ecto.Schema
  use GenServer

  import Ecto.Query

  require Logger

  alias Zefyrlab.NetworkMetrics
  alias Zefyrlab.Resolution
  alias Zefyrlab.Repo

  @primary_key false
  schema "network_metric_bins" do
    field(:id, :string)
    field(:bin, :utc_datetime, primary_key: true)
    field(:resolution, :string, primary_key: true)
    field(:volume, :integer)
    field(:tvl, :integer)
    field(:utilization_ratio, :decimal)

    timestamps(type: :utc_datetime_usec)
  end

  def default(prev_bin, time, now) do
    %{
      # Identifiers
      id: id(prev_bin.resolution, time),
      resolution: prev_bin.resolution,
      bin: time,
      volume: 0,
      tvl: prev_bin.tvl,
      utilization_ratio: 0
    }
  end

  def id(resolution, bin),
    do: "#{resolution}/#{DateTime.to_iso8601(bin)}"

  def update(entries) do
    __MODULE__
    |> Repo.insert_all(
      entries,
      on_conflict: handle_conflict(),
      conflict_target: [:resolution, :bin],
      returning: true
    )
  end

  defp handle_conflict do
    from(b in __MODULE__,
      update: [
        set: [
          volume: fragment("EXCLUDED.volume + ?", b.volume),
          tvl: fragment("EXCLUDED.tvl"),
          utilization_ratio:
            fragment(
              "CASE WHEN EXCLUDED.tvl > 0 THEN (EXCLUDED.volume + ?)::decimal / (EXCLUDED.tvl) ELSE 0 END",
              b.volume
            ),
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ]
    )
  end

  # ------------------------ Gen Server ------------------------
  def start_link(resolution) do
    GenServer.start_link(__MODULE__, resolution)
  end

  @impl true
  def init(resolution) do
    next =
      DateTime.utc_now()
      |> Resolution.truncate(resolution)
      |> Resolution.add(resolution)

    send(self(), next)
    {:ok, resolution}
  end

  @impl true
  def handle_info(time, resolution) do
    now = DateTime.utc_now()

    case DateTime.compare(time, now) do
      :gt ->
        now = DateTime.utc_now()
        delay = max(0, DateTime.diff(time, now, :millisecond))
        Process.send_after(self(), time, delay)
        {:noreply, resolution}

      _ ->
        Logger.debug("#{__MODULE__} #{resolution} #{time}")
        NetworkMetrics.insert_bins(time, resolution)

        time = Resolution.add(time, resolution)
        delay = max(0, DateTime.diff(time, now, :millisecond))
        Process.send_after(self(), time, delay)
        {:noreply, resolution}
    end
  end
end
