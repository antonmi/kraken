defmodule Kraken.Define.RoutingTable do
  alias Kraken.Utils

  @spec define(map()) :: {:ok, Kraken.RoutingTable}
  def define(routes) when is_map(routes) do
    template()
    |> EEx.eval_string(
      module: Kraken.RoutingTable,
      routes: routes
    )
    |> Utils.eval_code()
    |> case do
      {:ok, _code} ->
        {:ok, Kraken.RoutingTable}
    end
  end

  defp template() do
    """
      defmodule <%= module %> do
        @routes "<%= Base.encode64(:erlang.term_to_binary(routes)) %>"
                |> Base.decode64!()
                |> :erlang.binary_to_term()

        def routes, do: @routes

        def route(key), do: Map.get(@routes, key)
      end
    """
  end
end
