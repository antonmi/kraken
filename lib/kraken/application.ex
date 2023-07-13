defmodule Kraken.Application do
  @moduledoc false

  alias Kraken.Configs
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: Kraken.Api.Router, options: [port: Configs.port()]}
    ]

    :ok = Kraken.ProjectStart.run()

    opts = [strategy: :one_for_one, name: Kraken.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
