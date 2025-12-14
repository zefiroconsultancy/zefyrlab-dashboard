defmodule Rujira.Revenue do
  @moduledoc """
  Rujira Staking.
  """
  alias Rujira.Balances
  alias Rujira.Contracts
  alias Rujira.Deployments
  alias Rujira.Revenue.Converter

  @protocol :rujira
            |> Application.compile_env(__MODULE__, protocol: nil)
            |> Keyword.get(:protocol)

  def protocol, do: @protocol

  def list_converters do
    Converter
    |> Deployments.list_targets()
    |> Rujira.Enum.reduce_async_while_ok(&load_converter/1)
  end

  @spec get_converter(String.t() | nil) :: {:ok, Converter.t()} | {:error, :not_found}
  def get_converter(nil), do: {:ok, nil}
  def get_converter(address), do: Contracts.get({Converter, address})

  defp load_converter(%{status: :preview} = target), do: {:ok, Converter.from_target(target)}

  defp load_converter(%{address: address}) do
    with {:ok, converter} <- Contracts.get({Converter, address}),
         {:ok, %{"actions" => actions}} <-
           Contracts.query_state_smart(address, %{actions: %{}}),
         {:ok, actions} <- Rujira.Enum.reduce_while_ok(actions, &Converter.Action.from_query/1),
         {:ok, balances} <- Balances.balances(address, nil) do
      {:ok, %{converter | balances: balances, actions: actions}}
    end
  end
end
