defmodule Kraken.Define.Pipeline do
  alias Kraken.{Configs, Utils}
  alias Kraken.Define.{Decomposer, Goto, Recomposer, Plug, Stage, Switch}
  alias ALF.Components

  def define(definition) do
    name = definition["name"] || raise "Pipeline must have name!"
    pipeline_module = :"#{namespace()}.#{Utils.modulize(name)}"

    helpers = Utils.helper_modules(definition)

    definition["components"] || raise "Missing 'components'!"
    components = build_components(definition["components"], pipeline_module, helpers)

    template()
    |> EEx.eval_string(
      name: name,
      definition: definition,
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

        @definition "<%= Base.encode64(:erlang.term_to_binary(definition)) %>"
                    |> Base.decode64!()
                    |> :erlang.binary_to_term()

        @components "<%= Base.encode64(:erlang.term_to_binary(components)) %>"
                    |> Base.decode64!()
                    |> :erlang.binary_to_term()

        def kraken_pipeline_module?, do: true

        def name, do: "<%= name %>"

        def definition, do: @definition
      end
    """
  end

  defp build_components(components, pipeline_module, helpers) do
    components
    |> Enum.reduce([], fn definition, acc ->
      Map.get(definition, "type") || raise "Missing type"

      type =
        definition["type"]
        |> String.downcase()
        |> String.replace("-", "_")

      name = definition["name"] || type_with_random_postfix(type)

      component_module =
        "Elixir.#{pipeline_module}.#{name}"
        |> Utils.modulize()
        |> String.to_atom()

      component =
        case type do
          "stage" ->
            {:ok, ^component_module} = Stage.define(definition, component_module, helpers)

            %Components.Stage{
              name: name,
              module: component_module,
              function: :call,
              source_code: definition,
              count: Map.get(definition, "count", 1)
            }

          "switch" ->
            {:ok, ^component_module} = Switch.define(definition, component_module, helpers)

            branches =
              Enum.reduce(definition["branches"], %{}, fn {key, inner_pipe_spec}, branch_pipes ->
                inner_components = build_components(inner_pipe_spec, pipeline_module, helpers)

                Map.put(branch_pipes, key, inner_components)
              end)

            %Components.Switch{
              name: name,
              module: component_module,
              function: :call,
              branches: branches,
              source_code: definition
            }

          "clone" ->
            Map.get(definition, "to") || raise "Missing 'to'"

            %Components.Clone{
              name: name,
              to: build_components(definition["to"], pipeline_module, helpers)
            }

          "dead_end" ->
            %Components.DeadEnd{name: name}

          "goto_point" ->
            %Components.GotoPoint{name: name}

          "goto" ->
            {:ok, ^component_module} = Goto.define(definition, component_module, helpers)

            %Components.Goto{
              name: name,
              module: component_module,
              function: :call,
              to: Map.get(definition, "to") || raise("Missing 'to'"),
              source_code: definition
            }

          "decomposer" ->
            {:ok, ^component_module} = Decomposer.define(definition, component_module, helpers)

            %Components.Decomposer{
              name: name,
              module: component_module,
              function: :call,
              source_code: definition
            }

          "recomposer" ->
            {:ok, ^component_module} = Recomposer.define(definition, component_module, helpers)

            %Components.Recomposer{
              name: name,
              module: component_module,
              function: :call,
              source_code: definition
            }

          "plug" ->
            {:ok, ^component_module} = Plug.define(definition, component_module, helpers)

            pipeline_name =
              Map.get(definition, "pipeline") || raise "\"pipeline\" must be provided"

            pipeline_module = :"Elixir.#{namespace()}.#{Utils.modulize(pipeline_name)}"

            plug = %Components.Plug{name: name, module: component_module, source_code: definition}

            unplug = %Components.Unplug{
              name: name,
              module: component_module,
              source_code: definition
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

  defp type_with_random_postfix(type) do
    "#{type}_#{Utils.random_string()}"
  end
end
