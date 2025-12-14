defmodule Rujira.Deployments do
  @moduledoc """
  Deployment management
  """

  alias Cosmwasm.Wasm.V1.ContractInfo
  alias Cosmwasm.Wasm.V1.MsgInstantiateContract2
  alias Cosmwasm.Wasm.V1.MsgMigrateContract
  alias Cosmwasm.Wasm.V1.MsgUpdateAdmin
  alias Rujira.Bow
  alias Rujira.Contracts
  alias Rujira.Deployments.Target
  alias Rujira.Fin
  alias Rujira.Ghost
  alias Rujira.Keiko
  alias Rujira.Revenue
  alias Rujira.Staking
  alias Rujira.Vestings

  use Memoize

  @path "data/deployments"

  def network, do: Application.get_env(:rujira, :network, "stagenet")

  defmemo get_target(module, id, network \\ network()) do
    list_all_targets(network)
    |> Enum.find(&(&1.module === module and &1.id == id))
  end

  @doc """
  Returns the address of a contract if it exists and is live
  """
  defmemo get_address(module, id, network \\ network()) do
    case get_target(module, id, network) do
      %{address: address, status: :live} -> address
      _ -> nil
    end
  end

  defmemo list_all_targets(network \\ network()) do
    %{codes: codes, targets: targets} = load_config!(network)

    with {:ok, result} <-
           Rujira.Enum.reduce_async_while_ok(
             targets,
             &parse_protocol(codes, &1)
           ) do
      List.flatten(result)
    end
  end

  @doc """
  List all targets for a given module
  """
  defmemo list_targets(module, network \\ network()) do
    network
    |> list_all_targets()
    |> Enum.filter(&(&1.module === module))
  end

  defmemo contract_file_path(name, network \\ network()) do
    Application.app_dir(:rujira, "priv")
    |> Path.join(@path)
    |> Path.join(network)
    |> Path.join("contracts")
    |> Path.join("#{name}.yaml")
  end

  defmemo load_config!(network \\ network()) do
    deploy_dir =
      Application.app_dir(:rujira, "priv")
      |> Path.join(@path)
      |> Path.join(network)

    yaml_files =
      deploy_dir
      |> Path.join("contracts")
      |> File.ls!()

    {codes, targets} =
      Enum.reduce(yaml_files, {%{}, %{}}, fn file, {codes_acc, targets_acc} ->
        key = String.replace_suffix(file, ".yaml", "")
        full_path = deploy_dir |> Path.join("contracts") |> Path.join(file)

        %{"code" => code_id, "targets" => targets_list} = YamlElixir.read_from_file!(full_path)
        {Map.put(codes_acc, key, code_id), Map.put(targets_acc, key, targets_list)}
      end)

    # Load accounts.yaml separately
    accounts =
      deploy_dir
      |> Path.join("accounts.yaml")
      |> YamlElixir.read_from_file!()
      |> Map.fetch!("accounts")

    # Do accounts first, so they're available for contract interpolation
    %{accounts: parsed_accounts} = parse_ctx(%{accounts: accounts}, %{})

    parse_ctx(
      %{accounts: parsed_accounts, codes: codes, targets: targets},
      %{accounts: parsed_accounts, codes: codes, targets: targets}
    )
  end

  defp parse_protocol(codes, {protocol, configs}) do
    with {:ok, result} <-
           Rujira.Enum.reduce_async_while_ok(
             configs,
             &parse_contract(codes, protocol, &1)
           ) do
      result
    end
  end

  defp parse_contract(
         codes,
         protocol,
         %{
           "id" => id,
           "admin" => admin,
           "creator" => creator,
           "config" => config
         } = item
       ) do
    code_id = Map.get(codes, protocol)
    salt = build_address_salt(protocol, id)

    address =
      case Map.fetch(item, "address") do
        {:ok, value} -> value
        :error -> Contracts.build_address!(salt, creator, code_id)
      end

    %Target{
      id: id,
      address: address,
      creator: creator,
      code_id: code_id,
      salt: salt,
      admin: admin,
      protocol: protocol,
      module: to_module(protocol),
      config: config,
      contract: nil,
      status: :live
    }
  end

  def to_module("rujira-bow"), do: Bow
  def to_module("rujira-fin"), do: Fin.Pair
  def to_module("rujira-revenue"), do: Revenue.Converter
  def to_module("rujira-ghost-vault"), do: Ghost.Vault
  def to_module("rujira-ghost-credit"), do: Ghost.Credit
  def to_module("rujira-keiko"), do: Keiko
  def to_module("rujira-staking"), do: Staking.Pool
  def to_module("rujira-thorchain-swap"), do: Rujira.Thorchain.Swap
  def to_module("daodao-payroll-factory"), do: Vestings

  defp parse_ctx(map, ctx) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {k, parse_ctx(v, ctx)} end)
    |> Enum.into(%{})
  end

  defp parse_ctx(v, ctx) when is_list(v), do: Enum.map(v, &parse_ctx(&1, ctx))
  defp parse_ctx(v, ctx) when is_binary(v), do: interpolate_string(v, ctx)
  defp parse_ctx(v, _), do: v

  defp interpolate_string(str, ctx) do
    case Regex.run(~r/^\${(.*)}$/, str) do
      nil -> str
      [_, x] -> parse_arg(x, ctx)
    end
  end

  def parse_arg("targets:" <> id, %{targets: targets, codes: codes} = ctx) do
    [protocol, id] = String.split(id, ".")
    code_id = Map.get(codes, protocol)

    target_list = Map.get(targets, protocol, [])
    target = Enum.find(target_list, &(&1["id"] == id))

    target_map =
      case target do
        nil ->
          raise ArgumentError,
                "Unknown deployment target #{protocol}.#{id} referenced in configuration"

        map ->
          map
      end

    creator =
      target_map
      |> Map.get("creator")
      |> interpolate_string(ctx)

    case Map.get(target_map, "address") do
      nil ->
        protocol |> build_address_salt(id) |> Contracts.build_address!(creator, code_id)

      address ->
        interpolate_string(address, ctx)
    end
  end

  def parse_arg("accounts:" <> id, %{accounts: accounts}), do: Map.get(accounts, id)
  def parse_arg("env:" <> id, _), do: System.get_env(id)
  def parse_arg(x, _), do: x

  # Deployment straucture was updated, retain old format for backwards compatibility
  def build_address_salt("rujira-" <> protocol, id), do: Base.encode16("#{protocol}:#{id}")
  def build_address_salt("nami-" <> protocol, id), do: Base.encode16("#{protocol}:#{id}")
  def build_address_salt(protocol, id), do: Base.encode16("#{protocol}:#{id}")
end
