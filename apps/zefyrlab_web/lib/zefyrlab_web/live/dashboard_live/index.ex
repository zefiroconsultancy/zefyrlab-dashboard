defmodule ZefyrlabWeb.DashboardLive.Index do
  use ZefyrlabWeb, :live_view
  import ZefyrlabWeb.DashboardComponents
  alias Zefyrlab.Dashboard

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
     |> assign(:selected_scenario, "base")
     |> assign(:currency_toggle, :usd)
     |> load_all_sections()}
  end

  @impl true
  def handle_event("change_scenario", %{"scenario" => scenario}, socket) do
    {:noreply,
     socket
     |> assign(:selected_scenario, scenario)
     |> load_projections()}
  end

  @impl true
  def handle_event("toggle_currency", %{"currency" => currency}, socket) do
    currency_atom = String.to_existing_atom(currency)

    {:noreply,
     socket
     |> assign(:currency_toggle, currency_atom)
     |> load_treasury_balances()}
  end

  @impl true
  def handle_info({:metrics_updated, _metrics}, socket) do
    {:noreply, load_all_sections(socket)}
  end

  # ============================================================================
  # Data Loading Functions
  # ============================================================================

  defp load_all_sections(socket) do
    socket
    |> load_hero_kpis()
    |> load_projections()
    |> load_network_metrics()
    |> load_treasury_balances()
    |> load_rewards()
    |> load_capital_flows()
  end

  defp load_hero_kpis(socket) do
    socket
    |> assign(:nav_usd, Dashboard.nav_usd())
    |> assign(:ytd_rewards_usd, Dashboard.ytd_rewards_usd())
    |> assign(:realized_apy, Dashboard.realized_apy())
    |> assign(:net_capital_deployed, Dashboard.net_capital_deployed_usd())
  end

  defp load_projections(socket) do
    scenario = socket.assigns.selected_scenario
    projection_data = Dashboard.projection_data(scenario)

    socket
    |> assign(:projection_chart_data, Jason.encode!(projection_data.chart))
    |> assign(:projection_fy1_income, projection_data.fy1_net_income)
    |> assign(:projection_raise_size, projection_data.raise_size)
    |> assign(:projection_raise_timing, projection_data.raise_timing)
    |> assign(:projection_money_multiple, projection_data.money_multiple)
    |> assign(:projection_irr_5y, projection_data.irr_5y)
  end

  defp load_network_metrics(socket) do
    data = Dashboard.network_metrics_90d()

    socket
    |> assign(:network_chart_data, Jason.encode!(data.chart))
    |> assign(:network_current, data.current)
    |> assign(:network_avg_7d, data.averages.d7)
    |> assign(:network_avg_30d, data.averages.d30)
  end

  defp load_treasury_balances(socket) do
    currency = socket.assigns.currency_toggle
    data = Dashboard.treasury_balances_180d(currency)

    socket
    |> assign(:balances_chart_data, Jason.encode!(data.chart))
    |> assign(:balances_table, data.table)
  end

  defp load_rewards(socket) do
    data = Dashboard.rewards_chart_90d()

    socket
    |> assign(:rewards_chart_data, Jason.encode!(data.chart))
    |> assign(:cumulative_ytd, data.cumulative.ytd)
    |> assign(:cumulative_ltm, data.cumulative.ltm)
  end

  defp load_capital_flows(socket) do
    data = Dashboard.capital_flows_90d()

    socket
    |> assign(:flows_chart_data, Jason.encode!(data.chart))
    |> assign(:cost_revenue_ratio_current, data.cost_revenue_ratio.current)
    |> assign(:cost_revenue_ratio_ltm, data.cost_revenue_ratio.ltm)
    |> assign(:flows_table, data.flows_table)
  end

  # ============================================================================
  # Template
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dashboard-container">
      <!-- Section 1: Hero Overview -->
      <section class="hero-overview">
        <.kpi_card_hero label="NAV (USD)" value={@nav_usd} />
        <.kpi_card_hero label="YTD Realized Rewards" value={@ytd_rewards_usd} />
        <.kpi_card_hero label="Realized APY" value={@realized_apy} />
        <.kpi_card_hero label="Net Capital Deployed" value={@net_capital_deployed} />
      </section>

      <!-- Section 2: Projections & Scenarios -->
      <section class="projections-section">
        <h2>Projections & Scenarios</h2>

        <.scenario_selector selected={@selected_scenario} />

        <.projection_chart data={@projection_chart_data} />

        <.projection_kpis
          fy1_income={@projection_fy1_income}
          raise_size={@projection_raise_size}
          raise_timing={@projection_raise_timing}
          money_multiple={@projection_money_multiple}
          irr_5y={@projection_irr_5y}
        />

        <p class="note">Scenarios vary only THORChain TVL growth and liquidity utilization</p>
      </section>

      <!-- Section 3: Network Metrics -->
      <section class="network-metrics">
        <h2>Network Metrics (THORChain Drivers)</h2>

        <.dual_axis_chart data={@network_chart_data} />

        <.metrics_row
          current={@network_current}
          avg_7d={@network_avg_7d}
          avg_30d={@network_avg_30d}
        />
      </section>

      <!-- Section 4: Treasury Balances Evolution -->
      <section class="treasury-balances">
        <h2>Treasury Balances Evolution (180 days)</h2>

        <.currency_toggle current={@currency_toggle} />

        <.stacked_area_chart data={@balances_chart_data} />

        <.balances_table data={@balances_table} />
      </section>

      <!-- Section 5: Realized Rewards Breakdown -->
      <section class="realized-rewards">
        <h2>Realized Rewards Breakdown</h2>

        <.rewards_vs_bonded_chart data={@rewards_chart_data} />

        <.cumulative_stats ytd={@cumulative_ytd} ltm={@cumulative_ltm} />
      </section>

      <!-- Section 6: Capital Flows Waterfall -->
      <section class="capital-flows">
        <h2>Capital Flows (90 days)</h2>

        <.stacked_bar_chart data={@flows_chart_data} />

        <.flow_metrics current={@cost_revenue_ratio_current} ltm={@cost_revenue_ratio_ltm} />

        <.flows_table data={@flows_table} />
      </section>
    </div>
    """
  end
end
