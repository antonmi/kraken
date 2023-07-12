defmodule Kraken.Routes do
  alias Kraken.Define.RoutingTable

  @spec define(String.t()) :: {:ok, Kraken.RoutingTable} | {:error, any()}
  def define(definition) when is_binary(definition) do
    definition
    |> Jason.decode!()
    |> define()
  end

  @spec define(map()) :: {:ok, Kraken.RoutingTable} | {:error, any()}
  def define(definition) when is_map(definition) do
    RoutingTable.define(definition)
  end

  @spec all() :: {:ok, map()} | {:error, any()}
  def all() do
    {:ok, apply(Kraken.RoutingTable, :routes, [])}
  rescue
    UndefinedFunctionError ->
      {:error, :no_routes}
  end

  @spec delete() :: :ok
  def delete() do
    :code.soft_purge(Kraken.RoutingTable)
    :code.delete(Kraken.RoutingTable)
    :ok
  end
end
