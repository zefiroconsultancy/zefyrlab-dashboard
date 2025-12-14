defmodule Zefyrlab.Resolution do
  @moduledoc """
  Handles time resolution and date/time manipulation for the Zefyrlab application.
  """

  @resolutions ["1D", "1M", "12M"]
  def resolutions, do: @resolutions

  def active(now) do
    Enum.map(@resolutions, &{&1, truncate(now, &1)})
  end

  def add(%DateTime{} = datetime, resolution) do
    case Integer.parse(resolution) do
      {minutes, ""} ->
        DateTime.add(datetime, minutes, :minute)

      {days, "D"} ->
        DateTime.add(datetime, days, :day)

      {months, "M"} ->
        shift_datetime_by_months(datetime, months)
    end
  end

  defp shift_datetime_by_months(%DateTime{} = dt, months) when is_integer(months) do
    # Shift on the date component (calendar-aware), then rebuild DateTime in UTC.
    date = DateTime.to_date(dt)
    time = DateTime.to_time(dt)

    shifted_date = shift_date_by_months_clamped(date, months)

    {:ok, new_dt} = DateTime.new(shifted_date, time, "Etc/UTC")
    new_dt
  end

  defp shift_date_by_months_clamped(%Date{} = date, months) do
    # Compute target year/month, then clamp day to last day of target month.
    m0 = date.month + months

    {year, month} =
      cond do
        m0 > 0 ->
          years = div(m0 - 1, 12)
          {date.year + years, rem(m0 - 1, 12) + 1}

        true ->
          years = div(m0, 12) - 1
          {date.year + years, 12 + rem(m0, 12)}
      end

    last_day = :calendar.last_day_of_the_month(year, month)
    day = min(date.day, last_day)

    Date.new!(year, month, day)
  end

  def remove(%DateTime{} = datetime, resolution) do
    datetime
    |> DateTime.add(-1)
    |> truncate(resolution)
  end

  def truncate(%DateTime{} = datetime, "1") do
    d = DateTime.truncate(datetime, :second)
    %{d | second: 0}
  end

  def truncate(%DateTime{} = datetime, "3"),
    do: datetime |> truncate("1") |> Map.update!(:minute, &(&1 - rem(&1, 3)))

  def truncate(%DateTime{} = datetime, "5"),
    do: datetime |> truncate("1") |> Map.update!(:minute, &(&1 - rem(&1, 5)))

  def truncate(%DateTime{} = datetime, "15"),
    do: datetime |> truncate("1") |> Map.update!(:minute, &(&1 - rem(&1, 15)))

  def truncate(%DateTime{} = datetime, "30"),
    do: datetime |> truncate("1") |> Map.update!(:minute, &(&1 - rem(&1, 30)))

  def truncate(%DateTime{} = datetime, "60"),
    do: datetime |> truncate("1") |> Map.put(:minute, 0)

  def truncate(%DateTime{} = datetime, "120"),
    do: datetime |> truncate("60") |> Map.update!(:hour, &(&1 - rem(&1, 2)))

  def truncate(%DateTime{} = datetime, "180"),
    do: datetime |> truncate("60") |> Map.update!(:hour, &(&1 - rem(&1, 3)))

  def truncate(%DateTime{} = datetime, "240"),
    do: datetime |> truncate("60") |> Map.update!(:hour, &(&1 - rem(&1, 4)))

  def truncate(%DateTime{} = datetime, "1D"),
    do: datetime |> truncate("60") |> Map.put(:hour, 0)

  def truncate(%DateTime{} = datetime, "1M"),
    do: datetime |> truncate("1D") |> Map.put(:day, 1)

  def truncate(%DateTime{} = datetime, "12M"),
    do: datetime |> truncate("1M") |> Map.put(:month, 1)

  # To be moved in Analytics.Common mainly used to shift date in order to calculate moving avgs
  def shift_from_back(from, period, "1D"), do: DateTime.add(from, -period, :day)

  def shift_from_back(from, period, "1M") do
    m_shift = rem(period, 12)
    y_shift = div(period, 12)

    {year, month} =
      if from.month < m_shift do
        {from.year - y_shift - 1, 12 + from.month - m_shift}
      else
        {from.year - y_shift, from.month - m_shift}
      end

    %{from | year: year, month: month}
  end

  def shift_from_back(from, period, "12M"), do: from |> Map.update!(:year, &(&1 - period))

  def shift_from_back(from, period, resolution),
    do: DateTime.add(from, -period * resolution, :minute)
end
