defmodule Kraken.MixProject do
  use Mix.Project

  def project do
    [
      app: :kraken,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Kraken.Application, []}
    ]
  end

  defp deps do
    [
      {:alf, path: "/Users/anton.mishchukkloeckner.com/elixir/alf"},
      {:octopus, path: "/Users/anton.mishchukkloeckner.com/elixir/octopus/apps/octopus"}
    ]
  end
end
