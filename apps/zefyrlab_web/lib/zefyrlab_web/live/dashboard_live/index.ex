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

      <!-- Charts Section (Placeholder) -->
      <div class="charts-grid">
        <.chart_card title="Bonded Capital Over Time" id="chart-bonded">
          <p class="text-muted">Chart placeholder - Chart.js integration pending</p>
        </.chart_card>

        <.chart_card title="Rewards: Actual vs Projected" id="chart-rewards">
          <p class="text-muted">Chart placeholder - Chart.js integration pending</p>
        </.chart_card>

        <.chart_card title="Cumulative Net Income" id="chart-income">
          <p class="text-muted">Chart placeholder - Chart.js integration pending</p>
        </.chart_card>
      </div>
    </div>
    """
  end
end
