defmodule Kraken.Define.Switch do
  alias Kraken.Utils

  def define(definition, switch_module, pipeline_helpers \\ []) do
    if Enum.count(Map.get(definition, "branches", %{})) == 0, do: raise("Missing branches")
    prepare = Map.get(definition, "prepare", false)
    condition = Map.get(definition, "condition") || raise "Missing condition"
    helpers = Utils.helper_modules(definition) ++ pipeline_helpers

    template()
    |> EEx.eval_string(
      prepare: prepare,
      switch_module: switch_module,
      condition: condition,
      helpers: helpers
    )
    |> Utils.eval_code()
    |> case do
      {:ok, _code} ->
        {:ok, switch_module}
    end
  end

  defp template() do
    """
      defmodule <%= switch_module %> do
        @condition "<%= Base.encode64(:erlang.term_to_binary(condition)) %>"
                   |> Base.decode64!()
                   |> :erlang.binary_to_term()

        @prepare "<%= Base.encode64(:erlang.term_to_binary(prepare)) %>"
                   |> Base.decode64!()
                   |> :erlang.binary_to_term()

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def call(event, _opts) when is_map(event) do
          %Kraken.Define.Switch.Call{
            event: event,
            prepare: @prepare,
            condition: @condition,
            helpers: @helpers
          }
          |> Kraken.Define.Switch.Call.call()
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
              prepare: false,
              condition: "",
              helpers: []

    alias Octopus.Transform

    @spec call(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def call(%__MODULE__{
          event: event,
          prepare: prepare,
          condition: condition,
          helpers: helpers
        }) do
      case Transform.transform(event, prepare, helpers) do
        {:ok, args} ->
          Utils.eval_string(condition, args: args, helpers: helpers)

        {:error, error} ->
          {:error, error}
      end
    end
  end
end
