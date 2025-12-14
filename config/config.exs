# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Zefyrlab (data/indexer) configuration
config :zefyrlab,
  ecto_repos: [Zefyrlab.Repo],
  generators: [timestamp_type: :utc_datetime]

config :zefyrlab, Zefyrlab.Repo,
  database: "zefyrlab_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

# ZefyrlabWeb (frontend) configuration
config :zefyrlab_web, ZefyrlabWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ZefyrlabWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: ZefyrlabWeb.PubSub,
  live_view: [signing_salt: "zefyrlab_web_salt"]

config :zefyrlab_web,
  ecto_repos: [Zefyrlab.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  zefyrlab_web: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/zefyrlab_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  zefyrlab_web: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/zefyrlab_web/assets", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :rujira, :task_supervisor, Zefyrlab.TaskSupervisor

# Zefyrlab.Node configuration
config :zefyrlab, Zefyrlab.Node,
  grpc: "15.204.109.101:9090",
  websocket: "ws://15.204.109.101:27147",
  subscriptions: ["tm.event='NewBlock'"],
  query_pool: [
    size: 4,
    max_overflow: 4
  ],
  tx_pool: [
    size: 1,
    max_overflow: 1
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Cosmos SDK configuration
config :cosmos,
  hrp: "thor",
  chain_id: "thorchain-1",
  node: Zefyrlab.Node

config :memoize,
  cache_strategy: Cosmos.CacheStrategy

config :memoize, Cosmos.CacheStrategy,
  min_threshold: 64 * 1024 * 1024,
  max_threshold: 128 * 1024 * 1024

network = System.get_env("NETWORK", "stagenet")

config :rujira, :network, network

# Mailer configuration
config :zefyrlab, Zefyrlab.Mailer, adapter: Swoosh.Adapters.Local

# Magic Auth configuration
config :magic_auth,
  callbacks: ZefyrlabWeb.MagicAuth,
  repo: Zefyrlab.Repo,
  router: ZefyrlabWeb.Router,
  endpoint: ZefyrlabWeb.Endpoint,
  remember_me_cookie: "_zefyrlab_web_remember_me"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
