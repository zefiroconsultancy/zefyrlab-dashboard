defmodule ZefyrlabWeb.Router do
  use ZefyrlabWeb, :router

  use MagicAuth.Router
  magic_auth("/auth", signed_in: "/", log_in: "/signup")

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZefyrlabWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    # MagicAuth recommends this in the router pipeline
    plug :fetch_magic_auth_session
  end

  scope "/", ZefyrlabWeb do
    pipe_through [:browser, :require_authenticated]

    live_session :authenticated,
      on_mount: [{MagicAuth, :require_authenticated}, {ZefyrlabWeb.Layouts, :default}] do
      live "/", DashboardLive.Index, :index
    end
  end

  # Catch-all 404 for authenticated scope
  scope "/", ZefyrlabWeb do
    pipe_through [:browser]

    match :*, "/*path", FallbackController, :not_found
  end

  if Application.compile_env(:zefyrlab_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: ZefyrlabWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
