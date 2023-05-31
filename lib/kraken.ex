defmodule Kraken do
  alias Kraken.Pipelines

  def call(events, opts \\ %{})

  @spec call(map()) :: map() | {:error, any()}
  def call(event, opts) when is_map(event) do
    with {:ok, type} <- fetch_type(event),
         {:ok, pipeline} <- get_route(type) do
      Pipelines.call(pipeline, event, opts)
    else
      {:error, error} ->
        {:error, error}
    end
  end

  @spec call(list(map())) :: list(map() | {:error, any()}) | {:error, any()}
  def call(events, opts) when is_list(events) do
    cast_or_call_for_list(:call, events, opts)
  end

  def cast(events, opts \\ %{})

  @spec cast(map(), map()) :: reference() | list(reference()) | {:error, any()}
  def cast(event, opts) when is_map(event) do
    with {:ok, type} <- fetch_type(event),
         {:ok, pipeline} <- get_route(type) do
      Pipelines.cast(pipeline, event, opts)
    else
      {:error, error} ->
        {:error, error}
    end
  end

  @spec cast(list(map()), map()) :: reference() | list(reference()) | {:error, any()}
  def cast(events, opts) when is_list(events) do
    cast_or_call_for_list(:cast, events, opts)
  end

  defp cast_or_call_for_list(action, events, opts) do
    events
    |> Enum.group_by(&Map.get(&1, "type"))
    |> Enum.map(fn {_type, events} ->
      Task.async(fn -> call_or_cast_many(action, events, opts) end)
    end)
    |> Enum.map(&Task.await(&1, :infinity))
    |> List.flatten()
  end

  defp call_or_cast_many(action, events, opts) when is_list(events) do
    event = List.first(events)

    with {:ok, type} <- fetch_type(event),
         {:ok, pipeline} <- get_route(type) do
      apply(Pipelines, action, [pipeline, events, opts])
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp fetch_type(event) do
    case Map.get(event, "type") do
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
