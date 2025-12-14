defmodule ZefyrlabWeb.FallbackController do
  use ZefyrlabWeb, :controller

  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_root_layout({ZefyrlabWeb.Layouts, :root})
    |> put_layout(false)
    |> put_view(ZefyrlabWeb.ErrorHTML)
    |> render(:"404")
  end
end
