defmodule Cosmos.Crypto do
  @moduledoc """
  Cryptographic operations for Cosmos transactions.

  Provides secp256k1 cryptography functions including:
  - Private/public key operations
  - Digital signatures with low-S normalization
  - Key validation and conversion
  """

  alias ExSecp256k1, as: Secp

  @type priv32 :: <<_::256>>
  @type pub33 :: <<_::264>>
  @type digest32 :: <<_::256>>
  @type sig64 :: <<_::512>>

  @secp_n 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

  @doc """
  Derives a compressed public key from a private key.

  ## Parameters
    * `private_key` - 32-byte private key (binary or hex string)

  Returns `{:ok, public_key}` or `{:error, reason}`.
  """
  @spec pubkey_from_priv(binary() | String.t()) :: {:ok, pub33} | {:error, term()}
  def pubkey_from_priv(private_key) do
    with {:ok, priv32} <- normalize_private_key(private_key),
         {:ok, pub} <- Secp.create_public_key(priv32) do
      ensure_compressed(pub)
    end
  end

  @doc """
  Signs a 32-byte digest with a private key using compact format with low-S normalization.

  ## Parameters
    * `private_key` - 32-byte private key (binary or hex string)
    * `digest` - 32-byte message digest

  Returns `{:ok, signature}` (64-byte r||s format) or `{:error, reason}`.
  """
  @spec sign_compact(binary() | String.t(), digest32) :: {:ok, sig64} | {:error, term()}
  def sign_compact(private_key, <<_::256>> = digest) do
    with {:ok, priv32} <- normalize_private_key(private_key),
         {:ok, {<<_::512>> = sig, _recid}} <- Secp.sign_compact(digest, priv32) do
      {:ok, normalize_to_low_s(sig)}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:sign_failed, other}}
    end
  end

  def sign_compact(_, _), do: {:error, :invalid_digest}

  @doc """
  Validates and normalizes a private key.

  Accepts:
  - 32-byte binary
  - 64-character hex string (with or without 0x prefix)

  Returns `{:ok, private_key_binary}` or `{:error, reason}`.
  """
  @spec normalize_private_key(binary() | String.t()) :: {:ok, priv32} | {:error, term()}
  def normalize_private_key(<<_::256>> = bin), do: {:ok, bin}
  def normalize_private_key("0x" <> hex), do: normalize_hex(hex)

  def normalize_private_key(hex) when is_binary(hex) and byte_size(hex) in 64..66,
    do: normalize_hex(hex)

  def normalize_private_key(_), do: {:error, :invalid_private_key}

  # ---- helpers ----------------------------------------------------------------

  defp normalize_hex(hex) do
    case Base.decode16(pad_even(hex), case: :mixed) do
      {:ok, <<_::256>> = bin} -> {:ok, bin}
      {:ok, _} -> {:error, :invalid_key_length}
      :error -> {:error, :invalid_hex}
    end
  end

  defp pad_even(h) when rem(byte_size(h), 2) == 0, do: h
  defp pad_even(h), do: "0" <> h

  defp ensure_compressed(<<4, _::binary-size(64)>> = uncompressed),
    do: Secp.public_key_compress(uncompressed)

  defp ensure_compressed(<<2, _::binary-size(32)>> = compressed), do: {:ok, compressed}
  defp ensure_compressed(<<3, _::binary-size(32)>> = compressed), do: {:ok, compressed}
  defp ensure_compressed(other), do: {:error, {:unexpected_pubkey_format, byte_size(other)}}

  defp normalize_to_low_s(<<r::binary-32, s::binary-32>>) do
    s_int = :binary.decode_unsigned(s)

    if s_int > div(@secp_n, 2) do
      low_s = @secp_n - s_int
      r <> (:binary.encode_unsigned(low_s) |> left_pad_32())
    else
      r <> s
    end
  end

  defp left_pad_32(<<_::binary-size(32)>> = b), do: b

  defp left_pad_32(b) when is_binary(b) do
    <<0::unit(8)-size(32 - byte_size(b)), b::binary>>
  end
end
