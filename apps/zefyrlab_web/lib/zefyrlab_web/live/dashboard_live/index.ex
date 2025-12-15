defmodule ZefyrlabWeb.DashboardLive.Index do
  use ZefyrlabWeb, :live_view

  # Import new modular dashboard components
  import ZefyrlabWeb.Components.Dashboard.ChartComponent
  import ZefyrlabWeb.Components.Dashboard.ToggleComponent
  import ZefyrlabWeb.Components.Dashboard.MetricGrid
  import ZefyrlabWeb.Components.Dashboard.KpiComponents
  import ZefyrlabWeb.Components.Dashboard.TableComponents

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
  def handle_event("change_scenario", %{"selected" => scenario}, socket) do
    {:noreply,
     socket
     |> assign(:selected_scenario, scenario)
     |> load_projections()}
  end

  @impl true
  def handle_event("toggle_currency", %{"selected" => currency}, socket) do
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

        <.toggle_group
          options={[
            %{value: "downside", label: "Downside"},
            %{value: "base", label: "Base"},
            %{value: "upside", label: "Upside"}
          ]}
          selected={@selected_scenario}
          event="change_scenario"
          container_class="scenario-selector"
        />

        <.chart
          id="projection-chart"
          hook="ProjectionChart"
          data={@projection_chart_data}
          container_class="projection-chart-container"
          canvas_class="projection-chart"
        />

        <.metric_grid
          metrics={[
            %{label: "FY1 Net Income", value: @projection_fy1_income},
            %{label: "Next Raise Size", value: @projection_raise_size},
            %{label: "Next Raise Timing", value: @projection_raise_timing},
            %{label: "5Y Money Multiple", value: @projection_money_multiple},
            %{label: "5Y IRR", value: @projection_irr_5y}
          ]}
          layout={:rows}
          container_class="projection-kpis"
        />

        <p class="note">Scenarios vary only THORChain TVL growth and liquidity utilization</p>
      </section>

      <!-- Section 3: Network Metrics -->
      <section class="network-metrics">
        <h2>Network Metrics (THORChain Drivers)</h2>

        <.chart
          id="network-chart"
          hook="DualAxisChart"
          data={@network_chart_data}
          container_class="dual-axis-chart-container"
          canvas_class="dual-axis-chart"
        />

        <.metric_grid
          metrics={[
            %{label: "TVL (Current)", value: @network_current.tvl},
            %{label: "TVL (7d avg)", value: @network_avg_7d.tvl},
            %{label: "TVL (30d avg)", value: @network_avg_30d.tvl},
            %{label: "Volume (Current)", value: @network_current.volume},
            %{label: "Utilization (Current)", value: @network_current.utilization},
            %{label: "Utilization (30d avg)", value: @network_avg_30d.utilization}
          ]}
          layout={:columns}
          container_class="metrics-row"
        />
      </section>

      <!-- Section 4: Treasury Balances Evolution -->
      <section class="treasury-balances">
        <h2>Treasury Balances Evolution (180 days)</h2>

        <.toggle_group
          options={[
            %{value: "usd", label: "USD"},
            %{value: "rune", label: "RUNE"}
          ]}
          selected={@currency_toggle}
          event="toggle_currency"
          container_class="currency-toggle"
        />

        <.chart
          id="balances-chart"
          hook="StackedAreaChart"
          data={@balances_chart_data}
          container_class="stacked-area-chart-container"
          canvas_class="stacked-area-chart"
        />

        <.balances_table data={@balances_table} />
      </section>

      <!-- Section 5: Realized Rewards Breakdown -->
      <section class="realized-rewards">
        <h2>Realized Rewards Breakdown</h2>

        <.chart
          id="rewards-chart"
          hook="RewardsBondedChart"
          data={@rewards_chart_data}
          container_class="rewards-bonded-chart-container"
          canvas_class="rewards-bonded-chart"
        />

        <.metric_grid
          metrics={[
            %{label: "Cumulative YTD", value: "#{@cumulative_ytd} RUNE"},
            %{label: "Cumulative LTM", value: "#{@cumulative_ltm} RUNE"}
          ]}
          layout={:columns}
          container_class="cumulative-stats"
        />
      </section>

      <!-- Section 6: Capital Flows Waterfall -->
      <section class="capital-flows">
        <h2>Capital Flows (90 days)</h2>

        <.chart
          id="flows-chart"
          hook="StackedBarChart"
          data={@flows_chart_data}
          container_class="stacked-bar-chart-container"
          canvas_class="stacked-bar-chart"
        />

        <.metric_grid
          metrics={[
            %{label: "Cost/Revenue Ratio (Latest)", value: @cost_revenue_ratio_current},
            %{label: "Cost/Revenue Ratio (LTM)", value: @cost_revenue_ratio_ltm}
          ]}
          layout={:columns}
          container_class="flow-metrics"
        />

        <.flows_table data={@flows_table} />
      </section>
    </div>
    """
  end
end
