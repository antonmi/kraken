defmodule Kraken.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: Kraken.Api.Router, options: [port: port()]}
    ]

    :ok = Kraken.ProjectStart.run()

    opts = [strategy: :one_for_one, name: Kraken.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port() do
    (System.get_env("KRAKEN_PORT") || "4001")
    |> String.to_integer()
  end
end
