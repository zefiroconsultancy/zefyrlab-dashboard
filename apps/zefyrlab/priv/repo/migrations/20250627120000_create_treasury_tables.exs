defmodule Zefyrlab.Repo.Migrations.CreateTreasuryTables do
  use Ecto.Migration

  def change do
    create table(:treasury_bins, primary_key: false) do
      add :id, :string, null: false
      add :bin, :utc_datetime, primary_key: true, null: false
      add :resolution, :string, primary_key: true, null: false

      add :rune_usd_price, :decimal, null: false, default: 0

      add :bonded_rune, :bigint, null: false, default: 0
      add :wallet_rune, :bigint, null: false, default: 0
      add :total_rune, :bigint, null: false, default: 0

      add :bonded_rune_usd, :decimal, null: false, default: 0
      add :wallet_rune_usd, :decimal, null: false, default: 0
      add :total_rune_usd, :decimal, null: false, default: 0

      add :capital_inflows_rune, :bigint, null: false, default: 0
      add :revenue_inflows_rune, :bigint, null: false, default: 0
      add :cost_outflows_rune, :bigint, null: false, default: 0

      add :capital_inflows_usd, :decimal, null: false, default: 0
      add :revenue_inflows_usd, :decimal, null: false, default: 0
      add :cost_outflows_usd, :decimal, null: false, default: 0

      add :net_inflows_rune, :bigint, null: false, default: 0
      add :net_cashflow_rune, :bigint, null: false, default: 0
      add :net_change_assets_rune, :bigint, null: false, default: 0

      add :net_inflows_usd, :decimal, null: false, default: 0
      add :net_cashflow_usd, :decimal, null: false, default: 0
      add :net_change_assets_usd, :decimal, null: false, default: 0

      timestamps(type: :utc_datetime_usec, null: false)
    end

    create unique_index(:treasury_bins, [:id])
    create unique_index(:treasury_bins, [:resolution, :bin])

    create table(:thorchain_node_reward_cursors, primary_key: false) do
      add :node_address, :string, primary_key: true
      add :last_award_rune, :decimal, null: false, default: 0
      timestamps(type: :utc_datetime_usec, null: false)
    end
  end
end
