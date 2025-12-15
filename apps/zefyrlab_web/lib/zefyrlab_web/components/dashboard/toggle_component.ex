defmodule ZefyrlabWeb.Components.Dashboard.ToggleComponent do
  @moduledoc """
  Generic button group toggle component.

  This component consolidates scenario_selector and currency_toggle into a single,
  reusable component that handles any button group selection.
  """

  use Phoenix.Component

  attr :options, :list, required: true, doc: "List of %{value: any, label: string} maps"
  attr :selected, :any, required: true, doc: "Currently selected value (string or atom)"
  attr :event, :string, required: true, doc: "Phoenix LiveView event name"
  attr :container_class, :string, default: "toggle-group", doc: "CSS class for container"

  def toggle_group(assigns) do
    ~H"""
    <div class={@container_class}>
      <%= for option <- @options do %>
        <button
          type="button"
          phx-click={@event}
          phx-value-selected={option.value}
          class={if normalize_value(@selected) == normalize_value(option.value), do: "active", else: ""}
        >
          <%= option.label %>
        </button>
      <% end %>
    </div>
    """
  end

  # Normalize both string and atom values for comparison
  defp normalize_value(val) when is_atom(val), do: Atom.to_string(val)
  defp normalize_value(val) when is_binary(val), do: val
  defp normalize_value(val), do: to_string(val)
end
