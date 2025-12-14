defmodule Rujira.Fin.Book do
  @moduledoc """
  Parses and represents a FIN.Book from blockchain data.
  """

  defmodule Price do
    @moduledoc """
    Represents a price level in the order book with associated order details.
    """
    defstruct [:price, :total, :side, :value, :virtual_total, :virtual_value]

    @type side :: :bid | :ask
    @type t :: %__MODULE__{
            price: Decimal.t(),
            total: non_neg_integer(),
            side: side,
            value: non_neg_integer(),
            virtual_total: non_neg_integer(),
            virtual_value: non_neg_integer()
          }

    @spec from_query(side, map()) :: t() | {:error, :parse_error}
    def from_query(side, %{"price" => price_str, "total" => total_str}) do
      with {price, ""} <- Decimal.parse(price_str),
           {total, ""} <- Integer.parse(total_str) do
        %__MODULE__{
          side: side,
          total: total,
          price: price,
          value: value(side, price, total),
          virtual_total: 0,
          virtual_value: 0
        }
      else
        _ -> {:error, :parse_error}
      end
    end

    def from_swap(0, _, _), do: :error
    def from_swap(_, 0, _), do: :error

    def from_swap(bid, ask, side) do
      ask = round(ask * (1 - 0.0015))

      price =
        case side do
          :bid -> Decimal.div(Decimal.new(ask), Decimal.new(bid))
          :ask -> Decimal.div(Decimal.new(bid), Decimal.new(ask))
        end

      {:ok,
       %__MODULE__{
         price: price,
         side: side,
         total: 0,
         value: 0,
         virtual_total: ask,
         virtual_value: Price.value(side, price, ask)
       }}
    end

    def value(:ask, price, total) do
      total
      |> Decimal.new()
      |> Decimal.mult(price)
      |> Decimal.round(0, :floor)
      |> Decimal.to_integer()
    end

    def value(:bid, price, total) do
      total
      |> Decimal.new()
      |> Decimal.div(price)
      |> Decimal.round(0, :floor)
      |> Decimal.to_integer()
    end
  end

  defstruct [:id, :bids, :asks, :center, :spread]

  @type t :: %__MODULE__{
          id: String.t(),
          bids: list(Price.t()),
          asks: list(Price.t()),
          center: Decimal.t(),
          spread: Decimal.t()
        }

  @spec from_query(String.t(), map()) :: {:ok, __MODULE__.t()}
  def from_query(address, %{
        "base" => asks,
        "quote" => bids
      }) do
    {:ok,
     %__MODULE__{
       id: address,
       asks: Enum.map(asks, &Price.from_query(:ask, &1)),
       bids: Enum.map(bids, &Price.from_query(:bid, &1)),
       center: Decimal.new(0),
       spread: Decimal.new(0)
     }
     |> populate()}
  end

  def empty(address) do
    %__MODULE__{id: address, bids: [], asks: [], center: Decimal.new(0), spread: Decimal.new(0)}
  end

  def from_target(address), do: empty(address)

  def populate(%__MODULE__{asks: [ask | _], bids: [bid | _]} = book) do
    center =
      ask.price
      |> Decimal.add(bid.price)
      |> Decimal.div(Decimal.new(2))

    %{
      book
      | center: center,
        spread: ask.price |> Decimal.sub(bid.price) |> Decimal.div(center)
    }
  end

  def populate(book), do: book
end
