defmodule Rujira.Ghost.Credit do
  @moduledoc """
  Ghost credit contract configuration and management.
  """

  defmodule CollateralConfig do
    @moduledoc """
    Collateral ratio configuration for Ghost credit.
    """
    defstruct [:denom, :ratio]

    def from_config(map) do
      {:ok,
       Enum.map(map, fn {denom, ratio} ->
         with {ratio, ""} <- Decimal.parse(ratio) do
           %__MODULE__{denom: denom, ratio: ratio}
         end
       end)}
    end
  end

  alias Rujira.Deployments.Target
  alias Rujira.Ghost.Credit.CollateralConfig

  defstruct [
    :id,
    :address,
    :code_id,
    :collaterals,
    :fee_liquidation,
    :fee_liquidator,
    :fee_address,
    :liquidation_max,
    :liquidation_threshold,
    :adjustment_threshold,
    :status,
    :deployment_status
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          address: String.t(),
          code_id: non_neg_integer(),
          deployment_status: Target.status()
        }

  def from_config(address, %{
        "code_id" => code_id,
        "collateral_ratios" => collateral_ratios,
        "fee_liquidation" => fee_liquidation,
        "fee_liquidator" => fee_liquidator,
        "fee_address" => fee_address,
        "liquidation_max" => liquidation_max,
        "liquidation_threshold" => liquidation_threshold,
        "adjustment_threshold" => adjustment_threshold
      }) do
    with {fee_liquidation, ""} <- Decimal.parse(fee_liquidation),
         {fee_liquidator, ""} <- Decimal.parse(fee_liquidator),
         {liquidation_max, ""} <- Decimal.parse(liquidation_max),
         {liquidation_threshold, ""} <- Decimal.parse(liquidation_threshold),
         {adjustment_threshold, ""} <- Decimal.parse(adjustment_threshold),
         {:ok, collaterals} <- CollateralConfig.from_config(collateral_ratios) do
      {:ok,
       %__MODULE__{
         id: address,
         address: address,
         code_id: code_id,
         collaterals: collaterals,
         fee_liquidation: fee_liquidation,
         fee_liquidator: fee_liquidator,
         fee_address: fee_address,
         liquidation_max: liquidation_max,
         liquidation_threshold: liquidation_threshold,
         adjustment_threshold: adjustment_threshold,
         status: :not_loaded
       }}
    end
  end

  def init_msg(msg), do: msg
  def migrate_msg(_from, _to, _), do: %{}
  def init_label(_, _), do: "rujira-ghost-credit"
end
