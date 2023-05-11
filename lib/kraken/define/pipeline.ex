defmodule Kraken.Define.Pipeline do
  alias Kraken.{Configs, Utils}
  alias Kraken.Define.{Goto, Stage, Switch}
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

  # TODO think about default names based on the specification
  defp build_components(components, pipeline_module) do
    components
    |> Enum.reduce([], fn definition, acc ->
      Map.get(definition, "type") || raise "Missing type"
      type =
        definition["type"]
        |> String.downcase()
        |> String.replace("-", "_")

      component =
        case type do
          "stage" ->
            {:ok, stage_module} = Stage.define(definition, pipeline_module)

            %Components.Stage{
              name: definition["name"],
              module: :"Elixir.#{stage_module}",
              function: :call
            }

          "switch" ->
            {:ok, switch_module} = Switch.define(definition, pipeline_module)

            branches =
              Enum.reduce(definition["branches"], %{}, fn {key, inner_pipe_spec}, branch_pipes ->
                inner_components = build_components(inner_pipe_spec, pipeline_module)

                Map.put(branch_pipes, key, inner_components)
              end)

            %Components.Switch{
              name: definition["name"],
              module: :"Elixir.#{switch_module}",
              function: :call,
              branches: branches
            }

          "clone" ->
            Map.get(definition, "to") || raise "Missing 'to'"

            %Components.Clone{
              name: definition["name"],
              to: build_components(definition["to"], pipeline_module)
            }

          "dead_end" ->
            %Components.DeadEnd{
              name: definition["name"]
            }

          "goto_point" ->
            %Components.GotoPoint{
              name: definition["name"]
            }

          "goto" ->
            {:ok, goto_module} = Goto.define(definition, pipeline_module)

            %Components.Goto{
              name: definition["name"],
              module: :"Elixir.#{goto_module}",
              function: :call,
              to: (Map.get(definition, "to") || raise "Missing 'to'")
            }
        end

      acc ++ [component]
    end)
  end

  defp namespace do
    Configs.pipelines_namespace()
  end
end
