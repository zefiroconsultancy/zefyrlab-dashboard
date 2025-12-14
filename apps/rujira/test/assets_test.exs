defmodule Rujira.AssetsTest do
  use ExUnit.Case, async: true

  alias Rujira.Assets

  describe "from_denom/1 ticker extraction for credit account assets" do
    test "extracts ticker from BTC collateral denom" do
      {:ok, asset} = Assets.from_denom("btc-btc")
      assert asset.ticker == "BTC"
      assert asset.chain == "BTC"
      assert asset.type == :secured
    end

    test "extracts ticker from ETH collateral denom" do
      {:ok, asset} = Assets.from_denom("eth-eth")
      assert asset.ticker == "ETH"
      assert asset.chain == "ETH"
      assert asset.type == :secured
    end

    test "extracts ticker from BNB collateral denom" do
      {:ok, asset} = Assets.from_denom("bsc-bnb")
      assert asset.ticker == "BNB"
      assert asset.chain == "BSC"
      assert asset.type == :secured
    end

    test "extracts ticker from USDC debt denom (with contract address)" do
      {:ok, asset} = Assets.from_denom("eth-usdc-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
      assert asset.ticker == "USDC"
      assert asset.chain == "ETH"
      assert asset.symbol == "USDC-0XA0B86991C6218B36C1D19D4A2E9EB0CE3606EB48"
      assert asset.type == :secured
    end

    test "extracts ticker from USDT debt denom (with contract address)" do
      {:ok, asset} = Assets.from_denom("eth-usdt-0xdac17f958d2ee523a2206206994597c13d831ec7")
      assert asset.ticker == "USDT"
      assert asset.chain == "ETH"
      assert asset.symbol == "USDT-0XDAC17F958D2EE523A2206206994597C13D831EC7"
      assert asset.type == :secured
    end

    test "extracts ticker from native RUNE denom" do
      {:ok, asset} = Assets.from_denom("rune")
      assert asset.ticker == "RUNE"
      assert asset.chain == "THOR"
      assert asset.symbol == "RUNE"
      assert asset.type == :native
    end

    test "extracts ticker from native RUJI denom" do
      {:ok, asset} = Assets.from_denom("x/ruji")
      assert asset.ticker == "RUJI"
      assert asset.chain == "THOR"
      assert asset.symbol == "RUJI"
      assert asset.type == :native
    end

    test "extracts ticker from thor prefixed native token" do
      {:ok, asset} = Assets.from_denom("thor.auto")
      assert asset.ticker == "AUTO"
      assert asset.chain == "THOR"
      assert asset.symbol == "AUTO"
      assert asset.type == :native
    end

    test "handles invalid denom format" do
      result = Assets.from_denom("invalid")
      assert {:error, _} = result
    end
  end

  describe "ticker vs symbol for oracle price matching" do
    test "ticker is suitable for oracle price matching (short form)" do
      # Oracle prices come as "BTC", "USDC", "ETH", etc.
      # ticker should match these symbols
      {:ok, btc} = Assets.from_denom("btc-btc")
      {:ok, usdc} = Assets.from_denom("eth-usdc-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
      {:ok, eth} = Assets.from_denom("eth-eth")

      # Verify ticker is the short symbol that oracle would use
      assert btc.ticker == "BTC"
      assert usdc.ticker == "USDC"
      assert eth.ticker == "ETH"

      # Full symbol would be too long/specific for oracle matching
      assert btc.symbol == "BTC"
      assert usdc.symbol == "USDC-0XA0B86991C6218B36C1D19D4A2E9EB0CE3606EB48"
      assert eth.symbol == "ETH"
    end
  end
end
