defmodule ZefyrlabWeb.DashboardComponents do
  use Phoenix.Component

  # ============================================================================
  # Section 1: Hero Overview Components
  # ============================================================================

  @doc """
  Renders a hero KPI card (larger, for main dashboard KPIs).

  ## Examples

      <.kpi_card_hero label="NAV (USD)" value="$2,345,678" />
      <.kpi_card_hero label="Realized APY" value="12.5" unit="%" />
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :unit, :string, default: nil

  def kpi_card_hero(assigns) do
    ~H"""
    <div class="kpi-card-hero">
      <div class="kpi-label"><%= @label %></div>
      <div class="kpi-value">
        <%= @value %>
        <span :if={@unit} class="kpi-unit"><%= @unit %></span>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Section 2: Projections & Scenarios Components
  # ============================================================================

  @doc """
  Renders a scenario selector (3 buttons: Downside, Base, Upside).

  ## Examples

      <.scenario_selector selected="base" />
  """
  attr :selected, :string, required: true

  def scenario_selector(assigns) do
    ~H"""
    <div class="scenario-selector">
      <button
        type="button"
        phx-click="change_scenario"
        phx-value-scenario="downside"
        class={if @selected == "downside", do: "active", else: ""}
      >
        Downside
      </button>
      <button
        type="button"
        phx-click="change_scenario"
        phx-value-scenario="base"
        class={if @selected == "base", do: "active", else: ""}
      >
        Base
      </button>
      <button
        type="button"
        phx-click="change_scenario"
        phx-value-scenario="upside"
        class={if @selected == "upside", do: "active", else: ""}
      >
        Upside
      </button>
    </div>
    """
  end

  @doc """
  Renders a projection chart container.

  ## Examples

      <.projection_chart data={@projection_chart_data} />
  """
  attr :data, :string, required: true

  def projection_chart(assigns) do
    ~H"""
    <div class="projection-chart-container">
      <canvas
        id="projection-chart"
        phx-hook="ProjectionChart"
        data-chart={@data}
        class="projection-chart"
      ></canvas>
    </div>
    """
  end

  @doc """
  Renders projection KPIs table.

  ## Examples

      <.projection_kpis
        fy1_income="$1.2M"
        raise_size="$3.5M"
        raise_timing="Q2 2026"
        money_multiple="3.2x"
        irr_5y="26.4%"
      />
  """
  attr :fy1_income, :string, required: true
  attr :raise_size, :string, required: true
  attr :raise_timing, :string, required: true
  attr :money_multiple, :string, required: true
  attr :irr_5y, :string, required: true

  def projection_kpis(assigns) do
    ~H"""
    <div class="projection-kpis">
      <div class="kpi-row">
        <span class="kpi-label">FY1 Net Income</span>
        <span class="kpi-value"><%= @fy1_income %></span>
      </div>
      <div class="kpi-row">
        <span class="kpi-label">Next Raise Size</span>
        <span class="kpi-value"><%= @raise_size %></span>
      </div>
      <div class="kpi-row">
        <span class="kpi-label">Next Raise Timing</span>
        <span class="kpi-value"><%= @raise_timing %></span>
      </div>
      <div class="kpi-row">
        <span class="kpi-label">5Y Money Multiple</span>
        <span class="kpi-value"><%= @money_multiple %></span>
      </div>
      <div class="kpi-row">
        <span class="kpi-label">5Y IRR</span>
        <span class="kpi-value"><%= @irr_5y %></span>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Section 3: Network Metrics Components
  # ============================================================================

  @doc """
  Renders a dual-axis chart (TVL line + Volume bars).

  ## Examples

      <.dual_axis_chart data={@network_chart_data} />
  """
  attr :data, :string, required: true

  def dual_axis_chart(assigns) do
    ~H"""
    <div class="dual-axis-chart-container">
      <canvas
        id="network-chart"
        phx-hook="DualAxisChart"
        data-chart={@data}
        class="dual-axis-chart"
      ></canvas>
    </div>
    """
  end

  @doc """
  Renders current values and averages row.

  ## Examples

      <.metrics_row current={%{tvl: 1_000_000}} avg_7d={%{tvl: 950_000}} avg_30d={%{tvl: 900_000}} />
  """
  attr :current, :map, required: true
  attr :avg_7d, :map, required: true
  attr :avg_30d, :map, required: true

  def metrics_row(assigns) do
    ~H"""
    <div class="metrics-row">
      <div class="metric-col">
        <span class="metric-label">TVL (Current)</span>
        <span class="metric-value"><%= format_large_number(@current.tvl) %></span>
      </div>
      <div class="metric-col">
        <span class="metric-label">TVL (7d avg)</span>
        <span class="metric-value"><%= format_large_number(@avg_7d.tvl) %></span>
      </div>
      <div class="metric-col">
        <span class="metric-label">TVL (30d avg)</span>
        <span class="metric-value"><%= format_large_number(@avg_30d.tvl) %></span>
      </div>
      <div class="metric-col">
        <span class="metric-label">Volume (Current)</span>
        <span class="metric-value"><%= format_large_number(@current.volume) %></span>
      </div>
      <div class="metric-col">
        <span class="metric-label">Utilization (Current)</span>
        <span class="metric-value"><%= format_percentage(@current.utilization) %></span>
      </div>
      <div class="metric-col">
        <span class="metric-label">Utilization (30d avg)</span>
        <span class="metric-value"><%= format_percentage(@avg_30d.utilization) %></span>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Section 4: Treasury Balances Components
  # ============================================================================

  @doc """
  Renders a currency toggle (USD | RUNE).

  ## Examples

      <.currency_toggle current={:usd} />
  """
  attr :current, :atom, required: true

  def currency_toggle(assigns) do
    ~H"""
    <div class="currency-toggle">
      <button
        type="button"
        phx-click="toggle_currency"
        phx-value-currency="usd"
        class={if @current == :usd, do: "active", else: ""}
      >
        USD
      </button>
      <button
        type="button"
        phx-click="toggle_currency"
        phx-value-currency="rune"
        class={if @current == :rune, do: "active", else: ""}
      >
        RUNE
      </button>
    </div>
    """
  end

  @doc """
  Renders a stacked area chart (Wallet + Bonded + Cashflow line).

  ## Examples

      <.stacked_area_chart data={@balances_chart_data} />
  """
  attr :data, :string, required: true

  def stacked_area_chart(assigns) do
    ~H"""
    <div class="stacked-area-chart-container">
      <canvas
        id="balances-chart"
        phx-hook="StackedAreaChart"
        data-chart={@data}
        class="stacked-area-chart"
      ></canvas>
    </div>
    """
  end

  @doc """
  Renders latest balances table.

  ## Examples

      <.balances_table data={%{wallet: "$1.2M", bonded: "$2.3M", total: "$3.5M"}} />
  """
  attr :data, :map, required: true

  def balances_table(assigns) do
    ~H"""
    <div class="balances-table">
      <div class="balance-row">
        <span class="label">Wallet</span>
        <span class="value"><%= @data.wallet %></span>
      </div>
      <div class="balance-row">
        <span class="label">Bonded</span>
        <span class="value"><%= @data.bonded %></span>
      </div>
      <div class="balance-row total">
        <span class="label">Total</span>
        <span class="value"><%= @data.total %></span>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Section 5: Realized Rewards Components
  # ============================================================================

  @doc """
  Renders rewards vs bonded chart (bars + line + secondary axis).

  ## Examples

      <.rewards_vs_bonded_chart data={@rewards_chart_data} />
  """
  attr :data, :string, required: true

  def rewards_vs_bonded_chart(assigns) do
    ~H"""
    <div class="rewards-bonded-chart-container">
      <canvas
        id="rewards-chart"
        phx-hook="RewardsBondedChart"
        data-chart={@data}
        class="rewards-bonded-chart"
      ></canvas>
    </div>
    """
  end

  @doc """
  Renders cumulative rewards stats (YTD and LTM).

  ## Examples

      <.cumulative_stats ytd={123_456} ltm={456_789} />
  """
  attr :ytd, :integer, required: true
  attr :ltm, :integer, required: true

  def cumulative_stats(assigns) do
    ~H"""
    <div class="cumulative-stats">
      <div class="stat-col">
        <span class="stat-label">Cumulative YTD</span>
        <span class="stat-value"><%= format_rune(@ytd) %> RUNE</span>
      </div>
      <div class="stat-col">
        <span class="stat-label">Cumulative LTM</span>
        <span class="stat-value"><%= format_rune(@ltm) %> RUNE</span>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Section 6: Capital Flows Components
  # ============================================================================

  @doc """
  Renders stacked bar chart (Capital + Rewards + Costs + Net line).

  ## Examples

      <.stacked_bar_chart data={@flows_chart_data} />
  """
  attr :data, :string, required: true

  def stacked_bar_chart(assigns) do
    ~H"""
    <div class="stacked-bar-chart-container">
      <canvas
        id="flows-chart"
        phx-hook="StackedBarChart"
        data-chart={@data}
        class="stacked-bar-chart"
      ></canvas>
    </div>
    """
  end

  @doc """
  Renders cost/revenue ratio metrics.

  ## Examples

      <.flow_metrics current="15.2%" ltm="18.5%" />
  """
  attr :current, :string, required: true
  attr :ltm, :string, required: true

  def flow_metrics(assigns) do
    ~H"""
    <div class="flow-metrics">
      <div class="metric-col">
        <span class="metric-label">Cost/Revenue Ratio (Latest)</span>
        <span class="metric-value"><%= @current %></span>
      </div>
      <div class="metric-col">
        <span class="metric-label">Cost/Revenue Ratio (LTM)</span>
        <span class="metric-value"><%= @ltm %></span>
      </div>
    </div>
    """
  end

  @doc """
  Renders last 10 capital flows table.

  ## Examples

      <.flows_table data={@flows_table_data} />
  """
  attr :data, :list, required: true

  def flows_table(assigns) do
    ~H"""
    <div class="flows-table">
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th>Capital In</th>
            <th>Rewards</th>
            <th>Costs</th>
            <th>Net</th>
          </tr>
        </thead>
        <tbody>
          <%= for row <- @data do %>
            <tr>
              <td><%= row.date %></td>
              <td><%= row.capital_in %></td>
              <td><%= row.rewards %></td>
              <td><%= row.costs %></td>
              <td class={if String.starts_with?(row.net, "-"), do: "negative", else: "positive"}>
                <%= row.net %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  # ============================================================================
  # General Purpose Components
  # ============================================================================

  @doc """
  Renders a standard chart card container.

  ## Examples

      <.chart_card title="Network Metrics" id="network-section">
        <canvas...></canvas>
      </.chart_card>
  """
  attr :title, :string, required: true
  attr :id, :string, required: true
  slot :inner_block, required: true

  def chart_card(assigns) do
    ~H"""
    <div class="chart-card" id={@id}>
      <h3 class="chart-title"><%= @title %></h3>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  # RUNE token has 8 decimal places
  @rune_decimals 100_000_000

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
  defp format_number(_), do: "0"

  defp format_rune(rune_base_units) when is_integer(rune_base_units) do
    rune_decimal = rune_base_units / @rune_decimals

    # Format with thousands separator and 2 decimal places
    formatted = :erlang.float_to_binary(rune_decimal, decimals: 2)

    # Add thousands separators
    [integer_part, decimal_part] = String.split(formatted, ".")

    integer_with_commas = integer_part
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()

    integer_with_commas <> "." <> decimal_part
  end
  defp format_rune(_), do: "0.00"

  defp format_large_number(num) when is_number(num) do
    cond do
      num >= 1_000_000_000 -> "$#{Float.round(num / 1_000_000_000, 2)}B"
      num >= 1_000_000 -> "$#{Float.round(num / 1_000_000, 2)}M"
      num >= 1_000 -> "$#{Float.round(num / 1_000, 2)}K"
      true -> "$#{num}"
    end
  end
  defp format_large_number(_), do: "$0"

  defp format_percentage(value) when is_number(value) do
    "#{Float.round(value * 100, 1)}%"
  end
  defp format_percentage(_), do: "0.0%"
end
