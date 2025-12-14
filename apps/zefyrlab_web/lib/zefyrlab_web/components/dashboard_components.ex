defmodule ZefyrlabWeb.DashboardComponents do
  use Phoenix.Component

  @doc """
  Renders a KPI card with label, value, and unit.

  ## Examples

      <.kpi_card label="Current Capital" value="1,234,567" unit="RUNE" />
      <.kpi_card label="Rewards YTD" value="$123,456" />
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :unit, :string, default: nil

  def kpi_card(assigns) do
    ~H"""
    <div class="kpi-card">
      <div class="kpi-label"><%= @label %></div>
      <div class="kpi-value">
        <%= @value %>
        <span :if={@unit} class="kpi-unit"><%= @unit %></span>
      </div>
    </div>
    """
  end

  @doc """
  Renders a large metric display for valuations.

  ## Examples

      <.large_metric value="$2,345,678" subtitle="DCF-based, live updated" />
  """
  attr :value, :any, required: true
  attr :subtitle, :string, default: nil

  def large_metric(assigns) do
    ~H"""
    <div>
      <div class="large-metric"><%= @value %></div>
      <p :if={@subtitle} class="metric-subtitle"><%= @subtitle %></p>
    </div>
    """
  end

  @doc """
  Renders a button group selector.

  ## Examples

      <.button_group_selector
        label="Year"
        options={[2026, 2027, 2028, 2029, 2030]}
        selected={@selected_year}
        event="change_year"
      />
  """
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :selected, :any, required: true
  attr :event, :string, required: true

  def button_group_selector(assigns) do
    ~H"""
    <div class="selector-group">
      <label><%= @label %></label>
      <div class="button-group">
        <button
          :for={option <- @options}
          phx-click={@event}
          phx-value-value={option}
          class={if option == @selected, do: "active", else: ""}
        >
          <%= format_option(option) %>
        </button>
      </div>
    </div>
    """
  end

  defp format_option("30_days"), do: "Last 30 Days"
  defp format_option("90_days"), do: "Last 90 Days"
  defp format_option("all_time"), do: "All Time"
  defp format_option(option) when is_binary(option), do: option
  defp format_option(option), do: to_string(option)

  @doc """
  Renders a chart card container.

  ## Examples

      <.chart_card title="Bonded Capital Over Time" id="chart-bonded">
        <p class="text-muted">Chart placeholder</p>
      </.chart_card>
  """
  attr :title, :string, required: true
  attr :id, :string, required: true
  slot :inner_block, required: true

  def chart_card(assigns) do
    ~H"""
    <div class="chart-card">
      <div class="chart-header">
        <h3><%= @title %></h3>
      </div>
      <div id={@id}>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
