defmodule ZefyrlabWeb.DashboardLive.Index do
  use ZefyrlabWeb, :live_view
  import ZefyrlabWeb.DashboardComponents

  @impl true
  def mount(_params, session, socket) do
    email = session["email"]

    # Subscribe to real-time metrics updates if connected
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zefyrlab.PubSub, "dashboard:metrics")
    end

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:current_user_email, email)
     |> assign(:selected_year, 2026)
     |> assign(:selected_scenario, "base_case")
     |> assign(:growth_factor, 1.0)
     |> assign(:time_range, "all_time")
     |> load_metrics()
     |> load_projections()}
  end

  @impl true
  def handle_event("change_year", %{"value" => year}, socket) do
    {:noreply,
     socket
     |> assign(:selected_year, String.to_integer(year))
     |> load_projections()}
  end

  @impl true
  def handle_event("change_scenario", %{"value" => scenario}, socket) do
    {:noreply,
     socket
     |> assign(:selected_scenario, scenario)
     |> load_projections()}
  end

  @impl true
  def handle_event("change_growth_factor", %{"value" => factor}, socket) do
    {:noreply,
     socket
     |> assign(:growth_factor, String.to_float(factor))
     |> load_projections()}
  end

  @impl true
  def handle_event("change_time_range", %{"value" => time_range}, socket) do
    {:noreply,
     socket
     |> assign(:time_range, time_range)
     |> assign_chart_data()}
  end

  @impl true
  def handle_info({:metrics_updated, _metrics}, socket) do
    {:noreply, load_metrics(socket)}
  end

  defp load_metrics(socket) do
    # For now, use placeholder data
    # TODO: Replace with actual Zefyrlab.Metrics.get_current_day()
    socket
    |> assign(:current_capital, "1,234,567")
    |> assign(:total_bonded, "987,654")
    |> assign(:rewards_ytd, "$123,456")
    |> assign(:annualized_yield, "12.5%")
    |> assign(:current_valuation, "$2,345,678")
    |> assign_chart_data()
  end

  defp assign_chart_data(socket) do
    # Mock chart data - TODO: Replace with actual data from Zefyrlab
    time_range = socket.assigns.time_range

    {labels, bonded_values, rewards_actual, rewards_proj, income_values, costs_values} =
      case time_range do
        "30_days" ->
          {
            ["Day 1", "Day 5", "Day 10", "Day 15", "Day 20", "Day 25", "Day 30"],
            [1_450_000, 1_460_000, 1_470_000, 1_480_000, 1_490_000, 1_495_000, 1_500_000],
            [19_500, 20_100, 20_800, 21_400, 22_000, 22_600, 23_200],
            [19_000, 20_000, 20_500, 21_000, 21_500, 22_000, 22_500],
            [190_000, 195_000, 200_000, 205_000, 210_000, 213_000, 215_100],
            [12_000, 12_500, 13_000, 13_500, 14_000, 14_500, 15_000]
          }

        "90_days" ->
          {
            ["Week 1", "Week 3", "Week 5", "Week 7", "Week 9", "Week 11", "Week 13"],
            [1_300_000, 1_350_000, 1_390_000, 1_425_000, 1_460_000, 1_480_000, 1_500_000],
            [15_300, 17_200, 18_900, 20_300, 21_800, 22_600, 23_800],
            [15_000, 17_000, 18_500, 20_000, 21_500, 22_000, 23_500],
            [160_000, 175_000, 188_000, 198_000, 206_000, 211_000, 215_100],
            [10_500, 11_500, 12_500, 13_200, 14_000, 14_700, 15_000]
          }

        "all_time" ->
          {
            ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
            [850_000, 920_000, 980_000, 1_050_000, 1_100_000, 1_180_000,
             1_250_000, 1_300_000, 1_350_000, 1_400_000, 1_450_000, 1_500_000],
            [12_500, 13_200, 14_100, 15_300, 16_200, 17_800,
             18_900, 19_500, 20_100, 21_200, 22_500, 23_800],
            [12_000, 13_000, 14_000, 15_000, 16_000, 17_500,
             18_500, 19_000, 20_000, 21_000, 22_000, 23_500],
            [12_500, 25_700, 39_800, 55_100, 71_300, 89_100,
             108_000, 127_500, 147_600, 168_800, 191_300, 215_100],
            [8_500, 9_200, 9_800, 10_500, 11_000, 11_800,
             12_500, 13_000, 13_500, 14_000, 14_500, 15_000]
          }
      end

    bonded_data = %{labels: labels, data: bonded_values}
    rewards_data = %{labels: labels, actual: rewards_actual, projected: rewards_proj}
    income_data = %{labels: labels, data: income_values}
    costs_data = %{labels: labels, data: costs_values}

    socket
    |> assign(:bonded_chart_data, Jason.encode!(bonded_data))
    |> assign(:rewards_chart_data, Jason.encode!(rewards_data))
    |> assign(:income_chart_data, Jason.encode!(income_data))
    |> assign(:costs_chart_data, Jason.encode!(costs_data))
  end

  defp load_projections(socket) do
    # For now, use placeholder data
    # TODO: Replace with actual Zefyrlab.Projections.get_by_scenario_year()
    year = socket.assigns.selected_year
    scenario = socket.assigns.selected_scenario
    factor = socket.assigns.growth_factor

    projected_value = (2_500_000 * factor) |> round() |> format_number()

    socket
    |> assign(:projected_valuation, "$#{projected_value}")
    |> assign(:projection_subtitle, "#{year} · #{format_scenario(scenario)}")
  end

  defp format_scenario("base_case"), do: "Base Case"
  defp format_scenario("upside_case"), do: "Upside"
  defp format_scenario("conservative_case"), do: "Conservative"
  defp format_scenario(_), do: "Unknown"

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <!-- KPI Strip -->
      <div class="kpi-strip">
        <.kpi_card label="Current Capital" value={@current_capital} unit="RUNE" />
        <.kpi_card label="Bonded" value={@total_bonded} unit="RUNE" />
        <.kpi_card label="Rewards YTD" value={@rewards_ytd} />
        <.kpi_card label="Annualized Yield" value={@annualized_yield} />
      </div>

      <!-- Valuation Section -->
      <div class="valuation-section">
        <div class="valuation-card">
          <h2>Current Valuation</h2>
          <.large_metric value={@current_valuation} subtitle="DCF-based, live updated" />
        </div>

        <div class="valuation-card">
          <h2>Projected Valuation</h2>

          <.button_group_selector
            label="Year"
            options={[2026, 2027, 2028, 2029, 2030]}
            selected={@selected_year}
            event="change_year"
          />

          <.button_group_selector
            label="Scenario"
            options={["base_case", "upside_case", "conservative_case"]}
            selected={@selected_scenario}
            event="change_scenario"
          />

          <div class="selector-group">
            <label>Growth Factor: <%= @growth_factor %></label>
            <input
              type="range"
              min="0.5"
              max="2.0"
              step="0.1"
              value={@growth_factor}
              phx-change="change_growth_factor"
              style="width: 100%;"
            />
          </div>

          <.large_metric value={@projected_valuation} subtitle={@projection_subtitle} />
        </div>
      </div>

      <!-- Time Range Selector -->
      <div class="time-range-selector">
        <.button_group_selector
          label="Time Range"
          options={["30_days", "90_days", "all_time"]}
          selected={@time_range}
          event="change_time_range"
        />
      </div>

      <!-- Charts Section -->
      <div class="charts-grid">
        <.chart_card title="Bonded Capital Over Time" id="chart-bonded">
          <canvas id="canvas-bonded" phx-hook="BondedChart" data-chart={@bonded_chart_data}></canvas>
        </.chart_card>

        <.chart_card title="Rewards: Actual vs Projected" id="chart-rewards">
          <canvas id="canvas-rewards" phx-hook="RewardsChart" data-chart={@rewards_chart_data}></canvas>
        </.chart_card>

        <.chart_card title="Cumulative Net Income" id="chart-income">
          <canvas id="canvas-income" phx-hook="IncomeChart" data-chart={@income_chart_data}></canvas>
        </.chart_card>

        <.chart_card title="Costs YTD" id="chart-costs">
          <canvas id="canvas-costs" phx-hook="CostsChart" data-chart={@costs_chart_data}></canvas>
        </.chart_card>
      </div>
    </div>
    """
  end
end
