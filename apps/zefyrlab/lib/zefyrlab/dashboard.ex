defmodule Zefyrlab.Dashboard do
  @moduledoc """
  Provides dashboard data for the web UI based on indexed metrics.
  Organized by 6 dashboard sections per specification.
  """

  import Ecto.Query

  alias Zefyrlab.NetworkMetrics.Bin, as: NetworkBin
  alias Zefyrlab.Treasury.Bin, as: TreasuryBin
  alias Zefyrlab.Repo
  alias Decimal, as: D

  # ============================================================================
  # Section 1: Hero Overview KPIs
  # ============================================================================

  @doc """
  Returns NAV (Net Asset Value) in USD.
  NAV = bonded_rune_usd + wallet_rune_usd from latest bin.
  """
  def nav_usd do
    latest = latest_treasury_bin()
    bonded = latest.bonded_rune_usd || D.new(0)
    wallet = latest.wallet_rune_usd || D.new(0)

    bonded
    |> D.add(wallet)
    |> D.to_float()
    # Convert from base units to actual USD
    |> usd_to_decimal()
    |> trunc()
    |> format_currency()
  end

  @doc """
  Returns YTD (Year-To-Date) realized rewards in USD.
  Sum of revenue_inflows_usd from Jan 1 to now (1D bins).
  """
  def ytd_rewards_usd do
    ytd_sum = ytd_revenue_inflows_usd()

    ytd_sum
    |> D.to_float()
    # Convert from base units to actual USD
    |> usd_to_decimal()
    |> trunc()
    |> format_currency()
  end

  @doc """
  Returns realized APY based on last 7 days.
  Formula: (sum of last 7d revenue_inflows_rune / avg bonded_rune) / 7 * 365 * 100
  """
  def realized_apy do
    case last_7_days_treasury_bins() do
      [] ->
        "0.0%"

      bins ->
        # Convert RUNE base units to decimal
        total_rewards_rune =
          Enum.reduce(bins, 0.0, fn bin, acc ->
            acc + rune_to_decimal(bin.revenue_inflows_rune || 0)
          end)

        avg_bonded_rune =
          Enum.reduce(bins, 0.0, fn bin, acc ->
            acc + rune_to_decimal(bin.bonded_rune || 0)
          end) / length(bins)

        if avg_bonded_rune > 0 do
          apy = total_rewards_rune / avg_bonded_rune / 7 * 365 * 100
          format_percentage(apy)
        else
          "0.0%"
        end
    end
  end

  @doc """
  Returns net capital deployed (lifetime).
  Formula: sum(capital_inflows_usd) - sum(cost_outflows_usd)
  """
  def net_capital_deployed_usd do
    query =
      from(b in TreasuryBin,
        where: b.resolution == "1D",
        select: %{
          capital_in: coalesce(sum(b.capital_inflows_usd), 0),
          costs_out: coalesce(sum(b.cost_outflows_usd), 0)
        }
      )

    result = Repo.one(query) || %{capital_in: D.new(0), costs_out: D.new(0)}

    result.capital_in
    |> D.sub(result.costs_out)
    |> D.to_float()
    # Convert from base units to actual USD
    |> usd_to_decimal()
    |> trunc()
    |> format_currency()
  rescue
    _ -> format_currency(0)
  end

  # ============================================================================
  # Section 2: Projections & Scenarios (Mocked)
  # ============================================================================

  @doc """
  Returns projection data for a given scenario.
  Scenarios: "downside", "base", "upside"
  Returns chart data + KPIs (FY1 income, raise size/timing, multiple, IRR)
  """
  def projection_data(scenario \\ "base") do
    scenarios = %{
      "downside" => %{
        chart: projection_chart_downside(),
        fy1_net_income: "$850K",
        raise_size: "$2.5M",
        raise_timing: "Q4 2026",
        money_multiple: "2.1x",
        irr_5y: "15.8%"
      },
      "base" => %{
        chart: projection_chart_base(),
        fy1_net_income: "$1.2M",
        raise_size: "$3.5M",
        raise_timing: "Q2 2026",
        money_multiple: "3.2x",
        irr_5y: "26.4%"
      },
      "upside" => %{
        chart: projection_chart_upside(),
        fy1_net_income: "$1.8M",
        raise_size: "$5.0M",
        raise_timing: "Q1 2026",
        money_multiple: "4.5x",
        irr_5y: "35.2%"
      }
    }

    Map.get(scenarios, scenario, scenarios["base"])
  end

  # ============================================================================
  # Section 3: Network Metrics (90 days)
  # ============================================================================

  @doc """
  Returns network metrics chart data for last 90 days.
  Includes current values and 7d/30d averages.
  """
  def network_metrics_90d do
    bins = fetch_network_bins(days_back: 90)

    %{
      chart: %{
        labels: Enum.map(bins, &format_label/1),
        tvl: Enum.map(bins, &usd_to_decimal(&1.tvl || 0)),
        volume: Enum.map(bins, &usd_to_decimal(&1.volume || 0)),
        utilization: Enum.map(bins, &d_to_float(&1.utilization_ratio))
      },
      current: network_current_values(bins),
      averages: network_averages(bins)
    }
  end

  # ============================================================================
  # Section 4: Treasury Balances Evolution (180 days)
  # ============================================================================

  @doc """
  Returns treasury balances chart data for last 180 days.
  Time series of wallet_rune, bonded_rune, net_cashflow.
  Supports both USD and RUNE currency.
  """
  def treasury_balances_180d(currency \\ :usd) do
    bins = fetch_treasury_bins(days_back: 180)

    case currency do
      :rune ->
        %{
          chart: %{
            labels: Enum.map(bins, &format_label/1),
            wallet: Enum.map(bins, &rune_to_decimal(&1.wallet_rune || 0)),
            bonded: Enum.map(bins, &rune_to_decimal(&1.bonded_rune || 0)),
            net_cashflow: Enum.map(bins, &rune_to_decimal(&1.net_cashflow_rune || 0))
          },
          table: latest_balances_table(bins, :rune)
        }

      :usd ->
        %{
          chart: %{
            labels: Enum.map(bins, &format_label/1),
            wallet: Enum.map(bins, &usd_to_decimal(d_to_float(&1.wallet_rune_usd))),
            bonded: Enum.map(bins, &usd_to_decimal(d_to_float(&1.bonded_rune_usd))),
            net_cashflow: Enum.map(bins, &usd_to_decimal(d_to_float(&1.net_cashflow_usd)))
          },
          table: latest_balances_table(bins, :usd)
        }
    end
  end

  # ============================================================================
  # Section 5: Realized Rewards Breakdown (90 days)
  # ============================================================================

  @doc """
  Returns realized rewards chart data for last 90 days.
  Daily rewards vs bonded capital with realized daily return %.
  """
  def rewards_chart_90d do
    bins = fetch_treasury_bins(days_back: 90)

    %{
      chart: %{
        labels: Enum.map(bins, &format_label/1),
        rewards: Enum.map(bins, &rune_to_decimal(&1.revenue_inflows_rune || 0)),
        bonded: Enum.map(bins, &rune_to_decimal(&1.bonded_rune || 0)),
        daily_return_pct: Enum.map(bins, &calculate_daily_return_pct/1)
      },
      cumulative: %{
        ytd: ytd_revenue_sum(bins),
        ltm: ltm_revenue_sum(bins)
      }
    }
  end

  # ============================================================================
  # Section 6: Capital Flows Waterfall (90 days)
  # ============================================================================

  @doc """
  Returns capital flows chart data for last 90 days.
  Stacked bars of capital_inflows, revenue_inflows, cost_outflows.
  Plus last 10 daily flows table.
  """
  def capital_flows_90d do
    bins = fetch_treasury_bins(days_back: 90)

    %{
      chart: %{
        labels: Enum.map(bins, &format_label/1),
        capital_in: Enum.map(bins, &usd_to_decimal(d_to_float(&1.capital_inflows_usd))),
        rewards: Enum.map(bins, &usd_to_decimal(d_to_float(&1.revenue_inflows_usd))),
        costs:
          Enum.map(bins, fn bin ->
            -1 * usd_to_decimal(d_to_float(bin.cost_outflows_usd))
          end),
        net_cashflow: Enum.map(bins, &usd_to_decimal(d_to_float(&1.net_cashflow_usd)))
      },
      cost_revenue_ratio: %{
        current: calculate_cost_revenue_ratio(Enum.take(bins, -7)),
        ltm: calculate_cost_revenue_ratio(Enum.take(bins, -30))
      },
      flows_table: bins |> Enum.take(-10) |> format_flows_table()
    }
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp latest_treasury_bin do
    TreasuryBin
    |> order_by([b], desc: b.bin)
    |> limit(1)
    |> Repo.one() ||
      %TreasuryBin{
        bonded_rune: 0,
        wallet_rune: 0,
        bonded_rune_usd: D.new(0),
        wallet_rune_usd: D.new(0),
        revenue_inflows_rune: 0
      }
  end

  defp last_7_days_treasury_bins do
    {:ok, now} = DateTime.now("Etc/UTC")
    since = DateTime.add(now, -7 * 86_400, :second)

    TreasuryBin
    |> where([b], b.bin >= ^since and b.resolution == "1D")
    |> order_by([b], asc: b.bin)
    |> Repo.all()
  end

  defp ytd_revenue_inflows_usd do
    {:ok, now} = DateTime.now("Etc/UTC")
    start_of_year = %{now | month: 1, day: 1, hour: 0, minute: 0, second: 0}

    TreasuryBin
    |> where([b], b.bin >= ^start_of_year and b.resolution == "1D")
    |> select([b], coalesce(sum(b.revenue_inflows_usd), 0))
    |> Repo.one() || D.new(0)
  rescue
    _ -> D.new(0)
  end

  defp fetch_network_bins(days_back: days) do
    {:ok, now} = DateTime.now("Etc/UTC")
    since = DateTime.add(now, -days * 86_400, :second)

    NetworkBin
    |> where([b], b.bin >= ^since and b.resolution == "1D")
    |> order_by([b], asc: b.bin)
    |> Repo.all()
  end

  defp fetch_treasury_bins(days_back: days) do
    {:ok, now} = DateTime.now("Etc/UTC")
    since = DateTime.add(now, -days * 86_400, :second)

    TreasuryBin
    |> where([b], b.bin >= ^since and b.resolution == "1D")
    |> order_by([b], asc: b.bin)
    |> Repo.all()
  end

  defp network_current_values([]), do: %{tvl: 0, volume: 0, utilization: 0}

  defp network_current_values(bins) do
    latest = List.last(bins)

    %{
      tvl: usd_to_decimal(latest.tvl || 0),
      volume: usd_to_decimal(latest.volume || 0),
      utilization: d_to_float(latest.utilization_ratio)
    }
  end

  defp network_averages([]), do: %{d7: %{}, d30: %{}}

  defp network_averages(bins) do
    last_7 = Enum.take(bins, -7)
    last_30 = Enum.take(bins, -30)

    %{
      d7: calculate_network_avg(last_7),
      d30: calculate_network_avg(last_30)
    }
  end

  defp calculate_network_avg([]), do: %{tvl: 0, volume: 0, utilization: 0}

  defp calculate_network_avg(bins) do
    count = length(bins)

    %{
      tvl: usd_to_decimal(Enum.reduce(bins, 0, fn b, acc -> acc + (b.tvl || 0) end) / count),
      volume:
        usd_to_decimal(Enum.reduce(bins, 0, fn b, acc -> acc + (b.volume || 0) end) / count),
      utilization:
        Enum.reduce(bins, 0, fn b, acc ->
          acc + d_to_float(b.utilization_ratio)
        end) / count
    }
  end

  defp latest_balances_table([], _currency), do: %{wallet: "0", bonded: "0", total: "0"}

  defp latest_balances_table(bins, currency) do
    latest = List.last(bins)

    case currency do
      :rune ->
        wallet_rune = rune_to_decimal(latest.wallet_rune || 0)
        bonded_rune = rune_to_decimal(latest.bonded_rune || 0)
        total_rune = wallet_rune + bonded_rune

        %{
          wallet: Float.to_string(Float.round(wallet_rune, 2)) <> " RUNE",
          bonded: Float.to_string(Float.round(bonded_rune, 2)) <> " RUNE",
          total: Float.to_string(Float.round(total_rune, 2)) <> " RUNE"
        }

      :usd ->
        wallet_usd = usd_to_decimal(d_to_float(latest.wallet_rune_usd))
        bonded_usd = usd_to_decimal(d_to_float(latest.bonded_rune_usd))

        %{
          wallet: format_currency(trunc(wallet_usd)),
          bonded: format_currency(trunc(bonded_usd)),
          total: format_currency(trunc(wallet_usd + bonded_usd))
        }
    end
  end

  defp calculate_daily_return_pct(%{revenue_inflows_rune: rewards, bonded_rune: bonded})
       when bonded > 0 do
    # Convert RUNE base units to decimal
    rewards_rune = rune_to_decimal(rewards)
    bonded_rune = rune_to_decimal(bonded)
    rewards_rune / bonded_rune * 100
  end

  defp calculate_daily_return_pct(_), do: 0.0

  defp ytd_revenue_sum(bins) do
    {:ok, now} = DateTime.now("Etc/UTC")
    start_of_year = %{now | month: 1, day: 1, hour: 0, minute: 0, second: 0}

    bins
    |> Enum.filter(fn bin -> DateTime.compare(bin.bin, start_of_year) != :lt end)
    |> Enum.reduce(0, fn bin, acc ->
      acc + (bin.revenue_inflows_rune || 0)
    end)
    |> rune_to_decimal()
  end

  defp ltm_revenue_sum(bins) do
    bins
    |> Enum.take(-365)
    |> Enum.reduce(0, fn bin, acc ->
      acc + (bin.revenue_inflows_rune || 0)
    end)
    |> rune_to_decimal()
  end

  defp calculate_cost_revenue_ratio([]), do: "0.0%"

  defp calculate_cost_revenue_ratio(bins) do
    total_revenue =
      Enum.reduce(bins, D.new(0), fn bin, acc ->
        D.add(acc, bin.revenue_inflows_usd || D.new(0))
      end)

    total_costs =
      Enum.reduce(bins, D.new(0), fn bin, acc ->
        D.add(acc, bin.cost_outflows_usd || D.new(0))
      end)

    if D.compare(total_revenue, D.new(0)) == :gt do
      ratio = D.div(total_costs, total_revenue) |> D.mult(D.new(100)) |> D.to_float()
      format_percentage(ratio)
    else
      "0.0%"
    end
  end

  defp format_flows_table(bins) do
    Enum.map(bins, fn bin ->
      %{
        date: format_label(bin),
        capital_in: format_currency_decimal(bin.capital_inflows_usd),
        rewards: format_currency_decimal(bin.revenue_inflows_usd),
        costs: format_currency_decimal(bin.cost_outflows_usd),
        net: format_currency_decimal(bin.net_cashflow_usd)
      }
    end)
  end

  # Mocked projection chart data
  defp projection_chart_downside do
    %{
      labels: ["2025", "2026", "2027", "2028", "2029", "2030"],
      nav: [2_500_000, 3_200_000, 4_100_000, 5_200_000, 6_500_000, 8_100_000]
    }
  end

  defp projection_chart_base do
    %{
      labels: ["2025", "2026", "2027", "2028", "2029", "2030"],
      nav: [2_500_000, 3_800_000, 5_500_000, 7_800_000, 10_800_000, 14_500_000]
    }
  end

  defp projection_chart_upside do
    %{
      labels: ["2025", "2026", "2027", "2028", "2029", "2030"],
      nav: [2_500_000, 4_500_000, 7_500_000, 12_000_000, 18_500_000, 27_000_000]
    }
  end

  # Formatting helpers
  defp format_label(%{bin: %DateTime{} = dt}), do: dt |> DateTime.to_date() |> Date.to_string()

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(%D{} = num), do: format_number(D.to_integer(num))
  defp format_number(nil), do: "0"

  defp format_percentage(value) when is_number(value) do
    :erlang.float_to_binary(value, decimals: 1) <> "%"
  end

  defp format_currency(amount) when is_integer(amount) do
    "$" <> format_number(amount)
  end

  defp format_currency_decimal(%D{} = amount) do
    amount |> D.to_float() |> usd_to_decimal() |> trunc() |> format_currency()
  end

  defp format_currency_decimal(_), do: "$0"

  defp d_to_float(%D{} = val), do: D.to_float(val)
  defp d_to_float(nil), do: 0
  defp d_to_float(val) when is_number(val), do: val * 1.0

  # All blockchain amounts stored with 8 decimal places
  @decimals 100_000_000

  # Convert base units (bigint) to human-readable decimal
  defp to_decimal(base_units) when is_integer(base_units) do
    base_units / @decimals
  end

  defp to_decimal(%D{} = base_units) do
    D.to_float(base_units) / @decimals
  end

  defp to_decimal(base_units) when is_float(base_units) do
    base_units / @decimals
  end

  defp to_decimal(nil), do: 0.0
  defp to_decimal(_), do: 0.0

  # Aliases for clarity
  defp rune_to_decimal(val), do: to_decimal(val)
  defp usd_to_decimal(val), do: to_decimal(val)

  # Format RUNE amount with proper decimals
  defp format_rune(rune_base_units) when is_integer(rune_base_units) do
    rune_base_units
    |> rune_to_decimal()
    |> Float.round(2)
    |> Float.to_string()
    |> String.replace(~r/\.?0+$/, "")
  end

  defp format_rune(_), do: "0"
end
