defmodule Zefyrlab.Repo do
  use Ecto.Repo,
    otp_app: :zefyrlab,
    adapter: Ecto.Adapters.Postgres
end
