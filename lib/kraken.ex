defmodule Kraken do
  alias Kraken.Pipelines

  def call(events, opts \\ %{})

  @spec call(map()) :: map() | {:error, any()}
  def call(event, opts) when is_map(event) do
    case pipeline_ready_for_event(event) do
      {:ok, pipeline} -> Pipelines.call(pipeline, event, opts)
      {:error, error} -> {:error, error}
    end
  end

  @spec call(list(map())) :: list(map() | {:error, any()}) | {:error, any()}
  def call(events, opts) when is_list(events) do
    cast_or_call_for_list(:call, events, opts)
  end

  def cast(events, opts \\ %{})

  @spec cast(map(), map()) :: reference() | list(reference()) | {:error, any()}
  def cast(event, opts) when is_map(event) do
    case pipeline_ready_for_event(event) do
      {:ok, pipeline} ->
        Pipelines.cast(pipeline, event, opts)

      {:error, error} ->
        {:error, error}
    end
  end

  @spec cast(list(map()), map()) :: reference() | list(reference()) | {:error, any()}
  def cast(events, opts) when is_list(events) do
    cast_or_call_for_list(:cast, events, opts)
  end

  @spec stream(list(map()), map()) :: Enumerable.t() | {:error, any()}
  def stream(events, opts \\ %{}) when is_list(events) do
    streams =
      events
      |> Enum.group_by(&Map.get(&1, "type"))
      |> Enum.map(fn {_type, events} ->
        case pipeline_ready_for_event(hd(events)) do
          {:ok, pipeline} ->
            do_call_pipeline(pipeline, :stream, events, opts)

          {:error, error} ->
            Stream.map(events, fn _event -> {:error, error} end)
        end
      end)

    run_streams(streams, pid)
    build_output_stream(length(streams))
  end

  defp pipeline_ready_for_event(event) do
    with {:ok, type} <- fetch_type(event),
         {:ok, pipeline} <- get_route(type),
         :ready <- Pipelines.ready?(pipeline) do
      {:ok, pipeline}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp cast_or_call_for_list(action, events, opts) do
    events
    |> Enum.group_by(&Map.get(&1, "type"))
    |> Enum.map(fn {_type, events} ->
      case pipeline_ready_for_event(hd(events)) do
        {:ok, pipeline} ->
          {:task, Task.async(fn -> do_call_pipeline(pipeline, action, events, opts) end)}

        {:error, error} ->
          Enum.map(events, fn _event -> {:error, error} end)
      end
    end)
    |> Enum.map(fn
      {:task, task} -> Task.await(task, :infinity)
      errors -> errors
    end)
    |> List.flatten()
  end

  defp do_call_pipeline(pipeline, action, events, opts) when is_list(events) do
    apply(Pipelines, action, [pipeline, events, opts])
  end

  defp run_streams(streams, pid) do
    Enum.each(streams, fn stream ->
      Task.async(fn ->
        Enum.each(stream, &send(pid, {:event, &1}))
        send(pid, :done)
      end)
    end)
  end

  defp build_output_stream(streams_count) do
    Stream.resource(
      fn -> streams_count end,
      fn left ->
        if left > 0 do
          receive do
            {:event, event} -> {[event], left}
            :done -> {[], left - 1}
          end
        else
          {:halt, 0}
        end
      end,
      fn 0 -> :ok end
    )
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
