defmodule Kraken.Define.Switch do
  alias Kraken.Utils

  def define(definition, switch_module, pipeline_helpers \\ []) do
    Map.get(definition, "branches") || raise "Missing branches"
    download = Map.get(definition, "download", false)
    condition = Map.get(definition, "condition") || raise "Missing condition"
    helpers = Utils.helper_modules(definition) ++ pipeline_helpers

    template()
    |> EEx.eval_string(
      download: download,
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

        @download "<%= Base.encode64(:erlang.term_to_binary(download)) %>"
                   |> Base.decode64!()
                   |> :erlang.binary_to_term()

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def call(event, _opts) when is_map(event) do
          %Kraken.Define.Switch.Call{
            event: event,
            download: @download,
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
              download: false,
              condition: "",
              helpers: []

    alias Octopus.Transform

    @spec call(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def call(%__MODULE__{
          event: event,
          download: download,
          condition: condition,
          helpers: helpers
        }) do
      with {:ok, args} <- Transform.transform(event, download, helpers),
           {:ok, branch} <- Utils.eval_string(condition, args: args, helpers: helpers) do
        branch
      else
        {:error, error} ->
          {:error, error}
      end
    end
  end
end
