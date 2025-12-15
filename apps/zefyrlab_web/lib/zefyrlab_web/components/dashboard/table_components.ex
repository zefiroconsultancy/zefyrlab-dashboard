defmodule ZefyrlabWeb.Components.Dashboard.TableComponents do
  @moduledoc """
  Table components for displaying financial data.

  All values are pre-formatted strings from the Dashboard context.
  """

  use Phoenix.Component

  attr :data, :map, required: true, doc: "Map with wallet, bonded, total keys"

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

  attr :data, :list, required: true, doc: "List of flow maps with date, capital_in, rewards, costs, net"

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
end
