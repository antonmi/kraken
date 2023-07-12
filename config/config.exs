import Config

config :kraken,
  pipelines_namespace: Kraken.Pipelines,
  project_start: [
    kraken_folder: "lib/kraken",
    define_services: true,
    start_services: true,
    define_pipelines: true,
    start_pipelines: true,
    define_routes: true
  ]
