defmodule Kraken.Define.Decomposer do
  alias Kraken.Utils

  def define(definition, pipeline_module, pipeline_helpers \\ []) do
    decomposer_module =
      "#{pipeline_module}.#{definition["name"]}"
      |> Utils.modulize()
      |> String.to_atom()

    download = Map.get(definition, "download", false)
    service_name = get_in(definition, ["service", "name"]) || raise "Missing service name!"

    service_function =
      get_in(definition, ["service", "function"]) || raise "Missing service function!"

    get_in(definition, ["decompose", "events"]) || get_in(definition, ["decompose", "events"]) ||
      raise "Missing decompose events or event!"

    decompose = Map.get(definition, "decompose")

    helpers = Utils.helper_modules(definition) ++ pipeline_helpers

    template()
    |> EEx.eval_string(
      decomposer_module: decomposer_module,
      service_name: service_name,
      service_function: service_function,
      download: download,
      decompose: decompose,
      helpers: helpers
    )
    |> Utils.eval_code()
    |> case do
      {:ok, _code} ->
        {:ok, decomposer_module}
    end
  end

  defp template() do
    """
      defmodule <%= decomposer_module %> do
        @download "<%= Base.encode64(:erlang.term_to_binary(download)) %>"
                   |> Base.decode64!()
                   |> :erlang.binary_to_term()

        @decompose "<%= Base.encode64(:erlang.term_to_binary(decompose)) %>"
                   |> Base.decode64!()
                   |> :erlang.binary_to_term()

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def call(event, _opts) when is_map(event) do
          %Kraken.Define.Decomposer.Call{
            event: event,
            service_name: "<%= service_name %>",
            service_function: "<%= service_function %>",
            download: @download,
            decompose: @decompose,
            helpers: @helpers
          }
          |> Kraken.Define.Decomposer.Call.call()
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
              download: false,
              decompose: false,
              helpers: []

    alias Octopus.Transform

    @spec call(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def call(%__MODULE__{
          event: event,
          service_name: service_name,
          service_function: service_function,
          download: download,
          decompose: decompose,
          helpers: helpers
        }) do
      with {:ok, args} <-
             Transform.transform(event, download, helpers),
           {:ok, args} <-
             Octopus.call(service_name, service_function, args),
           {:ok, args} <-
             Transform.transform(args, decompose, helpers) do
        event = Map.get(args, "event")
        events = Map.get(args, "events")

        cond do
          events && event ->
            {events, event}

          events ->
            events

          true ->
            raise "Events or events with event must be present!"
        end
      else
        {:error, error} -> {:error, error}
      end
    end
  end
end
