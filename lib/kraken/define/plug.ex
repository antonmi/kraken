defmodule Kraken.Define.Plug do
  alias Kraken.Utils

  def define(definition, plug_module, pipeline_helpers \\ []) do
    prepare = Map.get(definition, "prepare", false)
    transform = Map.get(definition, "transform", false)
    helpers = Utils.helper_modules(definition) ++ pipeline_helpers

    template()
    |> EEx.eval_string(
      plug_module: plug_module,
      prepare: prepare,
      transform: transform,
      helpers: helpers
    )
    |> Utils.eval_code()
    |> case do
      {:ok, _code} ->
        {:ok, plug_module}
    end
  end

  defp template() do
    """
      defmodule <%= plug_module %> do
        @prepare "<%= Base.encode64(:erlang.term_to_binary(prepare)) %>"
                  |> Base.decode64!()
                  |> :erlang.binary_to_term()

        @transform "<%= Base.encode64(:erlang.term_to_binary(transform)) %>"
                |> Base.decode64!()
                |> :erlang.binary_to_term()

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def plug(event, _) when is_map(event) do
          %Kraken.Define.Plug.Call{
            event: event,
            prepare: @prepare,
            helpers: @helpers
          }
          |> Kraken.Define.Plug.Call.plug()
          |> case do
            {:ok, result} ->
              result
            {:error, error} ->
              raise inspect(error)
          end
        end

        def plug(_event, _opts), do: raise "Event must be a map"

        def unplug(event, prev_event, _) when is_map(event) and is_map(prev_event) do
          %Kraken.Define.Plug.Call{
            event: event,
            prev_event: prev_event,
            transform: @transform,
            helpers: @helpers
          }
          |> Kraken.Define.Plug.Call.unplug()
          |> case do
            {:ok, result} ->
              result
            {:error, error} ->
              raise inspect(error)
          end
        end

        def unplug(_event, _prev_event, _opts), do: raise "Event must be a map"
      end
    """
  end

  defmodule Call do
    @moduledoc false

    defstruct event: nil,
              prev_event: nil,
              prepare: false,
              transform: false,
              helpers: []

    alias Octopus.Transform

    @spec plug(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def plug(%__MODULE__{
          event: event,
          prepare: prepare,
          helpers: helpers
        }) do
      case Transform.transform(event, prepare, helpers) do
        {:ok, event} ->
          {:ok, event}

        {:error, error} ->
          {:error, error}
      end
    end

    @spec unplug(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def unplug(%__MODULE__{
          event: event,
          prev_event: prev_event,
          transform: transform,
          helpers: helpers
        }) do
      case Transform.transform(event, transform, helpers) do
        {:ok, args} ->
          event = upload_to_event(prev_event, args, transform)
          {:ok, event}

        {:error, error} ->
          {:error, error}
      end
    end

    defp upload_to_event(event, _args, false), do: event

    defp upload_to_event(event, args, transform) when is_map(transform) do
      Map.merge(event, args)
    end
  end
end
