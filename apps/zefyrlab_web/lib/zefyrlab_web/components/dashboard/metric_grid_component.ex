defmodule ZefyrlabWeb.Components.Dashboard.MetricGrid do
  @moduledoc """
  Generic metric grid component for displaying label-value pairs.

  This component consolidates projection_kpis, metrics_row, flow_metrics,
  and cumulative_stats into a single, flexible component.

  All values must be pre-formatted strings from the Dashboard context.
  """

  use Phoenix.Component

  attr :metrics, :list, required: true, doc: "List of %{label: string, value: string} maps"
  attr :layout, :atom, default: :rows, values: [:rows, :columns], doc: "Layout direction"
  attr :container_class, :string, default: nil, doc: "Optional CSS class override"

  def metric_grid(assigns) do
    ~H"""
    <div class={@container_class || default_container_class(@layout)}>
      <%= for metric <- @metrics do %>
        <div class={metric_item_class(@layout)}>
          <span class="metric-label"><%= metric.label %></span>
          <span class="metric-value"><%= metric.value %></span>
        </div>
      <% end %>
    </div>
    """
  end

  defp default_container_class(:rows), do: "metric-rows"
  defp default_container_class(:columns), do: "metric-columns"

  defp metric_item_class(:rows), do: "kpi-row"
  defp metric_item_class(:columns), do: "metric-col"
end
