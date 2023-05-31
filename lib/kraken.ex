defmodule Kraken do
  alias Kraken.Pipelines

  @spec call(map()) :: map() | list(map()) | {:error, any()}
  def call(args, opts \\ %{}) when is_map(args) do
    with {:ok, type} <- fetch_type(args),
         {:ok, pipeline} <- get_route(type) do
      Pipelines.call(pipeline, args, opts)
    else
      {:error, error} ->
        {:error, error}
    end
  end

  # def call for list -> groupes by type and calls in tasks

  defp fetch_type(args) do
    case Map.get(args, "type") do
      nil ->
        {:error, :no_type}

      type ->
        {:ok, type}
    end
  end

  defp get_route(type) do
    with {:ok, routes} <- Kraken.Routes.all(),
         pipeline when is_binary(pipeline) <- Map.get(routes, type) do
      {:ok, pipeline}
    else
      nil ->
        {:error, :no_route_for_type}

      {:error, :no_routes} ->
        {:error, :no_routes}
    end
  end
end
