defmodule Cosmos.Address do
  @moduledoc """
  Address derivation and Bech32 encoding for Cosmos networks.

  Handles:
  - Address derivation from public keys using SHA256 + RIPEMD160
  - Bech32 encoding with different human-readable prefixes
  - Multi-chain address formats (cosmos, thor, osmo, etc.)
  - Address validation and conversion
  """

  import Bitwise

  # Default HRP - can be overridden at compile time via config
  @default_hrp Application.compile_env(:cosmos, :hrp, "cosmos")

  @doc """
  Derives a Bech32 address from a public key.

  ## Parameters
    * `public_key` - 33-byte compressed public key
    * `hrp` - Human-readable prefix (default: "cosmos")

  Returns `{:ok, address}` or `{:error, reason}`.
  """
  @spec from_pubkey(binary(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def from_pubkey(public_key, hrp \\ @default_hrp)

  def from_pubkey(<<_::264>> = pub33, hrp) when is_binary(hrp) do
    with {:ok, hash160} <- hash_pubkey(pub33),
         {:ok, data5} <- convertbits(hash160, 8, 5, true) do
      bech32_encode(String.downcase(hrp), data5)
    end
  end

  def from_pubkey(_, _), do: {:error, :invalid_pubkey}

  @doc """
  Derives a Bech32 address from a private key.

  Convenience function that derives the public key first.

  ## Parameters
    * `private_key` - Private key (binary or hex string)
    * `hrp` - Human-readable prefix (default: "cosmos")

  Returns `{:ok, address}` or `{:error, reason}`.
  """
  @spec from_private_key(binary() | String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def from_private_key(private_key, hrp \\ @default_hrp) do
    with {:ok, public_key} <- Cosmos.Crypto.pubkey_from_priv(private_key) do
      from_pubkey(public_key, hrp)
    end
  end

  @doc """
  Validates a Bech32 address format.

  ## Parameters
    * `address` - The address to validate
    * `expected_hrp` - Optional expected human-readable prefix

  Returns `:ok` or `{:error, reason}`.
  """
  @spec validate(String.t(), String.t() | nil) :: :ok | {:error, term()}
  def validate(address, expected_hrp \\ nil)

  def validate(address, expected_hrp) when is_binary(address) do
    case bech32_decode(address) do
      {:ok, {hrp, data5}} ->
        with {:ok, hash160} <- convertbits(data5, 5, 8, false),
             :ok <- validate_hash_length(hash160) do
          validate_hrp(hrp, expected_hrp)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate(_, _), do: {:error, :invalid_address_format}

  # ---- helpers ----------------------------------------------------------------

  defp hash_pubkey(<<_::264>> = pub33) do
    h1 = :crypto.hash(:sha256, pub33)
    h160 = :crypto.hash(:ripemd160, h1)

    if byte_size(h160) == 20 do
      {:ok, h160}
    else
      {:error, :hash_length_error}
    end
  end

  defp validate_hash_length(hash) when byte_size(hash) == 20, do: :ok
  defp validate_hash_length(_), do: {:error, :invalid_hash_length}

  defp validate_hrp(_hrp, nil), do: :ok
  defp validate_hrp(hrp, expected) when hrp == expected, do: :ok
  defp validate_hrp(hrp, expected), do: {:error, {:hrp_mismatch, hrp, expected}}

  # Bech32 implementation using the working Signer approach
  defp bech32_encode(hrp, data5) do
    with :ok <- validate_hrp(hrp),
         {:ok, chk} <- create_checksum(hrp, data5),
         {:ok, str} <- do_encode(hrp, data5 ++ chk) do
      {:ok, str}
    else
      {:error, _} = e -> e
      other -> {:error, {:encode_failed, other}}
    end
  rescue
    e -> {:error, {:bech32_encode_error, e}}
  end

  defp validate_hrp(hrp) do
    # BIP-0173 recommends lowercase; Cosmos/THOR use lowercase hrp.
    if hrp != String.downcase(hrp) or hrp == "" do
      {:error, :bad_hrp}
    else
      :ok
    end
  end

  defp do_encode(hrp, data5_list) do
    sep = "1"
    charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

    chars =
      Enum.map_join(data5_list, "", &String.at(charset, &1))

    {:ok, hrp <> sep <> chars}
  end

  defp bech32_decode(addr) when is_binary(addr) do
    case String.split(addr, "1") do
      [hrp, data_part] when byte_size(hrp) > 0 and byte_size(data_part) >= 6 ->
        with {:ok, data5} <- decode_data_part(data_part),
             :ok <- verify_checksum(hrp, data5) do
          payload = Enum.drop(data5, -6)
          {:ok, {hrp, payload}}
        end

      _ ->
        {:error, :invalid_bech32_format}
    end
  rescue
    e -> {:error, {:bech32_decode_error, e}}
  end

  defp decode_data_part(data_part) do
    data5 =
      data_part
      |> String.to_charlist()
      |> Enum.map(&charset_decode/1)

    if Enum.any?(data5, &(&1 == :error)) do
      {:error, :invalid_bech32_character}
    else
      {:ok, data5}
    end
  end

  defp verify_checksum(hrp, data5) do
    spec = polymod([hrp_expand(hrp), data5] |> List.flatten())

    if spec == 1 do
      :ok
    else
      {:error, :invalid_checksum}
    end
  end

  defp convertbits(data, frombits, tobits, pad)
       when is_binary(data) and is_integer(frombits) and is_integer(tobits) and
              frombits > 0 and tobits > 0 and frombits <= 8 and tobits <= 8 do
    maxv = (1 <<< tobits) - 1

    with {:ok, {out, acc, bits}} <- process_input_bytes(data, frombits, tobits, maxv) do
      finalize_conversion(out, acc, bits, frombits, tobits, maxv, pad)
    end
  end

  defp process_input_bytes(data, frombits, tobits, maxv) do
    {out, acc, bits} =
      data
      |> :binary.bin_to_list()
      |> Enum.reduce({[], 0, 0}, fn b, {out, acc, bits} ->
        process_byte(b, out, acc, bits, frombits, tobits, maxv)
      end)

    if Enum.any?(out, &(&1 == :invalid)) do
      {:error, :invalid_data_range}
    else
      {:ok, {out, acc, bits}}
    end
  end

  defp process_byte(b, out, acc, bits, frombits, tobits, maxv) do
    if valid_byte?(b, frombits) do
      acc = acc <<< frombits ||| b
      bits = bits + frombits
      emit_loop(out, acc, bits, tobits, maxv)
    else
      {[:invalid | out], acc, bits}
    end
  end

  defp valid_byte?(b, frombits), do: b >= 0 and b >>> frombits == 0

  defp finalize_conversion(out, acc, bits, frombits, tobits, maxv, pad) do
    cond do
      should_pad?(pad, bits) ->
        {:ok, Enum.reverse(out, [acc <<< (tobits - bits) &&& maxv])}

      has_invalid_padding?(pad, bits, acc, frombits, tobits, maxv) ->
        {:error, :invalid_padding}

      true ->
        {:ok, Enum.reverse(out)}
    end
  end

  defp should_pad?(pad, bits), do: pad and bits > 0

  defp has_invalid_padding?(false, bits, acc, frombits, tobits, maxv) do
    bits >= frombits or (acc <<< (tobits - bits) &&& maxv) != 0
  end

  defp has_invalid_padding?(true, _bits, _acc, _frombits, _tobits, _maxv), do: false

  # emit as many tobits-sized groups as possible
  defp emit_loop(out, acc, bits, tobits, maxv) do
    if bits >= tobits do
      bits2 = bits - tobits
      val = acc >>> bits2 &&& maxv
      emit_loop([val | out], acc, bits2, tobits, maxv)
    else
      {out, acc, bits}
    end
  end

  # Bech32 constants and helper functions
  @generator [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]

  defp polymod(values) do
    Enum.reduce(values, 1, fn v, chk ->
      b = chk >>> 25
      chk = bxor((chk &&& 0x1FFFFFF) <<< 5, v)
      chk = if (b &&& 1) != 0, do: bxor(chk, Enum.at(@generator, 0)), else: chk
      chk = if (b &&& 2) != 0, do: bxor(chk, Enum.at(@generator, 1)), else: chk
      chk = if (b &&& 4) != 0, do: bxor(chk, Enum.at(@generator, 2)), else: chk
      chk = if (b &&& 8) != 0, do: bxor(chk, Enum.at(@generator, 3)), else: chk
      chk = if (b &&& 16) != 0, do: bxor(chk, Enum.at(@generator, 4)), else: chk
      chk
    end)
  end

  defp hrp_expand(hrp) do
    high = for <<c <- hrp>>, do: c >>> 5
    low = for <<c <- hrp>>, do: c &&& 31
    high ++ [0] ++ low
  end

  defp create_checksum(hrp, data5_list) do
    pm =
      (hrp_expand(hrp) ++ data5_list ++ [0, 0, 0, 0, 0, 0])
      |> polymod()
      |> bxor(1)

    list = Enum.map(0..5, fn i -> pm >>> (5 * (5 - i)) &&& 31 end)
    {:ok, list}
  end

  @charset "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

  defp charset_decode(c) do
    case String.graphemes(@charset) |> Enum.find_index(&(&1 == List.to_string([c]))) do
      nil -> :error
      index -> index
    end
  end
end
