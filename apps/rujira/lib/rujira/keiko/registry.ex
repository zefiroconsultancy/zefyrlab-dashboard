defmodule Rujira.Keiko.Registry do
  @moduledoc """
  Registry for Keiko sales and idx lookups
  """
  alias Rujira.Keiko

  use GenServer

  def start_link(init_arg \\ []) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, build_sale_lookups()}
  end

  # --- GenServer Callbacks ---

  @impl true
  def handle_call({:idx_from_sale, address}, _from, lookup) do
    case Map.get(lookup, address) do
      nil -> {:reply, {:error, :not_found}, lookup}
      idx -> {:reply, {:ok, idx}, lookup}
    end
  end

  @impl true
  def handle_cast({:add_sale_to_lookup, idx}, lookup) do
    with {:ok, sale} <- Keiko.query_sale(idx) do
      updated_state = map_sales_to_addresses(sale, lookup)
      {:noreply, updated_state}
    end
  end

  # --- Private Functions ---

  defp build_sale_lookups do
    case Keiko.load_sales(nil, nil) do
      {:ok, sales} ->
        Enum.reduce(sales, %{}, fn sale, addr_to_idx ->
          map_sales_to_addresses(sale, addr_to_idx)
        end)

      _ ->
        %{}
    end
  end

  defp map_sales_to_addresses(sale, addr_to_idx) do
    case sale.venture do
      %{sale: %{address: address}} when not is_nil(address) ->
        Map.put(addr_to_idx, address, sale.idx)

      _ ->
        addr_to_idx
    end
  end
end
