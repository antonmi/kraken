defmodule Kraken.Define.Recomposer do
  alias Kraken.Utils

  def define(definition, recomposer_module, pipeline_helpers \\ []) do
    download = Map.get(definition, "download", false)
    service_name = get_in(definition, ["service", "name"]) || raise "Missing service name!"

    service_function =
      get_in(definition, ["service", "function"]) || raise "Missing service function!"

    get_in(definition, ["recompose", "events"]) || get_in(definition, ["recompose", "events"]) ||
      raise "Missing recompose events or event!"

    recompose = Map.get(definition, "recompose")

    helpers = Utils.helper_modules(definition) ++ pipeline_helpers

    template()
    |> EEx.eval_string(
      recomposer_module: recomposer_module,
      service_name: service_name,
      service_function: service_function,
      download: download,
      recompose: recompose,
      helpers: helpers
    )
    |> Utils.eval_code()
    |> case do
      {:ok, _code} ->
        {:ok, recomposer_module}
    end
  end

  defp template() do
    """
      defmodule <%= recomposer_module %> do
        @download "<%= Base.encode64(:erlang.term_to_binary(download)) %>"
                   |> Base.decode64!()
                   |> :erlang.binary_to_term()

        @recompose "<%= Base.encode64(:erlang.term_to_binary(recompose)) %>"
                   |> Base.decode64!()
                   |> :erlang.binary_to_term()

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def call(event, events, _opts) when is_map(event) and is_list(events) do
          %Kraken.Define.Recomposer.Call{
            event: event,
            events: events,
            service_name: "<%= service_name %>",
            service_function: "<%= service_function %>",
            download: @download,
            recompose: @recompose,
            helpers: @helpers
          }
          |> Kraken.Define.Recomposer.Call.call()
        end

        def call(_event, _events, _opts) do
          raise "'event' must be a map and 'events' must be a list"
        end
      end
    """
  end

  defmodule Call do
    @moduledoc false

    defstruct event: nil,
              events: [],
              service_name: nil,
              service_function: nil,
              download: false,
              recompose: false,
              helpers: []

    alias Octopus.Transform

    @spec call(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def call(%__MODULE__{
          event: event,
          events: events,
          service_name: service_name,
          service_function: service_function,
          download: download,
          recompose: recompose,
          helpers: helpers
        }) do
      with {:ok, args} <-
             Transform.transform(event, download, helpers),
           {:ok, args} <-
             Octopus.call(service_name, service_function, %{"event" => args, "events" => events}),
           {:ok, args} <-
             Transform.transform(args, recompose, helpers) do
        event = Map.get(args, "event", nil)
        events = Map.get(args, "events", [])

        case {event, events} do
          {event, events} when is_list(events) and (is_map(event) or is_nil(event)) ->
            {event, events}

          _other ->
            raise "The 'event' must be map or nil, 'events' must be a list. " <>
                    "Currently, event: #{inspect(event)}, events: #{inspect(events)}"
        end
      else
        {:error, error} -> {:error, error}
      end
    end
  end
end
