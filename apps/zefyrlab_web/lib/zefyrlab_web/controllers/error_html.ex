defmodule ZefyrlabWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use ZefyrlabWeb, :html
  alias ZefyrlabWeb.Layouts

  embed_templates "error_html/*"

  def render("404.html", assigns), do: apply(__MODULE__, :"404", [assigns])
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
