[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["apps/*/priv/*/migrations"],
  plugins: [],
  inputs: [
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "apps/*/mix.exs",
    "apps/*/{config,lib,test}/**/*.{heex,ex,exs}",
    "apps/*/priv/*/seeds.exs"
  ]
]
