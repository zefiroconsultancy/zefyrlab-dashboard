defmodule Rujira.Keiko.Tokenomics.Stream do
  @moduledoc """
  This module provides the type definition and parsing logic for a Tokenomics stream used by the Keiko deployment orchestrator.
  """

  alias Rujira.Vestings.Type.PiecewiseLinear
  alias Rujira.Vestings.Type.SaturatingLinear

  defstruct [
    :owner,
    :recipient,
    :title,
    :total,
    :denom,
    :start_time,
    :schedule,
    :cliff_in_seconds,
    :cliff_time,
    :end_time
  ]

  @type t :: %__MODULE__{
          owner: String.t() | nil,
          recipient: String.t(),
          title: String.t(),
          total: non_neg_integer(),
          denom: String.t(),
          start_time: DateTime.t(),
          schedule: String.t(),
          cliff_in_seconds: non_neg_integer(),
          cliff_time: DateTime.t(),
          end_time: DateTime.t()
        }

  def from_query(%{
        "owner" => owner,
        "recipient" => recipient,
        "title" => title,
        "total" => total,
        "denom" => %{"native" => denom},
        "start_time" => start_time,
        "schedule" => schedule,
        "vesting_duration_seconds" => vesting_duration_seconds
      }) do
    with {total, ""} <- Integer.parse(total),
         {start_time, ""} <- Integer.parse(start_time),
         {:ok, start_date} <- DateTime.from_unix(start_time, :nanosecond),
         {:ok, {_, schedule}} <- parse_schedule(schedule, total, vesting_duration_seconds) do
      {cliff, end_date} = calculate_cliff_and_end_date(start_date, schedule)

      {:ok,
       %__MODULE__{
         owner: owner,
         recipient: recipient,
         title: title,
         total: total,
         denom: denom,
         start_time: start_date,
         schedule: schedule,
         cliff_in_seconds: cliff,
         cliff_time: DateTime.add(start_date, cliff, :second),
         end_time: end_date
       }}
    end
  end

  def parse_schedule(%{"piecewise_linear" => schedule}, _, _) do
    PiecewiseLinear.from_config(%{"steps" => schedule})
  end

  def parse_schedule("saturating_linear", total, vesting_duration_seconds),
    do:
      SaturatingLinear.from_config(%{
        "max_x" => vesting_duration_seconds,
        "max_y" => Integer.to_string(total),
        "min_x" => 0,
        "min_y" => "0"
      })

  def calculate_cliff_and_end_date(start_date, %SaturatingLinear{} = schedule) do
    end_date = DateTime.add(start_date, schedule.max_x, :second)
    {0, end_date}
  end

  def calculate_cliff_and_end_date(start_date, %PiecewiseLinear{steps: steps}) do
    cliff = Map.get(Enum.at(steps, 0), :seconds)
    end_time_in_seconds = Map.get(Enum.at(steps, length(steps) - 1), :seconds)

    end_time = DateTime.add(start_date, end_time_in_seconds, :second)
    {cliff, end_time}
  end
end
