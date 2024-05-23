defmodule Kraken.Define.Composer do
  alias Kraken.Utils

  def define(definition, composer_module, pipeline_helpers \\ []) do
    prepare = Map.get(definition, "prepare", false)
    compose = Map.get(definition, "compose", false) || raise "Missing 'compose' rules"
    Map.get(compose, "events", false) || raise "'events' must be present in the 'compose' rules"

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
      composer_module: composer_module,
      service_name: service_name,
      service_function: service_function,
      prepare: prepare,
      compose: compose,
      helpers: helpers
    )
    |> Utils.eval_code()
    |> case do
      {:ok, _code} ->
        {:ok, composer_module}
    end
  end

  defp template() do
    """
      defmodule <%= composer_module %> do
        @prepare "<%= Base.encode64(:erlang.term_to_binary(prepare)) %>"
                  |> Base.decode64!()
                  |> :erlang.binary_to_term()

        @compose "<%= Base.encode64(:erlang.term_to_binary(compose)) %>"
                  |> Base.decode64!()
                  |> :erlang.binary_to_term()

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def call(event, memo, _opts) when is_map(event) do
          %Kraken.Define.Composer.Call{
            event: event,
            memo: memo,
            service_name: "<%= service_name %>",
            service_function: "<%= service_function %>",
            prepare: @prepare,
            compose: @compose,
            helpers: @helpers
          }
          |> Kraken.Define.Composer.Call.call()
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
              memo: nil,
              prepare: false,
              compose: nil,
              helpers: []

    alias Octopus.Transform

    @spec call(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def call(%__MODULE__{
          event: event,
          service_name: service_name,
          service_function: service_function,
          memo: memo,
          prepare: prepare,
          compose: compose,
          helpers: helpers
        }) do
      with {:ok, args} <-
             Transform.transform(event, prepare, helpers),
           {:ok, args} <- replace_memo(args, memo),
           {:ok, args} <-
             do_call(service_name, service_function, args),
           {:ok, args} <-
             Transform.transform(args, compose, helpers) do
        {events, memo} = {Map.get(args, "events"), Map.get(args, "memo")}

        case {events, memo} do
          {events, memo} when is_list(events) ->
            {events, memo}

          _other ->
            raise "'events' must be a list. Got #{inspect(events)}"
        end
      else
        {:error, error} -> {:error, error}
      end
    end

    defp replace_memo(args, memo) do
      args =
        Enum.reduce(args, %{}, fn
          {k, "memo"}, acc -> Map.put(acc, k, memo)
          {k, v}, acc -> Map.put(acc, k, v)
        end)

      {:ok, args}
    end

    defp do_call("", "", args), do: {:ok, args}

    defp do_call(service_name, service_function, args) do
      Octopus.call(service_name, service_function, args)
    end
  end
end
