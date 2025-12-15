defmodule Zefyrlab.Dashboard do
  @moduledoc """
  Provides dashboard data for the web UI based on indexed metrics.
  """

  import Ecto.Query

  alias Zefyrlab.NetworkMetrics.Bin, as: NetworkBin
  alias Zefyrlab.Treasury.Bin, as: TreasuryBin
  alias Zefyrlab.Repo

  @mock_metrics %{
    current_capital: 1_234_567,
    total_bonded: 987_654,
    rewards_ytd: 123_456,
    annualized_yield: 12.5,
    current_valuation: 2_345_678
  }

  @chart_data_by_range %{
    "30_days" => {
      ["Day 1", "Day 5", "Day 10", "Day 15", "Day 20", "Day 25", "Day 30"],
      [1_450_000, 1_460_000, 1_470_000, 1_480_000, 1_490_000, 1_495_000, 1_500_000],
      [19_500, 20_100, 20_800, 21_400, 22_000, 22_600, 23_200],
      [19_000, 20_000, 20_500, 21_000, 21_500, 22_000, 22_500],
      [190_000, 195_000, 200_000, 205_000, 210_000, 213_000, 215_100],
      [12_000, 12_500, 13_000, 13_500, 14_000, 14_500, 15_000]
    },
    "90_days" => {
      ["Week 1", "Week 3", "Week 5", "Week 7", "Week 9", "Week 11", "Week 13"],
      [1_300_000, 1_350_000, 1_390_000, 1_425_000, 1_460_000, 1_480_000, 1_500_000],
      [15_300, 17_200, 18_900, 20_300, 21_800, 22_600, 23_800],
      [15_000, 17_000, 18_500, 20_000, 21_500, 22_000, 23_500],
      [160_000, 175_000, 188_000, 198_000, 206_000, 211_000, 215_100],
      [10_500, 11_500, 12_500, 13_200, 14_000, 14_700, 15_000]
    },
    "all_time" => {
      ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
      [
        850_000,
        920_000,
        980_000,
        1_050_000,
        1_100_000,
        1_180_000,
        1_250_000,
        1_300_000,
        1_350_000,
        1_400_000,
        1_450_000,
        1_500_000
      ],
      [
        12_500,
        13_200,
        14_100,
        15_300,
        16_200,
        17_800,
        18_900,
        19_500,
        20_100,
        21_200,
        22_500,
        23_800
      ],
      [
        12_000,
        13_000,
        14_000,
        15_000,
        16_000,
        17_500,
        18_500,
        19_000,
        20_000,
        21_000,
        22_000,
        23_500
      ],
      [
        12_500,
        25_700,
        39_800,
        55_100,
        71_300,
        89_100,
        108_000,
        127_500,
        147_600,
        168_800,
        191_300,
        215_100
      ],
      [
        8_500,
        9_200,
        9_800,
        10_500,
        11_000,
        11_800,
        12_500,
        13_000,
        13_500,
        14_000,
        14_500,
        15_000
      ]
    }
  }

  @doc """
  Returns headline metrics: current capital, bonded, and rewards YTD.
  """
  def metrics do
    latest = latest_treasury_bin()
    ytd_rewards = ytd_revenue_inflows()

    metrics = %{
      current_capital: choose_value(to_int(latest.total_rune), @mock_metrics.current_capital),
      total_bonded: choose_value(to_int(latest.bonded_rune), @mock_metrics.total_bonded),
      rewards_ytd: choose_value(to_int(ytd_rewards), @mock_metrics.rewards_ytd),
      annualized_yield: @mock_metrics.annualized_yield,
      current_valuation: @mock_metrics.current_valuation
    }

    format_metrics(metrics)
  end

  @doc """
  Chart datasets:
    - volume_tvl: volume bars, tvl bars, utilization ratio line
    - cashflow: revenue (positive) and costs (negative)
  """
  def chart_data(time_range \\ "all_time") do
    bins = chart_bins(time_range)
    treasury_bins = treasury_bins(time_range)
    mock = mock_chart_data(time_range)

    %{
      volume_tvl: build_volume_tvl_chart(bins),
      cashflow: build_cashflow_chart(treasury_bins),
      table_rows:
        bins
        |> Enum.take(-7)
        |> Enum.map(
          &%{
            bin: &1.bin,
            volume: &1.volume || 0,
            tvl: &1.tvl || 0,
            utilization_ratio: &1.utilization_ratio || Decimal.new(0)
          }
        ),
      bonded: mock.bonded,
      rewards: mock.rewards,
      income: mock.income,
      costs: mock.costs
    }
  end

  def projection(year, scenario, growth_factor \\ 1.0) do
    # Keep projection mocked for now
    projected_value = round(2_500_000 * growth_factor)

    %{
      projected_valuation: format_number(projected_value),
      subtitle: "#{year} · #{scenario}"
    }
  end

  defp latest_treasury_bin do
    TreasuryBin
    |> order_by([b], desc: b.bin)
    |> limit(1)
    |> Repo.one() ||
      %TreasuryBin{
        bonded_rune: 0,
        wallet_rune: 0,
        total_rune: 0,
        revenue_inflows_rune: 0,
        cost_outflows_rune: 0
      }
  end

  defp ytd_revenue_inflows do
    {:ok, now} = DateTime.now("Etc/UTC")
    start_of_year = %{now | month: 1, day: 1, hour: 0, minute: 0, second: 0}

    TreasuryBin
    |> where([b], b.bin >= ^start_of_year and b.resolution == "1D")
    |> select([b], coalesce(sum(b.revenue_inflows_rune), 0))
    |> Repo.one()
  rescue
    _ -> 0
  end

  defp chart_bins("30_days"), do: fetch_network_bins(days_back: 30)
  defp chart_bins("90_days"), do: fetch_network_bins(days_back: 90)
  defp chart_bins(_), do: fetch_network_bins(days_back: 180)

  defp fetch_network_bins(days_back: days) do
    {:ok, now} = DateTime.now("Etc/UTC")
    since = DateTime.add(now, -days * 86_400, :second)

    NetworkBin
    |> where([b], b.bin >= ^since and b.resolution == "1D")
    |> order_by([b], asc: b.bin)
    |> Repo.all()
  end

  defp treasury_bins("30_days"), do: fetch_treasury_bins(days_back: 30)
  defp treasury_bins("90_days"), do: fetch_treasury_bins(days_back: 90)
  defp treasury_bins(_), do: fetch_treasury_bins(days_back: 180)

  defp fetch_treasury_bins(days_back: days) do
    {:ok, now} = DateTime.now("Etc/UTC")
    since = DateTime.add(now, -days * 86_400, :second)

    TreasuryBin
    |> where([b], b.bin >= ^since and b.resolution == "1D")
    |> order_by([b], asc: b.bin)
    |> Repo.all()
  end

  defp build_volume_tvl_chart(bins) do
    labels = Enum.map(bins, &format_label/1)
    volume = Enum.map(bins, &(&1.volume || 0))
    tvl = Enum.map(bins, &(&1.tvl || 0))
    utilization = Enum.map(bins, &Decimal.to_float(&1.utilization_ratio || Decimal.new(0)))

    %{labels: labels, volume: volume, tvl: tvl, utilization: utilization}
  end

  defp build_cashflow_chart(bins) do
    labels = Enum.map(bins, &format_label/1)
    revenue = Enum.map(bins, &(&1.revenue_inflows_rune || 0))
    costs = Enum.map(bins, &negate(&1.cost_outflows_rune || 0))

    %{labels: labels, revenue: revenue, costs: costs}
  end

  defp mock_chart_data(time_range) do
    ranges = @chart_data_by_range

    {labels, bonded_values, rewards_actual, rewards_proj, income_values, costs_values} =
      Map.get(ranges, time_range, ranges["all_time"])

    %{
      bonded: %{labels: labels, data: bonded_values},
      rewards: %{labels: labels, actual: rewards_actual, projected: rewards_proj},
      income: %{labels: labels, data: income_values},
      costs: %{labels: labels, data: costs_values}
    }
  end

  defp format_label(%{bin: %DateTime{} = dt}), do: dt |> DateTime.to_date() |> Date.to_string()

  defp negate(value), do: -value

  defp format_metrics(%{} = metrics) do
    %{
      current_capital: format_number(metrics.current_capital),
      total_bonded: format_number(metrics.total_bonded),
      rewards_ytd: format_number(metrics.rewards_ytd),
      annualized_yield: format_percentage(metrics.annualized_yield),
      current_valuation: format_currency(metrics.current_valuation)
    }
  end

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(%Decimal{} = num), do: format_number(Decimal.to_integer(num))
  defp format_number(nil), do: format_number(0)

  defp to_int(%Decimal{} = val), do: Decimal.to_integer(val)
  defp to_int(val) when is_integer(val), do: val
  defp to_int(_), do: 0

  defp format_percentage(value) when is_number(value) do
    :erlang.float_to_binary(value, decimals: 1) <> "%"
  end

  defp format_currency(amount) when is_integer(amount) do
    "$" <> format_number(amount)
  end

  defp format_currency(%Decimal{} = amount), do: format_currency(Decimal.to_integer(amount))

  defp choose_value(0, fallback), do: fallback
  defp choose_value(val, _fallback) when is_number(val), do: val
  defp choose_value(_, fallback), do: fallback
end
