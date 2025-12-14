defmodule Rujira.Vestings.Type do
  @moduledoc "
  A struct that represents a vesting schedule logic.
  "

  defmodule PiecewiseLinear do
    @moduledoc false
    defstruct [:steps]

    defmodule Step do
      @moduledoc false
      defstruct [:seconds, :amount]
    end

    def from_config(%{"steps" => steps}) do
      steps = Enum.map(steps, &parse_step/1)

      last = Enum.at(steps, length(steps) - 1)

      {:ok,
       {last.amount,
        %__MODULE__{
          steps: steps
        }}}
    end

    defp parse_step([seconds, amount]) do
      with {amount, ""} <- Integer.parse(amount) do
        %Step{
          seconds: seconds,
          amount: amount
        }
      end
    end
  end

  defmodule SaturatingLinear do
    @moduledoc false
    defstruct [:max_x, :max_y, :min_x, :min_y]

    def from_config(%{"max_x" => max_x, "max_y" => max_y, "min_x" => min_x, "min_y" => min_y}) do
      with {max_y, ""} <- Integer.parse(max_y),
           {min_y, ""} <- Integer.parse(min_y) do
        {:ok,
         {max_y,
          %__MODULE__{
            max_x: max_x,
            max_y: max_y,
            min_x: min_x,
            min_y: min_y
          }}}
      end
    end
  end
end
