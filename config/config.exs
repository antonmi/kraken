import Config

config :kraken,
  pipelines_namespace: Kraken.Pipelines,
  project_start: false


config :alf,
       default_timeout: 20_000
