defmodule Cosmos.Signer do
  @moduledoc """
  High-level interface for Cosmos transaction signing.

  Provides transaction signing functions:
  1. sign/1 - Signs transactions with structured parameters
  2. sign_and_broadcast/1 - Signs and broadcasts in one operation

  For broadcasting only, call broadcast/2 directly on your node module (e.g., MyApp.Node.broadcast/2).
  """

  alias Cosmos.Address
  alias Cosmos.Crypto
  alias Cosmos.Crypto.Secp256k1.PubKey
  alias Cosmos.Tx.V1beta1.AuthInfo
  alias Cosmos.Tx.V1beta1.Fee
  alias Cosmos.Tx.V1beta1.ModeInfo
  alias Cosmos.Tx.V1beta1.SignDoc
  alias Cosmos.Tx.V1beta1.SignerInfo
  alias Cosmos.Tx.V1beta1.Tx
  alias Cosmos.Tx.V1beta1.TxBody
  alias Cosmos.Tx.V1beta1.TxRaw
  alias Google.Protobuf.Any

  # Default chain ID - can be overridden at compile time via config
  @default_chain_id Application.compile_env(:cosmos, :chain_id, "cosmoshub-4")
  @default_hrp Application.compile_env(:cosmos, :hrp, "cosmos")

  @type fee_opts :: %{required(:gas_limit) => pos_integer(), optional(atom()) => any()}
  @type broadcast_opts :: %{optional(atom()) => any()}
  @type sign_params :: %{
          required(:messages) => list(Any.t()),
          required(:fee_opts) => fee_opts(),
          required(:private_key) => binary() | String.t(),
          required(:account_number) => non_neg_integer(),
          required(:sequence) => non_neg_integer(),
          optional(:chain_id) => String.t(),
          optional(:hrp) => String.t()
        }

  @doc """
  Signs a transaction with explicit account information.

  ## Parameters
    * `params` - Map with transaction signing parameters

  ## Example
      params = %{
        messages: [transfer_msg],
        fee_opts: %{gas_limit: 200_000},
        private_key: "abc123...",
        account_number: 42,
        sequence: 1,
        chain_id: "cosmoshub-4",
        hrp: "cosmos"
      }
      
      {:ok, signed_tx} = Cosmos.Signer.sign(params)
  """
  @spec sign(sign_params()) :: {:ok, Tx.t()} | {:error, term()}
  def sign(
        %{
          messages: messages,
          fee_opts: fee_opts,
          private_key: private_key,
          account_number: account_number,
          sequence: sequence
        } = params
      )
      when is_list(messages) and is_map(fee_opts) and is_integer(account_number) and
             is_integer(sequence) do
    chain_id = Map.get(params, :chain_id, @default_chain_id)
    hrp = Map.get(params, :hrp, @default_hrp)

    do_sign(messages, fee_opts, private_key, account_number, sequence, chain_id, hrp)
  end

  def sign(_), do: {:error, :invalid_sign_params}

  defp do_sign(messages, fee_opts, private_key, account_number, sequence, chain_id, hrp) do
    with {:ok, _gas_limit} <- validate_gas_limit(fee_opts),
         {:ok, _address} <- Address.from_private_key(private_key, hrp),
         {:ok, unsigned_tx} <- build_unsigned_tx(messages, fee_opts) do
      sign_transaction(
        unsigned_tx,
        chain_id,
        account_number,
        private_key,
        sequence
      )
    end
  end

  @type sign_and_broadcast_params :: %{
          required(:node_module) => module(),
          required(:messages) => list(Any.t()),
          required(:fee_opts) => fee_opts(),
          required(:private_key) => binary() | String.t(),
          required(:account_number) => non_neg_integer(),
          required(:sequence) => non_neg_integer(),
          optional(:broadcast_opts) => broadcast_opts(),
          optional(:chain_id) => String.t(),
          optional(:hrp) => String.t()
        }

  @doc """
  Signs and broadcasts a transaction in one operation.
  Returns `{:ok, txhash}` or `{:error, reason}`.

  ## Example
      params = %{
        node_module: MyApp.Node,
        messages: [transfer_msg],
        fee_opts: %{gas_limit: 200_000},
        private_key: "abc123...",
        account_number: 42,
        sequence: 1,
        broadcast_opts: %{mode: :sync}
      }
      
      {:ok, txhash} = Cosmos.Signer.sign_and_broadcast(params)
  """
  @spec sign_and_broadcast(sign_and_broadcast_params()) :: {:ok, String.t()} | {:error, term()}
  def sign_and_broadcast(
        %{
          node_module: node_module,
          messages: messages,
          fee_opts: fee_opts,
          private_key: private_key,
          account_number: account_number,
          sequence: sequence
        } = params
      ) do
    sign_params = %{
      messages: messages,
      fee_opts: fee_opts,
      private_key: private_key,
      account_number: account_number,
      sequence: sequence,
      chain_id: Map.get(params, :chain_id, @default_chain_id),
      hrp: Map.get(params, :hrp, @default_hrp)
    }

    broadcast_opts = Map.get(params, :broadcast_opts, %{})

    with {:ok, signed_tx} <- sign(sign_params),
         {:ok, tx_raw_bytes} <- to_raw_bytes(signed_tx) do
      node_module.broadcast(tx_raw_bytes, broadcast_opts)
    end
  end

  # ---- helpers ----------------------------------------------------------------

  defp validate_gas_limit(%{gas_limit: gas_limit}) when is_integer(gas_limit) and gas_limit > 0 do
    {:ok, gas_limit}
  end

  defp validate_gas_limit(_), do: {:error, :invalid_gas_limit}

  defp build_unsigned_tx(messages, fee_opts) do
    with {:ok, validated_messages} <- validate_any_messages(messages),
         {:ok, fee} <- build_fee(fee_opts),
         {:ok, tx_body} <- build_tx_body(validated_messages, fee_opts),
         {:ok, auth_info} <- build_auth_info(fee) do
      {:ok, %Tx{body: tx_body, auth_info: auth_info, signatures: []}}
    end
  end

  defp validate_any_messages(messages) when is_list(messages) do
    messages
    |> Enum.reduce_while({:ok, []}, fn msg, {:ok, acc} ->
      case validate_any_message(msg) do
        {:ok, validated} -> {:cont, {:ok, [validated | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, validated_messages} -> {:ok, Enum.reverse(validated_messages)}
      error -> error
    end
  end

  defp validate_any_message(%Any{type_url: type_url, value: value} = any_msg)
       when is_binary(type_url) and is_binary(value) do
    {:ok, any_msg}
  end

  defp validate_any_message(_), do: {:error, :invalid_any_message}

  defp build_fee(%{gas_limit: gas_limit} = fee_opts) do
    {:ok,
     %Fee{
       amount: Map.get(fee_opts, :amount, []),
       gas_limit: gas_limit,
       payer: Map.get(fee_opts, :payer, ""),
       granter: Map.get(fee_opts, :granter, "")
     }}
  end

  defp build_tx_body(messages, fee_opts) do
    {:ok,
     %TxBody{
       messages: messages,
       memo: Map.get(fee_opts, :memo, ""),
       timeout_height: Map.get(fee_opts, :timeout, 0),
       extension_options: [],
       non_critical_extension_options: []
     }}
  end

  defp build_auth_info(fee) do
    {:ok, %AuthInfo{signer_infos: [], fee: fee, tip: nil}}
  end

  defp sign_transaction(
         %Tx{body: %TxBody{} = body, auth_info: %AuthInfo{fee: %Fee{} = fee}},
         chain_id,
         account_number,
         private_key,
         sequence
       )
       when is_binary(chain_id) and is_integer(account_number) and is_integer(sequence) do
    with {:ok, priv32} <- Crypto.normalize_private_key(private_key),
         {:ok, pub33} <- Crypto.pubkey_from_priv(priv32),
         {:ok, signer} <- build_signer_info(pub33, sequence),
         auth <- %AuthInfo{signer_infos: [signer], fee: fee, tip: nil},
         sign_doc <- %SignDoc{
           body_bytes: TxBody.encode(body),
           auth_info_bytes: AuthInfo.encode(auth),
           chain_id: chain_id,
           account_number: account_number
         },
         digest <- :crypto.hash(:sha256, SignDoc.encode(sign_doc)),
         {:ok, sig} <- Crypto.sign_compact(priv32, digest) do
      {:ok, %Tx{body: body, auth_info: auth, signatures: [sig]}}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:sign_tx_failed, other}}
    end
  end

  defp sign_transaction(_, _, _, _, _), do: {:error, :invalid_sign_inputs}

  defp build_signer_info(<<_::264>> = pub33, sequence)
       when is_integer(sequence) and sequence >= 0 do
    pk_any = %Any{
      type_url: "/cosmos.crypto.secp256k1.PubKey",
      value: PubKey.encode(%PubKey{key: pub33})
    }

    mode = %ModeInfo{sum: {:single, %ModeInfo.Single{mode: 1}}}
    {:ok, %SignerInfo{public_key: pk_any, mode_info: mode, sequence: sequence}}
  end

  defp build_signer_info(_, _), do: {:error, :bad_signer_info}

  defp to_raw_bytes(%Tx{body: %TxBody{} = body, auth_info: %AuthInfo{} = auth, signatures: sigs})
       when is_list(sigs) and length(sigs) > 0 do
    tx_raw = %TxRaw{
      body_bytes: TxBody.encode(body),
      auth_info_bytes: AuthInfo.encode(auth),
      signatures: sigs
    }

    {:ok, TxRaw.encode(tx_raw)}
  rescue
    e -> {:error, {:encode_tx_raw_failed, e}}
  end

  defp to_raw_bytes(_), do: {:error, :tx_not_signed}
end
