defmodule Zefyrlab.Dashboard do
  @moduledoc """
  Provides dashboard data for the web UI.

  The current implementation keeps the existing mocked dataset in one place so it can
  later be replaced with live data sources without touching the UI.
  """

  @current_metrics %{
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
  Returns dashboard headline metrics formatted for display.
  """
  def metrics do
    %{
      current_capital: format_number(@current_metrics.current_capital),
      total_bonded: format_number(@current_metrics.total_bonded),
      rewards_ytd: format_currency(@current_metrics.rewards_ytd),
      annualized_yield: format_percentage(@current_metrics.annualized_yield),
      current_valuation: format_currency(@current_metrics.current_valuation)
    }
  end

  @doc """
  Returns chart datasets keyed by the given time range.
  """
  def chart_data(time_range \\ "all_time") do
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

  @doc """
  Returns projected valuation data for the given year and scenario.
  """
  def projection(year, scenario, growth_factor \\ 1.0) do
    base_value = scenario_base(scenario)
    projected_value = round(base_value * growth_factor)

    %{
      projected_valuation: format_currency(projected_value),
      subtitle: "#{year} · #{humanize_scenario(scenario)}"
    }
  end

  defp scenario_base("upside_case"), do: 3_100_000
  defp scenario_base("conservative_case"), do: 2_100_000
  defp scenario_base(_), do: 2_500_000

  defp humanize_scenario("base_case"), do: "Base Case"
  defp humanize_scenario("upside_case"), do: "Upside"
  defp humanize_scenario("conservative_case"), do: "Conservative"
  defp humanize_scenario(_), do: "Unknown"

  defp format_currency(amount) when is_integer(amount) do
    "$#{format_number(amount)}"
  end

  defp format_percentage(value) when is_number(value) do
    :erlang.float_to_binary(value, decimals: 1) <> "%"
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
end
