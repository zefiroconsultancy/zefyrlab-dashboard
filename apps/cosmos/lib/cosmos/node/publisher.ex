defmodule Cosmos.Node.Publisher do
  @callback publish(non_neg_integer()) :: :ok | {:error, any()}
end
