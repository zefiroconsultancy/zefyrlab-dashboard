defmodule Cosmos.SignerIntegrationTest do
  use ExUnit.Case, async: true

  import Mox

  alias Cosmos.Bank.V1beta1.MsgSend
  alias Cosmos.Base.V1beta1.Coin
  alias Cosmos.Signer
  alias Google.Protobuf

  setup :verify_on_exit!

  # Mock implementation of node behavior for testing
  defmodule TestNode do
    def broadcast(tx_bytes, opts) do
      mode =
        case Map.get(opts, :mode, :sync) do
          :async -> :BROADCAST_MODE_ASYNC
          :sync -> :BROADCAST_MODE_SYNC
          :commit -> :BROADCAST_MODE_BLOCK
          _ -> :BROADCAST_MODE_SYNC
        end

      response = TestMock.broadcast_tx(:fake_grpc_channel, tx_bytes, mode)

      # Extract txhash like the real implementation
      case response do
        %{tx_response: %{txhash: hash}} when is_binary(hash) and byte_size(hash) > 0 ->
          {:ok, hash}

        %{tx_response: resp} when is_map(resp) ->
          {:error, {:empty_txhash, resp}}

        other ->
          {:error, {:no_tx_response, other}}
      end
    end
  end

  # Define mock for the test functions
  defmodule TestBehaviour do
    @callback broadcast_tx(any(), binary(), atom()) :: {:ok, String.t()} | {:error, term()}
  end

  Mox.defmock(TestMock, for: TestBehaviour)

  setup do
    :ok
  end

  # Test constants - EXACT same as signer app
  @chain_id "thorchain-1"
  @public_key "029861487da8e2cb1b9937b4bab4659fd1d198e73a51de3a31d702ecd52e8fe380"
  @private_key "5836db8acb39d410329bfa765ff4d25866628aaa6582be65a92acd95fdbd560a"
  @address "thor1h4eyzp33jx9nxh6dfz7s3jhjn3mkvpeh0u8hyk"

  test "addr_from_pub encodes thor Bech32 and roundtrips to 20 bytes" do
    assert {:ok, pub33} = Cosmos.Crypto.pubkey_from_priv(@private_key)
    assert Base.encode16(pub33, case: :lower) == String.downcase(@public_key)

    assert {:ok, addr} = Cosmos.Address.from_pubkey(pub33, "thor")
    assert String.starts_with?(addr, "thor1")
    assert addr == "thor1h4eyzp33jx9nxh6dfz7s3jhjn3mkvpeh0u8hyk"
  end

  test "sign tx" do
    # first verify that the public key matches the private key
    assert {:ok, pub33} = Cosmos.Crypto.pubkey_from_priv(@private_key)
    pub = Base.encode16(pub33, case: :lower)
    assert pub == String.downcase(@public_key)
    assert {:ok, addr} = Cosmos.Address.from_pubkey(pub33, "thor")
    assert addr == @address

    # Create unsigned transaction - exactly like signer app
    unsigned_tx = %Cosmos.Tx.V1beta1.Tx{
      body: %Cosmos.Tx.V1beta1.TxBody{
        messages: [
          %Protobuf.Any{
            type_url: "/cosmos.bank.v1beta1.MsgSend",
            value:
              MsgSend.encode(%MsgSend{
                from_address: "thor1h4eyzp33jx9nxh6dfz7s3jhjn3mkvpeh0u8hyk",
                to_address: "thor1ds7rqlfmgkevl7lmpetsxgqer6mmfhg26la3xh",
                amount: [%Coin{denom: "rune", amount: "1"}]
              })
          }
        ],
        memo: "",
        timeout_height: 0,
        extension_options: [],
        non_critical_extension_options: []
      },
      auth_info: %Cosmos.Tx.V1beta1.AuthInfo{
        signer_infos: [],
        fee: %Cosmos.Tx.V1beta1.Fee{
          amount: [],
          gas_limit: 200_000,
          payer: "",
          granter: ""
        },
        tip: nil
      },
      signatures: []
    }

    assert {:ok, signed_tx} =
             Signer.sign(%{
               messages: unsigned_tx.body.messages,
               fee_opts: %{gas_limit: 200_000},
               private_key: @private_key,
               account_number: 139_787,
               sequence: 40_021,
               chain_id: @chain_id,
               hrp: "thor"
             })

    # Verify signed transaction structure
    assert length(signed_tx.signatures) == 1
    assert length(signed_tx.auth_info.signer_infos) == 1
    [signature] = signed_tx.signatures
    assert byte_size(signature) == 64
  end

  test "sign_and_broadcast/1 with privkey passes gRPC node and returns txhash" do
    txhash = Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)

    TestMock
    |> expect(:broadcast_tx, fn _channel, tx_raw_bytes, mode ->
      assert is_binary(tx_raw_bytes) and byte_size(tx_raw_bytes) > 0
      assert mode == :BROADCAST_MODE_SYNC
      %{tx_response: %{txhash: txhash}}
    end)

    # Create the same message as signer app
    send_message = %Protobuf.Any{
      type_url: "/cosmos.bank.v1beta1.MsgSend",
      value:
        MsgSend.encode(%MsgSend{
          from_address: "thor1h4eyzp33jx9nxh6dfz7s3jhjn3mkvpeh0u8hyk",
          to_address: "thor1ds7rqlfmgkevl7lmpetsxgqer6mmfhg26la3xh",
          amount: [%Coin{denom: "rune", amount: "1"}]
        })
    }

    {:ok, hash} =
      Signer.sign_and_broadcast(%{
        node_module: TestNode,
        messages: [send_message],
        fee_opts: %{gas_limit: 200_000},
        private_key: @private_key,
        account_number: 139_787,
        sequence: 40_021,
        broadcast_opts: %{mode: :sync},
        chain_id: @chain_id,
        hrp: "thor"
      })

    assert hash == txhash
  end

  test "full workflow: create message -> sign" do
    # Create message exactly like signer app (users must do this themselves now)
    send_msg = %Protobuf.Any{
      type_url: "/cosmos.bank.v1beta1.MsgSend",
      value:
        MsgSend.encode(%MsgSend{
          from_address: @address,
          to_address: "thor1ds7rqlfmgkevl7lmpetsxgqer6mmfhg26la3xh",
          amount: [%Coin{denom: "rune", amount: "1"}]
        })
    }

    # Test the same workflow: message -> sign
    {:ok, signed_tx} =
      Signer.sign(%{
        messages: [send_msg],
        fee_opts: %{gas_limit: 200_000},
        private_key: @private_key,
        account_number: 139_787,
        sequence: 40_021,
        chain_id: @chain_id,
        hrp: "thor"
      })

    # Verify the signed transaction has signatures and signer info (same as signer app)
    assert length(signed_tx.signatures) == 1
    assert length(signed_tx.auth_info.signer_infos) == 1
    assert is_binary(hd(signed_tx.signatures))
    assert byte_size(hd(signed_tx.signatures)) == 64
  end
end
