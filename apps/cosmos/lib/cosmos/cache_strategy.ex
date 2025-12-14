defmodule Cosmos.CacheStrategy do
  @moduledoc """
  A Cache Strategy for Memoize that doesn't cache {:error, _} patterns.
  Useful to protect against gRPC connection failures and temporary errors getting permanently cached

  ```
  config :memoize, cache_strategy: Cosmos.CacheStrategy
  ```
  """

  @behaviour Memoize.CacheStrategy

  @ets_tab __MODULE__
  @access_frequency_tab Module.concat(__MODULE__, AccessFrequency)

  def init(opts) do
    :ets.new(@ets_tab, [:public, :set, :named_table, {:read_concurrency, true}])
    :ets.new(@access_frequency_tab, [:public, :set, :named_table, {:write_concurrency, true}])

    # Default global settings
    #
    # config :memoize, Cosmos.CacheStrategy,
    #   expires_in: 1000,
    #   min_threshold: 32 * 1024 * 1024,
    #   max_threshold: 64 * 1024 * 1024
    config = Application.get_env(:memoize, __MODULE__, [])
    expires_in = Keyword.get(config, :expires_in, :infinity)
    min_threshold = Keyword.get(config, :min_threshold, :infinity)
    max_threshold = Keyword.get(config, :max_threshold, :infinity)

    opts =
      opts
      |> Keyword.put(:expires_in, expires_in)
      |> Keyword.put(:min_threshold, min_threshold)
      |> Keyword.put(:max_threshold, max_threshold)

    opts
  end

  def tab(_key) do
    @ets_tab
  end

  defp used_bytes do
    words = 0
    words = words + :ets.info(@ets_tab, :memory)
    words = words + :ets.info(@access_frequency_tab, :memory)

    words * :erlang.system_info(:wordsize)
  end

  defp min_threshold do
    Memoize.Config.opts().min_threshold
  end

  defp max_threshold do
    Memoize.Config.opts().max_threshold
  end

  def cache(key, _value, opts) do
    # Check memory thresholds before caching
    if max_threshold() != :infinity and used_bytes() > max_threshold() do
      garbage_collect()
    end

    expires_in = Keyword.get(opts, :expires_in, Memoize.Config.opts().expires_in)

    expired_at =
      case expires_in do
        :infinity -> :infinity
        value -> System.monotonic_time(:millisecond) + value
      end

    # Initialize access frequency for new cache entries
    :ets.insert(@access_frequency_tab, {key, 0})

    expired_at
  end

  def read(key, {:error, %GRPC.RPCError{status: 2, message: message}}, _) do
    if String.contains?(message, "codespace wasm code 22: no such contract: address") do
      :ok
    else
      invalidate(key)
      :ok
    end
  end

  def read(key, {:error, _}, _) do
    invalidate(key)
    :ok
  end

  def read(key, _value, expired_at) do
    # Track access frequency for proven useful eviction strategy
    :ets.update_counter(@access_frequency_tab, key, {2, 1}, {key, 0})

    if expired_at != :infinity && System.monotonic_time(:millisecond) > expired_at do
      invalidate(key)
      :retry
    else
      :ok
    end
  end

  def invalidate do
    :ets.select_delete(@ets_tab, [{{:_, {:completed, :_, :_}}, [], [true]}])
    :ets.delete_all_objects(@access_frequency_tab)
  end

  def invalidate(key) do
    :ets.select_delete(@ets_tab, [{{key, {:completed, :_, :_}}, [], [true]}])
    :ets.delete(@access_frequency_tab, key)
  end

  def garbage_collect do
    expired_at = System.monotonic_time(:millisecond)

    # Clean up time-expired entries first
    expired_count =
      :ets.select_delete(@ets_tab, [
        {{:_, {:completed, :_, :"$1"}},
         [{:andalso, {:"/=", :"$1", :infinity}, {:<, :"$1", {:const, expired_at}}}], [true]}
      ])

    # Clean up corresponding frequency tracking entries
    all_cache_keys = :ets.select(@ets_tab, [{{:"$1", {:completed, :_, :_}}, [], [:"$1"]}])
    all_frequency_keys = :ets.select(@access_frequency_tab, [{{:"$1", :_}, [], [:"$1"]}])
    orphaned_frequency_keys = all_frequency_keys -- all_cache_keys
    Enum.each(orphaned_frequency_keys, &:ets.delete(@access_frequency_tab, &1))

    # If memory is still over threshold, evict least useful entries
    if min_threshold() != :infinity and used_bytes() > min_threshold() do
      evict_least_useful_entries()
    end

    expired_count
  end

  defp evict_least_useful_entries do
    # Get all cache entries with their access frequencies
    frequency_data = :ets.tab2list(@access_frequency_tab)

    # Sort by access frequency (ascending) to evict least useful first
    sorted_by_usefulness = Enum.sort_by(frequency_data, fn {_key, count} -> count end)

    # Evict entries until memory drops below min_threshold
    Enum.reduce_while(sorted_by_usefulness, 0, fn {key, _count}, evicted_count ->
      :ets.select_delete(@ets_tab, [{{key, {:completed, :_, :_}}, [], [true]}])
      :ets.delete(@access_frequency_tab, key)

      if used_bytes() <= min_threshold() do
        {:halt, evicted_count + 1}
      else
        {:cont, evicted_count + 1}
      end
    end)
  end
end
