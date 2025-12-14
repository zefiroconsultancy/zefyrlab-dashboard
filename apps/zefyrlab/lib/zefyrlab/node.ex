defmodule Zefyrlab.Node do
  @moduledoc """
  Thorchain node client for Zefyrlab application.

  Uses Cosmos.Node to provide gRPC connectivity to Thorchain nodes
  with separate pools for queries and transactions.
  """

  use Cosmos.Node, otp_app: :zefyrlab, publisher: Zefyrlab.Publisher
end
