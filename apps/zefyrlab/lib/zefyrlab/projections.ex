defmodule Zefyrlab.Projections do
  @moduledoc """
  Calculates financial projections dynamically from current metrics.

  Provides 3 volume growth scenarios:
  - Base case: 300% volume increase
  - Upside case: 500% volume increase
  - Downside case: 100% volume increase

  All scenarios assume stable utilization ratio.
  """

  import Ecto.Query
  alias Zefyrlab.Repo
  alias Zefyrlab.Treasury.Bin, as: TreasuryBin
  alias Zefyrlab.NetworkMetrics.Bin, as: NetworkBin
  alias Decimal, as: D

  @decimals 100_000_000

  @doc """
  Calculate 5-year projections for a given scenario.
  Returns list of maps with year and projection metrics.
  """
  def calculate_scenario(scenario) do
    # Get current metrics from latest bins
    current = get_current_metrics()

    # Get volume growth multiplier for scenario
    multiplier = volume_growth_multiplier(scenario)

    # Calculate 5-year projections (2026-2030)
    years = [2026, 2027, 2028, 2029, 2030]

    projections =
      Enum.with_index(years, 1)
      |> Enum.map(fn {year, year_index} ->
        calculate_year_projection(year, year_index, current, multiplier)
      end)

    # Calculate IRR and money multiple across all years
    cash_flows = Enum.map(projections, & &1.projected_net_income)
    initial_investment = current.bonded_capital_usd
    final_valuation = List.last(projections).projected_valuation

    money_multiple = calculate_multiple(initial_investment, final_valuation)
    irr = calculate_irr([initial_investment | cash_flows])

    # Add money_multiple and irr to each year's projection
    Enum.map(projections, fn proj ->
      Map.merge(proj, %{money_multiple: money_multiple, irr_5y: irr})
    end)
  end

  # ----------------
  # Current Metrics
  # ----------------

  defp get_current_metrics do
    # Query latest 1D bins from both tables
    treasury =
      from(b in TreasuryBin,
        where: b.resolution == "1D",
        order_by: [desc: b.bin],
        limit: 1
      )
      |> Repo.one()

    network =
      from(b in NetworkBin,
        where: b.resolution == "1D",
        order_by: [desc: b.bin],
        limit: 1
      )
      |> Repo.one()

    # Query YTD data (sum all 1D bins from start of current year)
    current_year = DateTime.utc_now().year
    year_start = DateTime.new!(Date.new!(current_year, 1, 1), ~T[00:00:00])

    ytd_treasury =
      from(b in TreasuryBin,
        where: b.resolution == "1D" and b.bin >= ^year_start,
        select: %{
          total_revenue_rune: sum(b.revenue_inflows_rune)
        }
      )
      |> Repo.one()

    ytd_network =
      from(b in NetworkBin,
        where: b.resolution == "1D" and b.bin >= ^year_start,
        select: %{
          total_volume: sum(b.volume)
        }
      )
      |> Repo.one()

    # Fallback to zeros if no data
    if is_nil(treasury) or is_nil(network) do
      %{
        bonded_capital_rune: 0,
        bonded_capital_usd: 0.0,
        ytd_revenue_rune: 0,
        ytd_revenue_usd: 0.0,
        ytd_volume_usd: 0.0,
        current_volume_usd: 0.0,
        utilization_ratio: 0.0,
        annualized_revenue_usd: 0.0,
        rune_price: 0.0,
        days_elapsed: 1
      }
    else
      bonded_capital_rune = treasury.bonded_rune || 0
      rune_price = D.to_float(treasury.rune_usd_price || D.new(0))

      # YTD metrics
      ytd_revenue_rune = ytd_treasury.total_revenue_rune || 0
      ytd_volume = ytd_network.total_volume || 0

      # Convert to human-readable decimals
      bonded_capital_usd = to_decimal(bonded_capital_rune) * rune_price
      ytd_revenue_usd = to_decimal(ytd_revenue_rune) * rune_price
      ytd_volume_usd = to_decimal(ytd_volume)
      current_volume_usd = to_decimal(network.volume || 0)

      utilization_ratio = D.to_float(network.utilization_ratio || D.new(0))

      # Calculate days elapsed in current year
      days_elapsed = Date.diff(Date.utc_today(), Date.new!(current_year, 1, 1))
      days_elapsed = max(1, days_elapsed)  # Avoid division by zero

      # Annualize YTD revenue
      annualized_revenue_usd = ytd_revenue_usd * (365.0 / days_elapsed)

      %{
        bonded_capital_rune: bonded_capital_rune,
        bonded_capital_usd: bonded_capital_usd,
        ytd_revenue_rune: ytd_revenue_rune,
        ytd_revenue_usd: ytd_revenue_usd,
        ytd_volume_usd: ytd_volume_usd,
        current_volume_usd: current_volume_usd,
        utilization_ratio: utilization_ratio,
        annualized_revenue_usd: annualized_revenue_usd,
        rune_price: rune_price,
        days_elapsed: days_elapsed
      }
    end
  end

  # ----------------
  # Projection Logic
  # ----------------

  defp calculate_year_projection(year, year_index, current, volume_multiplier) do
    # Calculate the revenue-to-volume ratio from current YTD data
    # This tells us: for every $1 of volume, we earn $X in revenue
    revenue_per_volume_ratio =
      if current.ytd_volume_usd > 0 do
        current.ytd_revenue_usd / current.ytd_volume_usd
      else
        0.0
      end

    # Project volume growth for this year
    # Year 1: base volume × multiplier
    # Year 2: base volume × multiplier × multiplier (compounding)
    # etc.
    projected_volume = current.ytd_volume_usd * :math.pow(volume_multiplier, year_index)

    # Since utilization stays constant, and revenue is proportional to volume processed:
    # Projected revenue = projected_volume × revenue_per_volume_ratio
    # OR equivalently: current_annualized_revenue × volume_growth_factor
    projected_annual_revenue = current.annualized_revenue_usd * :math.pow(volume_multiplier, year_index)

    # Alternative calculation (should be same):
    # projected_annual_revenue = projected_volume × revenue_per_volume_ratio

    # Cumulative earnings over years (sum of all previous years' revenue)
    cumulative_earnings =
      Enum.reduce(1..year_index, 0.0, fn idx, acc ->
        year_revenue = current.annualized_revenue_usd * :math.pow(volume_multiplier, idx)
        acc + year_revenue
      end)

    # Projected capital = initial capital + cumulative earnings
    projected_capital = current.bonded_capital_usd + cumulative_earnings

    # Projected valuation (NAV) = current capital + future discounted cash flows
    # Simple approach: use capital as NAV
    projected_valuation = projected_capital

    %{
      year: year,
      projected_volume: projected_volume,
      projected_net_income: projected_annual_revenue,
      projected_capital: projected_capital,
      projected_valuation: projected_valuation,
      revenue_per_volume_ratio: revenue_per_volume_ratio
    }
  end

  # ----------------
  # Scenario Multipliers
  # ----------------

  defp volume_growth_multiplier(:base_case), do: 4.0 # 300% increase = 4x total (100% + 300%)
  defp volume_growth_multiplier(:upside_case), do: 6.0 # 500% increase = 6x total (100% + 500%)
  defp volume_growth_multiplier(:conservative_case), do: 2.0 # 100% increase = 2x total (100% + 100%)

  # ----------------
  # Financial Calculations
  # ----------------

  defp calculate_multiple(initial_investment, final_valuation) do
    if initial_investment > 0 do
      final_valuation / initial_investment
    else
      0.0
    end
  end

  defp calculate_irr(cash_flows) do
    # Simplified IRR calculation using Newton-Raphson method
    # For now, return a placeholder (proper IRR needs iterative calculation)
    # TODO: Implement full IRR calculation
    calculate_simple_irr(cash_flows)
  end

  defp calculate_simple_irr([initial | future_flows]) do
    # Simple approximation: average annual return
    total_return = Enum.sum(future_flows)
    years = length(future_flows)

    if initial > 0 and years > 0 do
      avg_annual_return = total_return / years
      (avg_annual_return / abs(initial)) * 100
    else
      0.0
    end
  end

  # ----------------
  # Helpers
  # ----------------

  defp to_decimal(base_units) when is_integer(base_units) do
    base_units / @decimals
  end

  defp to_decimal(%D{} = base_units) do
    D.to_float(base_units) / @decimals
  end

  defp to_decimal(base_units) when is_float(base_units) do
    base_units / @decimals
  end

  defp to_decimal(_), do: 0.0
end
