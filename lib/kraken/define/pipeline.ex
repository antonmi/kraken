defmodule Kraken.Define.Pipeline do
  alias Kraken.{Configs, Utils}
  alias Kraken.Define.{Decomposer, Goto, Recomposer, Plug, Stage, Switch}
  alias ALF.Components

  def define(definition) do
    name = definition["name"] || raise "Provide pipeline name"
    pipeline_module = :"#{namespace()}.#{Utils.modulize(name)}"

    helpers = Utils.helper_modules(definition)

    components = build_components(definition["components"], pipeline_module, helpers)

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
  # "type - serialized json definition"
  # TODO definition should go to the component code.
  defp build_components(components, pipeline_module, helpers) do
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
            {:ok, stage_module} = Stage.define(definition, pipeline_module, helpers)

            %Components.Stage{
              name: definition["name"],
              module: :"Elixir.#{stage_module}",
              function: :call
            }

          "switch" ->
            {:ok, switch_module} = Switch.define(definition, pipeline_module)

            branches =
              Enum.reduce(definition["branches"], %{}, fn {key, inner_pipe_spec}, branch_pipes ->
                inner_components = build_components(inner_pipe_spec, pipeline_module, helpers)

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
              to: build_components(definition["to"], pipeline_module, helpers)
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
              to: Map.get(definition, "to") || raise("Missing 'to'")
            }

          "decomposer" ->
            {:ok, decomposer_module} = Decomposer.define(definition, pipeline_module, helpers)

            %Components.Decomposer{
              name: definition["name"],
              module: :"Elixir.#{decomposer_module}",
              function: :call
            }

          "recomposer" ->
            {:ok, recomposer_module} = Recomposer.define(definition, pipeline_module, helpers)

            %Components.Recomposer{
              name: definition["name"],
              module: :"Elixir.#{recomposer_module}",
              function: :call
            }

          "plug" ->
            {:ok, plug_module} = Plug.define(definition, pipeline_module)

            pipeline_name =
              Map.get(definition, "pipeline") || raise "\"pipeline\" must be provided"

            pipeline_module = :"Elixir.#{namespace()}.#{Utils.modulize(pipeline_name)}"

            plug = %Components.Plug{name: definition["name"], module: :"Elixir.#{plug_module}"}

            unplug = %Components.Unplug{
              name: definition["name"],
              module: :"Elixir.#{plug_module}"
            }

            [plug] ++ pipeline_module.alf_components() ++ [unplug]

          nil ->
            raise "Component 'type' must be given"

          unknown_type ->
            raise "Unknown component type #{unknown_type}"
        end

      case component do
        component when is_map(component) ->
          acc ++ [component]

        components when is_list(components) ->
          acc ++ components
      end
    end)
  end

  defp namespace do
    Configs.pipelines_namespace()
  end
end
