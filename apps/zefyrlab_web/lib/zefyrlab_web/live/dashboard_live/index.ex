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
     |> assign(:selected_year, 2026)
     |> assign(:selected_scenario, "base_case")
     |> assign(:growth_factor, 1.0)
     |> assign(:time_range, "all_time")
     |> load_metrics()
     |> load_projections()}
  end

  @impl true
  def handle_event("change_year", %{"selected" => year}, socket) do
    case safe_integer(year) do
      nil ->
        {:noreply, socket}

      parsed_year ->
        {:noreply,
         socket
         |> assign(:selected_year, parsed_year)
         |> load_projections()}
    end
  end

  @impl true
  def handle_event("change_scenario", %{"selected" => scenario}, socket) do
    if scenario == "" do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:selected_scenario, scenario)
       |> load_projections()}
    end
  end

  @impl true
  def handle_event("change_growth_factor", %{"selected" => factor}, socket) do
    parsed = safe_float(factor) || socket.assigns.growth_factor

    {:noreply,
     socket
     |> assign(:growth_factor, parsed)
     |> load_projections()}
  end

  @impl true
  def handle_event(
        "change_growth_factor",
        %{"projection" => %{"growth_factor" => factor}},
        socket
      ) do
    parsed = safe_float(factor) || socket.assigns.growth_factor

    {:noreply,
     socket
     |> assign(:growth_factor, parsed)
     |> load_projections()}
  end

  @impl true
  def handle_event("change_growth_factor", %{"value" => factor}, socket) do
    parsed = safe_float(factor) || socket.assigns.growth_factor

    {:noreply,
     socket
     |> assign(:growth_factor, parsed)
     |> load_projections()}
  end

  @impl true
  def handle_event("change_time_range", %{"selected" => time_range}, socket) do
    effective_range = if time_range == "" or is_nil(time_range), do: "all_time", else: time_range

    {:noreply,
     socket
     |> assign(:time_range, effective_range)
     |> assign_chart_data()}
  end

  @impl true
  def handle_info({:metrics_updated, _metrics}, socket) do
    {:noreply, load_metrics(socket)}
  end

  defp load_metrics(socket) do
    metrics = Dashboard.metrics()

    socket
    |> assign(:current_capital, metrics.current_capital)
    |> assign(:total_bonded, metrics.total_bonded)
    |> assign(:rewards_ytd, metrics.rewards_ytd)
    |> assign(:annualized_yield, metrics.annualized_yield)
    |> assign(:current_valuation, metrics.current_valuation)
    |> assign_chart_data()
  end

  defp assign_chart_data(socket) do
    chart_data = Dashboard.chart_data(socket.assigns.time_range)

    socket
    |> assign(:bonded_chart_data, Jason.encode!(chart_data.bonded))
    |> assign(:rewards_chart_data, Jason.encode!(chart_data.rewards))
    |> assign(:income_chart_data, Jason.encode!(chart_data.income))
    |> assign(:costs_chart_data, Jason.encode!(chart_data.costs))
  end

  defp load_projections(socket) do
    %{projected_valuation: projected_value, subtitle: subtitle} =
      Dashboard.projection(
        socket.assigns.selected_year,
        socket.assigns.selected_scenario,
        socket.assigns.growth_factor
      )

    socket
    |> assign(:projected_valuation, projected_value)
    |> assign(:projection_subtitle, subtitle)
  end

  defp safe_integer(""), do: nil
  defp safe_integer(nil), do: nil

  defp safe_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _} -> parsed
      :error -> nil
    end
  end

  defp safe_float(""), do: nil
  defp safe_float(nil), do: nil

  defp safe_float(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> nil
    end
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
            <label>Growth Factor: <%= :erlang.float_to_binary(@growth_factor, decimals: 1) %></label>

            <.form for={%{growth_factor: @growth_factor}} as={:projection} phx-change="change_growth_factor">
              <input
                type="range"
                min="0.5"
                max="2.0"
                step="0.1"
                value={@growth_factor}
                name="projection[growth_factor]"
                phx-debounce="0"
                style="width: 100%;"
              />
            </.form>
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
          <canvas
            id="canvas-bonded"
            class="w-full h-80 md:h-96"
            phx-hook="BondedChart"
            data-chart={@bonded_chart_data}
          ></canvas>
        </.chart_card>

        <.chart_card title="Rewards: Actual vs Projected" id="chart-rewards">
          <canvas
            id="canvas-rewards"
            class="w-full h-80 md:h-96"
            phx-hook="RewardsChart"
            data-chart={@rewards_chart_data}
          ></canvas>
        </.chart_card>

        <.chart_card title="Cumulative Net Income" id="chart-income">
          <canvas
            id="canvas-income"
            class="w-full h-80 md:h-96"
            phx-hook="IncomeChart"
            data-chart={@income_chart_data}
          ></canvas>
        </.chart_card>

        <.chart_card title="Costs YTD" id="chart-costs">
          <canvas
            id="canvas-costs"
            class="w-full h-80 md:h-96"
            phx-hook="CostsChart"
            data-chart={@costs_chart_data}
          ></canvas>
        </.chart_card>
      </div>
    </div>
    """
  end
end
