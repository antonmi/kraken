defmodule Kraken.Configs do
  def pipelines_namespace do
    case Application.get_env(:kraken, :pipelines_namespace) do
      nil ->
        "Kraken.Pipelines"

      namespace when is_atom(namespace) ->
        String.replace("#{namespace}", "Elixir.", "")

      namespace when is_binary(namespace) ->
        namespace
    end
  end

  def host do
    case Application.get_env(:kraken, :host) do
      nil ->
        "localhost"

      host when is_binary(host) ->
        host
    end
  end

  def port do
    case Application.get_env(:kraken, :port) do
      nil ->
        String.to_integer(System.get_env("KRAKEN_PORT") || "4001")

      port when is_integer(port) ->
        port
    end
  end
end
