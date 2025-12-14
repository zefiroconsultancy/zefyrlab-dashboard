defmodule Rujira.Revenue.Converter do
  @moduledoc """
  Struct for a Revenue Converter contract
  """
  defmodule Action do
    @moduledoc """
    Struct for an Action on a Revenue Converter contract
    """
    defstruct [:denom, :contract, :limit, :msg]

    @type t :: %__MODULE__{
            denom: String.t(),
            contract: String.t(),
            limit: non_neg_integer(),
            msg: String.t()
          }

    def from_query(%{"denom" => denom, "contract" => contract, "limit" => limit, "msg" => msg}) do
      case Integer.parse(limit) do
        {limit, ""} ->
          {:ok,
           %__MODULE__{denom: denom, contract: contract, limit: limit, msg: Base.decode64!(msg)}}

        _ ->
          {:error, :invalid_action}
      end
    end
  end

  alias Cosmos.Base.V1beta1.Coin
  defstruct [:id, :address, :executor, :actions, :balances, :target_denoms, :target_addresses]

  @type t :: %__MODULE__{
          id: String.t(),
          address: String.t(),
          executor: String.t(),
          balances: list(Coin.t()),
          actions: list(Action.t()),
          target_denoms: list(String.t()),
          target_addresses: list({String.t(), non_neg_integer()})
        }

  @spec from_config(String.t(), map()) :: {:ok, __MODULE__.t()}
  def from_config(address, %{
        "target_denoms" => target_denoms,
        "target_addresses" => target_addresses,
        "executor" => executor
      }) do
    {:ok,
     %__MODULE__{
       id: address,
       address: address,
       executor: executor,
       actions: [],
       balances: [],
       target_denoms: target_denoms,
       target_addresses: Enum.map(target_addresses, &{Enum.at(&1, 0), Enum.at(&1, 1)})
     }}
  end

  def from_target(%{
        address: address,
        config: %{
          "target_addresses" => target_addresses,
          "target_denoms" => target_denoms,
          "executor" => executor
        }
      }) do
    {:ok,
     %__MODULE__{
       id: address,
       address: address,
       executor: executor,
       balances: [],
       actions: [],
       target_denoms: target_denoms,
       target_addresses: Enum.map(target_addresses, &{&1["address"], &1["weight"]})
     }}
  end

  def init_msg(%{
        "executor" => executor,
        "target_addresses" => target_addresses,
        "target_denoms" => target_denoms
      }) do
    %{
      owner: executor,
      executor: executor,
      target_addresses:
        Enum.map(target_addresses, fn
          %{"address" => address, "weight" => weight} -> [address, weight]
        end),
      target_denoms: target_denoms
    }
  end

  def migrate_msg(_from, _to, _), do: %{}

  def init_label(id, _), do: "rujira-revenue:#{id}"
end
