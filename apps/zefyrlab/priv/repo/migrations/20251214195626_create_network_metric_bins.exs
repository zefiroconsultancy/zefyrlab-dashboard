defmodule Zefyrlab.Repo.Migrations.CreateNetworkMetricBins do
  use Ecto.Migration

  def change do
    create table(:network_metric_bins, primary_key: false) do
      add :id, :string, null: false
      add :resolution, :string, null: false, primary_key: true
      add :bin, :utc_datetime, null: false, primary_key: true
      add :volume, :integer, null: false, default: 0
      add :tvl, :integer, null: false, default: 0
      add :utilization_ratio, :decimal, null: false, default: 0

      timestamps(type: :utc_datetime_usec, null: false)
    end

    create unique_index(:network_metric_bins, [:id])
  end
end
