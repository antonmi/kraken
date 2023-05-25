defmodule Kraken.Define.Stage do
  alias Kraken.Utils

  def define(definition, stage_module, pipeline_helpers \\ []) do
    prepare = Map.get(definition, "prepare", false)
    transform = Map.get(definition, "transform", false)

    helpers = Utils.helper_modules(definition) ++ pipeline_helpers

    {service_name, service_function} =
      if Map.get(definition, "service") do
        service_name = get_in(definition, ["service", "name"]) || raise "Missing service name!"

        service_function =
          get_in(definition, ["service", "function"]) || raise "Missing service function!"

        {service_name, service_function}
      else
        {"", ""}
      end

    template()
    |> EEx.eval_string(
      stage_module: stage_module,
      service_name: service_name,
      service_function: service_function,
      prepare: prepare,
      transform: transform,
      helpers: helpers
    )
    |> Utils.eval_code()
    |> case do
      {:ok, _code} ->
        {:ok, stage_module}
    end
  end

  defp template() do
    """
      defmodule <%= stage_module %> do
        @prepare "<%= Base.encode64(:erlang.term_to_binary(prepare)) %>"
                  |> Base.decode64!()
                  |> :erlang.binary_to_term()

        @transform "<%= Base.encode64(:erlang.term_to_binary(transform)) %>"
                |> Base.decode64!()
                |> :erlang.binary_to_term()

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def call(event, _opts) when is_map(event) do
          %Kraken.Define.Stage.Call{
            event: event,
            service_name: "<%= service_name %>",
            service_function: "<%= service_function %>",
            prepare: @prepare,
            transform: @transform,
            helpers: @helpers
          }
          |> Kraken.Define.Stage.Call.call()
          |> case do
            {:ok, result} ->
              result
            {:error, error} ->
              raise inspect(error)
          end
        end

        def call(_event, _opts) do
          raise "Event must be a map"
        end
      end
    """
  end

  defmodule Call do
    @moduledoc false

    defstruct event: nil,
              service_name: nil,
              service_function: nil,
              prepare: false,
              transform: false,
              helpers: []

    alias Octopus.Transform

    @spec call(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def call(%__MODULE__{
          event: event,
          service_name: service_name,
          service_function: service_function,
          prepare: prepare,
          transform: transform,
          helpers: helpers
        }) do
      with {:ok, args} <-
             Transform.transform(event, prepare, helpers),
           {:ok, args} <-
             do_call(service_name, service_function, args),
           {:ok, args} <-
             Transform.transform(args, transform, helpers) do
        event = upload_to_event(event, args, transform)
        {:ok, event}
      else
        {:error, error} -> {:error, error}
      end
    end

    defp do_call("", "", args), do: {:ok, args}

    defp do_call(service_name, service_function, args) do
      Octopus.call(service_name, service_function, args)
    end

    defp upload_to_event(event, _args, false), do: event

    defp upload_to_event(event, args, transform) when is_map(transform) do
      Map.merge(event, args)
    end
  end
end
