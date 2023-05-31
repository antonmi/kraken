defmodule Kraken.Routes do
  alias Kraken.Define.RoutingTable

  @spec define(String.t()) :: {:ok, String.t()} | {:error, any()}
  def define(definition) when is_binary(definition) do
    definition
    |> Jason.decode!()
    |> define()
  end

  @spec define(map()) :: {:ok, String.t()} | {:error, any()}
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
end
