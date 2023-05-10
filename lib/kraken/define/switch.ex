defmodule Kraken.Define.Switch do
  alias Kraken.Utils

  def define(definition, pipeline_module) do
    switch_module =
      "#{pipeline_module}.#{definition["name"]}"
      |> Utils.modulize()
      |> String.to_atom()

    branches = Map.get(definition, "branches") || raise "Missing branches"
    condition = Map.get(definition, "condition") || raise "Missing condition"

    template()
    |> EEx.eval_string(
      switch_module: switch_module,
      condition: condition,
      # TODO helper_modules(definition.helpers)
      helpers: []
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

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def call(event, _opts) when is_map(event) do
          %Kraken.Define.Switch.Call{
            event: event,
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
              condition: "",
              helpers: []

    @spec call(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def call(%__MODULE__{
          event: event,
          condition: condition,
          helpers: helpers
        }) do
      case Utils.eval_string(condition, args: event, helpers: helpers) do
        {:ok, branch} ->
          branch

        {:error, error} ->
          raise error
      end
    end
  end
end
