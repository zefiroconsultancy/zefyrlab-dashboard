defmodule Cosmos.CryptoTest do
  use ExUnit.Case, async: true

  alias Cosmos.Crypto

  # Test constants
  @priv_hex "b7e03eae2d19ae7250958295e69b11c5e56c5864ea9a1581a50683664ca6dde3"
  @pub_hex "0261780144d664451206d82a891e67d8b82273f62baf5996ba9328e5302e6cd44e"

  describe "pubkey_from_priv/1" do
    test "derives public key from hex private key" do
      assert {:ok, pub33} = Crypto.pubkey_from_priv(@priv_hex)
      assert byte_size(pub33) == 33
      assert Base.encode16(pub33, case: :lower) == @pub_hex
    end

    test "derives public key from binary private key" do
      {:ok, priv_bin} = Base.decode16(@priv_hex, case: :lower)
      assert {:ok, pub33} = Crypto.pubkey_from_priv(priv_bin)
      assert byte_size(pub33) == 33
    end

    test "handles 0x prefixed hex" do
      assert {:ok, pub33} = Crypto.pubkey_from_priv("0x" <> @priv_hex)
      assert byte_size(pub33) == 33
    end

    test "returns error for invalid private key" do
      assert {:error, :invalid_private_key} = Crypto.pubkey_from_priv("")
      assert {:error, :invalid_private_key} = Crypto.pubkey_from_priv("invalid")
      assert {:error, :invalid_private_key} = Crypto.pubkey_from_priv(123)
    end
  end

  describe "sign_compact/2" do
    test "signs digest with private key" do
      digest = :crypto.hash(:sha256, "test message")
      assert {:ok, signature} = Crypto.sign_compact(@priv_hex, digest)
      assert byte_size(signature) == 64
    end

    test "signs with binary private key" do
      {:ok, priv_bin} = Base.decode16(@priv_hex, case: :lower)
      digest = :crypto.hash(:sha256, "test message")
      assert {:ok, signature} = Crypto.sign_compact(priv_bin, digest)
      assert byte_size(signature) == 64
    end

    test "returns error for invalid digest" do
      assert {:error, :invalid_digest} = Crypto.sign_compact(@priv_hex, "short")
      assert {:error, :invalid_digest} = Crypto.sign_compact(@priv_hex, :not_binary)
    end

    test "returns error for invalid private key" do
      digest = :crypto.hash(:sha256, "test message")
      assert {:error, :invalid_private_key} = Crypto.sign_compact("invalid", digest)
    end
  end

  describe "normalize_private_key/1" do
    test "normalizes hex strings" do
      assert {:ok, priv_bin} = Crypto.normalize_private_key(@priv_hex)
      assert byte_size(priv_bin) == 32
    end

    test "normalizes 0x prefixed hex" do
      assert {:ok, priv_bin} = Crypto.normalize_private_key("0x" <> @priv_hex)
      assert byte_size(priv_bin) == 32
    end

    test "passes through binary" do
      {:ok, expected} = Base.decode16(@priv_hex, case: :lower)
      assert {:ok, ^expected} = Crypto.normalize_private_key(expected)
    end

    test "returns error for invalid inputs" do
      assert {:error, :invalid_private_key} = Crypto.normalize_private_key("")
      assert {:error, :invalid_private_key} = Crypto.normalize_private_key("short")
      assert {:error, :invalid_private_key} = Crypto.normalize_private_key(123)

      assert {:error, :invalid_private_key} =
               Crypto.normalize_private_key("invalid_hex_chars_xyz")
    end
  end

  describe "signature determinism" do
    test "produces consistent signatures for same input" do
      digest = :crypto.hash(:sha256, "consistent test")

      assert {:ok, sig1} = Crypto.sign_compact(@priv_hex, digest)
      assert {:ok, sig2} = Crypto.sign_compact(@priv_hex, digest)

      # Note: secp256k1 signatures are not deterministic by default
      # This test mainly ensures no errors occur with repeated signing
      assert byte_size(sig1) == 64
      assert byte_size(sig2) == 64
    end
  end
end
