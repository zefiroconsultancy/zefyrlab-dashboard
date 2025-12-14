defmodule Rujira.Thorchain.Swap do
  @moduledoc """
  The base layer pool virtualization contract for Fin
  """

  def init_msg(config), do: config
  def init_label(_, _), do: "rujira-thorchain-swap"
  def migrate_msg(_, _, _), do: nil
end
