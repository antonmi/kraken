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
end
