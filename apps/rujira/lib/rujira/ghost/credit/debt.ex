defmodule Rujira.Ghost.Credit.Debt do
  @moduledoc """
  Ghost credit debt management.
  """
  alias Rujira.Ghost.Vault.Delegate

  defstruct [
    :debt,
    :value
  ]

  def from_query(%{
        "debt" => debt,
        "value" => value
      }) do
    with {:ok, debt} <- Delegate.from_query(debt) do
      {:ok,
       %__MODULE__{
         debt: debt,
         value: Decimal.new(value) |> Decimal.round() |> Decimal.to_integer()
       }}
    end
  end
end
