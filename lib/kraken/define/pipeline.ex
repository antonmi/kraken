defmodule Kraken.Define.Pipeline do
  alias Kraken.{Configs, Utils}
  alias Kraken.Define.Stage
  alias ALF.Components


  def define(definition) do
    name = definition["name"] || raise "Provide pipeline name"
    pipeline_module = :"#{namespace}.#{Utils.modulize(name)}"
    components = build_components(definition["components"], pipeline_module)

    template()
    |> EEx.eval_string(
         pipeline_module: pipeline_module,
         components: components
       )
    |> Utils.eval_code()
    |> case do
         {:ok, _code} ->
           {:ok, name}
       end
  end

  defp template() do
    """
      defmodule <%= pipeline_module %> do
        use ALF.DSL

        @components "<%= Base.encode64(:erlang.term_to_binary(components)) %>"
                    |> Base.decode64!()
                    |> :erlang.binary_to_term()



        def test, do: :ok
      end
    """
  end

  defp build_components(components, pipeline_module) do
    components
    |> Enum.reduce([], fn(definition, acc) ->
      case definition["type"] do
        "stage" ->
          {:ok, stage_module} = Stage.define(definition, pipeline_module)
          component = %Components.Stage{
            name: String.to_atom(definition["name"]),
            module: :"Elixir.#{stage_module}",
            function: :call,
            opts: definition["opts"]
          }
         acc ++ [component]
      end
    end)
  end

  defp namespace do
    Configs.pipelines_namespace()
  end
end
