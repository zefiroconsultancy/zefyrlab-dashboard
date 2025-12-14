defmodule Zefyrlab.Treasury.Bin do
  @moduledoc """

  """

  use Ecto.Schema
  use GenServer

  import Ecto.Query

  require Logger

  alias Zefyrlab.Repo
  alias Zefyrlab.Resolution
  alias Zefyrlab.Treasury
  alias Decimal, as: D

  @primary_key false
  schema "treasury_bins" do
    field(:id, :string)
    field(:bin, :utc_datetime, primary_key: true)
    field(:resolution, :string, primary_key: true)

    # price
    field(:rune_usd_price, :decimal)

    # treasury
    field(:bonded_rune, :integer)
    field(:wallet_rune, :integer)
    field(:total_rune, :integer)

    field(:bonded_rune_usd, :decimal)
    field(:wallet_rune_usd, :decimal)
    field(:total_rune_usd, :decimal)

    # flows of capital
    field(:capital_inflows_rune, :integer)
    field(:revenue_inflows_rune, :integer)
    field(:cost_outflows_rune, :integer)

    # USD flows (price * rune amount)
    field(:capital_inflows_usd, :decimal)
    field(:revenue_inflows_usd, :decimal)
    field(:cost_outflows_usd, :decimal)

    # Net changes (rune)
    field(:net_inflows_rune, :integer)
    field(:net_cashflow_rune, :integer)
    field(:net_change_assets_rune, :integer)

    # Net changes (USD)
    field(:net_inflows_usd, :decimal)
    field(:net_cashflow_usd, :decimal)
    field(:net_change_assets_usd, :decimal)

    timestamps(type: :utc_datetime_usec)
  end

  def default(prev_bin, time, now) do
    rune_usd_price = prev_bin.rune_usd_price || D.new(0)
    bonded_rune = prev_bin.bonded_rune || 0
    wallet_rune = prev_bin.wallet_rune || 0
    total_rune = prev_bin.total_rune || 0

    %{
      # Identifiers
      id: id(prev_bin.resolution, time),
      resolution: prev_bin.resolution,
      bin: time,
      rune_usd_price: rune_usd_price,
      bonded_rune: bonded_rune,
      wallet_rune: wallet_rune,
      total_rune: total_rune,
      bonded_rune_usd: usd(bonded_rune, rune_usd_price),
      wallet_rune_usd: usd(wallet_rune, rune_usd_price),
      total_rune_usd: usd(total_rune, rune_usd_price),
      capital_inflows_rune: 0,
      revenue_inflows_rune: 0,
      cost_outflows_rune: 0,
      capital_inflows_usd: usd(0, rune_usd_price),
      revenue_inflows_usd: usd(0, rune_usd_price),
      cost_outflows_usd: usd(0, rune_usd_price),
      net_inflows_rune: 0,
      net_cashflow_rune: 0,
      net_change_assets_rune: 0,
      net_inflows_usd: usd(0, rune_usd_price),
      net_cashflow_usd: usd(0, rune_usd_price),
      net_change_assets_usd: usd(0, rune_usd_price),
      inserted_at: now,
      updated_at: now
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
          rune_usd_price: fragment("EXCLUDED.rune_usd_price"),
          bonded_rune: fragment("EXCLUDED.bonded_rune"),
          bonded_rune_usd:
            fragment("EXCLUDED.rune_usd_price * EXCLUDED.bonded_rune"),
          wallet_rune: fragment("EXCLUDED.wallet_rune"),
          wallet_rune_usd:
            fragment("EXCLUDED.rune_usd_price * EXCLUDED.wallet_rune"),
          total_rune: fragment("EXCLUDED.total_rune"),
          total_rune_usd:
            fragment("EXCLUDED.rune_usd_price * EXCLUDED.total_rune"),
          capital_inflows_rune:
            fragment("EXCLUDED.capital_inflows_rune + COALESCE(?, 0)", b.capital_inflows_rune),
          revenue_inflows_rune:
            fragment("EXCLUDED.revenue_inflows_rune + COALESCE(?, 0)", b.revenue_inflows_rune),
          cost_outflows_rune:
            fragment("EXCLUDED.cost_outflows_rune + COALESCE(?, 0)", b.cost_outflows_rune),
          net_inflows_rune:
            fragment(
              "(EXCLUDED.capital_inflows_rune + COALESCE(?, 0)) + (EXCLUDED.revenue_inflows_rune + COALESCE(?, 0))",
              b.capital_inflows_rune,
              b.revenue_inflows_rune
            ),
          net_cashflow_rune:
            fragment(
              "(EXCLUDED.capital_inflows_rune + COALESCE(?, 0)) + (EXCLUDED.revenue_inflows_rune + COALESCE(?, 0)) - (EXCLUDED.cost_outflows_rune + COALESCE(?, 0))",
              b.capital_inflows_rune,
              b.revenue_inflows_rune,
              b.cost_outflows_rune
            ),
          net_change_assets_rune:
            fragment("EXCLUDED.total_rune - COALESCE(?, 0)", b.total_rune),
          capital_inflows_usd:
            fragment(
              "EXCLUDED.rune_usd_price * (EXCLUDED.capital_inflows_rune + COALESCE(?, 0))",
              b.capital_inflows_rune
            ),
          revenue_inflows_usd:
            fragment(
              "EXCLUDED.rune_usd_price * (EXCLUDED.revenue_inflows_rune + COALESCE(?, 0))",
              b.revenue_inflows_rune
            ),
          cost_outflows_usd:
            fragment(
              "EXCLUDED.rune_usd_price * (EXCLUDED.cost_outflows_rune + COALESCE(?, 0))",
              b.cost_outflows_rune
            ),
          net_inflows_usd:
            fragment(
              "EXCLUDED.rune_usd_price * ((EXCLUDED.capital_inflows_rune + COALESCE(?, 0)) + (EXCLUDED.revenue_inflows_rune + COALESCE(?, 0)))",
              b.capital_inflows_rune,
              b.revenue_inflows_rune
            ),
          net_cashflow_usd:
            fragment(
              "EXCLUDED.rune_usd_price * ((EXCLUDED.capital_inflows_rune + COALESCE(?, 0)) + (EXCLUDED.revenue_inflows_rune + COALESCE(?, 0)) - (EXCLUDED.cost_outflows_rune + COALESCE(?, 0)))",
              b.capital_inflows_rune,
              b.revenue_inflows_rune,
              b.cost_outflows_rune
            ),
          net_change_assets_usd:
            fragment(
              "EXCLUDED.rune_usd_price * (EXCLUDED.total_rune - COALESCE(?, 0))",
              b.total_rune
            ),
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ]
    )
  end

  defp usd(amount, price), do: price |> D.mult(D.new(amount || 0))

  # Gen Server
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
        Treasury.insert_bin(time, resolution)

        time = Resolution.add(time, resolution)
        delay = max(0, DateTime.diff(time, now, :millisecond))
        Process.send_after(self(), time, delay)
        {:noreply, resolution}
    end
  end
end
