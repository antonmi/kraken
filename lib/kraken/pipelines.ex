defmodule Kraken.Pipelines do
  alias Kraken.{Configs, Utils}
  alias Kraken.Define.Pipeline

  @spec define(String.t()) :: {:ok, String.t()} | {:error, any()}
  def define(definition) when is_binary(definition) do
    definition
    |> Jason.decode!()
    |> define()
  end

  @spec define(map()) :: {:ok, String.t()} | {:error, any()}
  def define(definition) when is_map(definition) do
    name = definition["name"] || "Pipeline must have name!"

    case status(name) do
      :undefined ->
        Pipeline.define(definition)

      :not_ready ->
        Pipeline.define(definition)

      :ready ->
        {:error, :already_started}
    end
  rescue
    error ->
      {:error, error}
  end

  @spec status(String.t()) :: :undefined | :not_ready | :ready
  def status(pipeline_name) when is_binary(pipeline_name) do
    case build_module(pipeline_name) do
      {:ok, module} ->
        case module.started?() do
          true -> :ready
          false -> :not_ready
        end

      {:error, :not_found} ->
        :undefined
    end
  end

  @spec definition(String.t()) :: {:ok, map()} | {:error, any}
  def definition(pipeline_name) do
    case status(pipeline_name) do
      :undefined ->
        {:error, :undefined}

      :not_ready ->
        {:ok, module} = build_module(pipeline_name)
        {:ok, apply(module, :definition, [])}

      :ready ->
        {:ok, module} = build_module(pipeline_name)
        {:ok, apply(module, :definition, [])}
    end
  end

  @spec pipelines :: list(String.t())
  def pipelines do
    :code.all_loaded()
    |> Enum.map(&Atom.to_string(elem(&1, 0)))
    |> Enum.filter(&String.starts_with?(&1, "Elixir.#{Configs.pipelines_namespace()}."))
    |> Enum.map(&String.to_existing_atom/1)
    |> Enum.filter(&Keyword.has_key?(&1.__info__(:functions), :kraken_pipeline_module?))
    |> Enum.map(&apply(&1, :name, []))
  end

  @spec start(String.t(), map()) :: {:ok, map()} | {:error, any}
  def start(pipeline_name, args \\ %{}) when is_binary(pipeline_name) and is_map(args) do
    opts = [
      telemetry_enabled: fetch_boolean_arg(args, "telemetry_enabled"),
      sync: fetch_boolean_arg(args, "sync")
    ]

    case status(pipeline_name) do
      :undefined ->
        {:error, :undefined}

      :not_ready ->
        {:ok, module} = build_module(pipeline_name)
        :ok = apply(module, :start, [opts])
        {:ok, module}

      :ready ->
        {:error, :already_started}
    end
  rescue
    error ->
      {:error, inspect(error)}
  end

  @spec stop(String.t()) :: :ok | {:error, any()}
  def stop(pipeline_name) when is_binary(pipeline_name) do
    case status(pipeline_name) do
      :undefined ->
        {:error, :undefined}

      :not_ready ->
        {:error, :not_ready}

      :ready ->
        {:ok, module} = build_module(pipeline_name)
        apply(module, :stop, [])
        :ok
    end
  rescue
    error ->
      {:error, error}
  end

  @spec delete(String.t()) :: :ok | {:error, any()}
  def delete(pipeline_name) do
    case status(pipeline_name) do
      :undefined ->
        {:error, :undefined}

      :not_ready ->
        {:ok, module} = build_module(pipeline_name)
        do_delete(module)

      :ready ->
        {:ok, module} = build_module(pipeline_name)
        apply(module, :stop, [])
        do_delete(module)
    end
  rescue
    error ->
      {:error, error}
  end

  @spec call(String.t(), map(), map()) :: map() | list(map()) | {:error, any()}
  def call(pipeline_name, args, opts \\ %{})
      when is_binary(pipeline_name) and (is_map(args) or is_list(args)) do
    opts = [return_ip: fetch_boolean_arg(opts, "return_ip")]

    case status(pipeline_name) do
      :undefined ->
        {:error, :undefined}

      :not_ready ->
        {:error, :not_ready}

      :ready ->
        {:ok, module} = build_module(pipeline_name)

        case args do
          event when is_map(event) ->
            apply(module, :call, [event, opts])

          events when is_list(events) ->
            Enum.to_list(apply(module, :stream, [events, opts]))
        end
    end
  rescue
    error ->
      {:error, error}
  end

  @spec cast(String.t(), map(), map()) :: reference() | list(reference()) | {:error, any()}
  def cast(pipeline_name, args, opts \\ %{})
      when is_binary(pipeline_name) and (is_map(args) or is_list(args)) do
    opts = [send_result: fetch_boolean_arg(opts, "send_result")]

    case status(pipeline_name) do
      :undefined ->
        {:error, :undefined}

      :not_ready ->
        {:error, :not_ready}

      :ready ->
        {:ok, module} = build_module(pipeline_name)

        case args do
          event when is_map(event) ->
            apply(module, :cast, [event, opts])

          events when is_list(events) ->
            Enum.map(events, &apply(module, :cast, [&1, opts]))
        end
    end
  rescue
    error ->
      {:error, error}
  end

  @spec stream(String.t(), map(), map()) :: Enumerable.t() | {:error, any()}
  def stream(pipeline_name, args, opts \\ %{})
      when is_list(args)
      when is_binary(pipeline_name) and (is_map(args) or is_list(args)) do
    opts = [return_ip: fetch_boolean_arg(opts, "return_ip")]

    case status(pipeline_name) do
      :undefined ->
        {:error, :undefined}

      :not_ready ->
        {:error, :not_ready}

      :ready ->
        {:ok, module} = build_module(pipeline_name)
        apply(module, :stream, [args, opts])
    end
  rescue
    error ->
      {:error, error}
  end

  def ready?(pipeline_name) do
    case status(pipeline_name) do
      :undefined ->
        {:error, :undefined}

      :not_ready ->
        {:error, :not_ready}

      :ready ->
        :ready
    end
  end

  defp fetch_boolean_arg(args, arg) do
    case Map.get(args, arg) do
      true -> true
      "true" -> true
      false -> false
      "false" -> false
      nil -> false
    end
  end

  defp do_delete(module) do
    :code.soft_purge(module)
    :code.delete(module)
    :ok
  end

  defp build_module(pipeline_name) do
    module_name = Utils.modulize(pipeline_name)
    namespace = Configs.pipelines_namespace()
    module = String.to_atom("Elixir.#{namespace}.#{module_name}")

    if Utils.module_exist?(module) do
      {:ok, module}
    else
      {:error, :not_found}
    end
  end

  def map_to_keyword(map) do
    Enum.map(map, fn {key, value} -> {String.to_atom(key), value} end)
  end
end
