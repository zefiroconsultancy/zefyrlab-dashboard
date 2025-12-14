defmodule ZefyrlabWeb.DashboardLive.Index do
  use ZefyrlabWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    email = session["email"]

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:email, email)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto mt-8">
      <h1 class="text-3xl font-bold mb-4">Zefyr Labs Dashboard</h1>
      <p class="text-gray-600 mb-8">
        Logged in as: <span class="font-mono text-brand"><%= @email %></span>
      </p>

      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold mb-4">Welcome!</h2>
        <p>Your authenticated dashboard is ready.</p>
      </div>

            <.link
        href={~p"/auth/log_out"}
        method="delete"
        class="ml-auto inline-flex items-center rounded-md bg-zinc-900 px-3 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
      >
        Log out
      </.link>
    </div>
    """
  end
end
