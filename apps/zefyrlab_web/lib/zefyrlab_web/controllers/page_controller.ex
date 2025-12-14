defmodule ZefyrlabWeb.PageController do
  use ZefyrlabWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
