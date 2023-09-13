defmodule Kraken.MixProject do
  use Mix.Project

  def project do
    [
      app: :kraken,
      version: "0.3.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: "https://github.com/antonmi/kraken",
      deps: deps()
    ]
  end

  def application do
    [
      env: [
        pipelines_namespace: Kraken.Pipelines,
        project_start: false,
        host: "localhost",
        port: 4001
      ],
      extra_applications: [:logger],
      mod: {Kraken.Application, []}
    ]
  end

  defp description do
    "Flow-based System Orchestration Framework"
  end

  defp package do
    [
      files: ~w(lib mix.exs README.md),
      maintainers: ["Anton Mishchuk"],
      licenses: ["MIT"],
      links: %{"github" => "https://github.com/antonmi/kraken"}
    ]
  end

  defp deps do
    [
      {:alf, "0.9.0"},
      {:octopus, "0.5.1"},
      {:plug_cowboy, "~> 2.5"},
      {:finch, "~> 0.16"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end
end
