defmodule Rujira.Node do
  @moduledoc """
  Runtime delegator for the configured Cosmos node implementation.

  Allows Rujira to swap node backends (e.g. mocked adapters in tests)
  by changing the `:rujira, :node` application environment entry while
  defaulting to the `:cosmos, :node` setting when no override is present.
  """

  @type query_fun ::
          (GRPC.Channel.t(), term() -> {:ok, term()} | {:error, GRPC.RPCError.t() | term()})

  @spec query(query_fun, term(), keyword()) :: {:ok, term()} | {:error, term()}
  def query(fun, request, opts \\ []) do
    impl().query(fun, request, opts)
  end

  @spec broadcast(binary(), keyword()) :: {:ok, term()} | {:error, term()}
  def broadcast(tx_bytes, opts \\ []) when is_binary(tx_bytes) do
    impl().broadcast(tx_bytes, opts)
  end

  @spec simulate(binary(), keyword()) :: {:ok, term()} | {:error, term()}
  def simulate(tx_bytes, opts \\ []) when is_binary(tx_bytes) do
    impl().simulate(tx_bytes, opts)
  end

  defp impl do
    Application.get_env(:rujira, :node) ||
      Application.fetch_env!(:cosmos, :node)
  end
end
