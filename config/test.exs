import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :zefyrlab, Zefyrlab.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "zefyrlab_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :zefyrlab, ZefyrlabWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LQFBLC9iH9WxQSyL6CSwY2U0AdOMnu7TwAGwldwXX2qmoEuDMnRSeDL3qSkFMEzX",
  server: false

# In test we don't send emails
config :zefyrlab, Zefyrlab.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Zefyrlab.Node configuration
config :zefyrlab, Zefyrlab.Node,
  websocket: "wss://stagenet-rpc.ninerealms.com",
  grpc: "stagenet-grpc.ninerealms.com:443",
  subscriptions: ["tm.event='NewBlock'"],
  poolboy: [
    size: 20,
    max_overflow: 10
  ]

# Use stagenet hrp and chain for tests
config :cosmos,
  hrp: "sthor",
  chain_id: "thorchain-stagenet-v2"
