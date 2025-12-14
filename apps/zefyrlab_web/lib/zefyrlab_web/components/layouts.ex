defmodule ZefyrlabWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """

  use ZefyrlabWeb, :html

  import ZefyrlabWeb.CoreComponents

  embed_templates "layouts/*"

  @doc """
  on_mount callback to set current_user_email in socket assigns.
  This makes the email available to all layouts.
  """
  def on_mount(:default, _params, session, socket) do
    {:cont, Phoenix.Component.assign(socket, :current_user_email, session["email"])}
  end
end
