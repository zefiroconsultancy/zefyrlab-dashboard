defmodule ZefyrlabWeb.Components.Dashboard.KpiComponents do
  @moduledoc """
  KPI card components for hero overview section.

  All values are pre-formatted strings from the Dashboard context.
  """

  use Phoenix.Component

  attr :label, :string, required: true, doc: "KPI label text"
  attr :value, :any, required: true, doc: "Pre-formatted KPI value"
  attr :unit, :string, default: nil, doc: "Optional unit suffix (deprecated, include in value)"

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
end
