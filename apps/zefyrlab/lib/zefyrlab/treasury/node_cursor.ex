defmodule Zefyrlab.Treasury.NodeCursor do
  @moduledoc """
  Stores last seen node reward counters to support delta accounting.
  """

  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Zefyrlab.Repo

  @primary_key {:node_address, :string, []}
  schema "thorchain_node_reward_cursors" do
    field(:last_award_rune, :decimal)

    timestamps(type: :utc_datetime_usec)
  end

  def delta_and_update(node_address, current_award) do
    Repo.transaction(fn ->
      cursor =
        __MODULE__
        |> where(node_address: ^node_address)
        |> lock("FOR UPDATE")
        |> Repo.one()

      last = (cursor && cursor.last_award_rune) || Decimal.new(0)
      current = Decimal.new(current_award || 0)

      earned =
        current
        |> Decimal.sub(last)
        |> Decimal.max(Decimal.new(0))
        |> Decimal.round(0, :floor)
        |> Decimal.to_integer()

      changeset =
        (cursor || %__MODULE__{node_address: node_address})
        |> changeset(%{last_award_rune: current})

      Repo.insert!(
        changeset,
        on_conflict: [set: [last_award_rune: current, updated_at: DateTime.utc_now()]],
        conflict_target: :node_address
      )

      earned
    end)
    |> case do
      {:ok, earned} -> {:ok, earned}
      error -> error
    end
  end

  defp changeset(cursor, attrs) do
    cursor
    |> cast(attrs, [:node_address, :last_award_rune])
    |> validate_required([:node_address, :last_award_rune])
  end
end
