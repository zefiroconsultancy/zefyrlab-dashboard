defmodule ZefyrlabWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """

  use ZefyrlabWeb, :html

  import ZefyrlabWeb.CoreComponents

  embed_templates "layouts/*"
end
