defmodule ZefyrlabWeb.Components.Dashboard.ChartComponent do
  @moduledoc """
  Generic chart component for all Chart.js visualizations.

  This component consolidates 5 different chart components into a single,
  reusable component that handles all chart types through configuration.
  """

  use Phoenix.Component

  attr :id, :string, required: true, doc: "Unique ID for the canvas element"
  attr :hook, :string, required: true, doc: "Phoenix LiveView hook name (e.g., 'ProjectionChart')"
  attr :data, :string, required: true, doc: "JSON-encoded chart data"
  attr :container_class, :string, default: "chart-container", doc: "CSS class for container div"
  attr :canvas_class, :string, default: "chart", doc: "CSS class for canvas element"
  attr :height, :string, default: nil, doc: "Optional height style"

  def chart(assigns) do
    ~H"""
    <div class={@container_class}>
      <canvas
        id={@id}
        phx-hook={@hook}
        data-chart={@data}
        class={@canvas_class}
        style={if @height, do: "height: #{@height}", else: nil}
      >
      </canvas>
    </div>
    """
  end
end
