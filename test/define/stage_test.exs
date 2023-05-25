defmodule Kraken.Define.StageTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Define.{Pipeline, Stage}

  setup do
    define_and_start_service("simple-math")

    on_exit(fn ->
      Octopus.stop("simple-math")
      Octopus.delete("simple-math")
    end)
  end

  test "simple-math service" do
    assert {:ok, %{"sum" => 3}} = Octopus.call("simple-math", "add", %{"a" => 1, "b" => 2})
    assert {:ok, %{"result" => 10}} = Octopus.call("simple-math", "mult_by_two", %{"x" => 5})
  end

  @component %{
    "type" => "stage",
    "name" => "add",
    "service" => %{"name" => "simple-math", "function" => "add"},
    "prepare" => %{"a" => "args['x']", "b" => "args['y']"},
    "transform" => %{"z" => "args['sum']"}
  }

  test "define and call stage" do
    stage_module = Kraken.Pipelines.MyPipeline.Add
    {:ok, ^stage_module} = Stage.define(@component, stage_module)

    result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
    assert result == %{"x" => 1, "y" => 2, "z" => 3}

    assert_raise RuntimeError, "Event must be a map", fn ->
      apply(stage_module, :call, ["error", %{}])
    end

    assert_raise RuntimeError, fn ->
      apply(stage_module, :call, [%{"x" => "error"}, %{}])
    end
  end

  test "without transform" do
    component = %{
      "type" => "stage",
      "service" => %{"name" => "simple-math", "function" => "add"},
      "prepare" => %{"a" => "args['x']", "b" => "args['y']"}
    }

    stage_module = Kraken.Pipelines.MyPipeline.Add2
    {:ok, ^stage_module} = Stage.define(component, stage_module)

    result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
    assert result == %{"x" => 1, "y" => 2}
  end

  test "when transform is empty map" do
    component = %{
      "type" => "stage",
      "service" => %{"name" => "simple-math", "function" => "add"},
      "prepare" => %{"a" => "args['x']", "b" => "args['y']"},
      "transform" => %{}
    }

    stage_module = Kraken.Pipelines.MyPipeline.Add3
    {:ok, ^stage_module} = Stage.define(component, stage_module)

    result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
    assert result == %{"x" => 1, "y" => 2}
  end

  describe "Transform only " do
    @transform_only_stage %{
      "type" => "stage",
      "name" => "transform",
      "prepare" => %{"a" => "args['x']", "b" => "args['y']"},
      "transform" => %{"z" => "args['a'] + args['b']"}
    }

    test "define and call stage" do
      stage_module = Kraken.Pipelines.MyPipeline.Transform
      {:ok, ^stage_module} = Stage.define(@transform_only_stage, stage_module)

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2, "z" => 3}
    end

    test "define and call stage with transform only" do
      transform_only_stage = %{
        "type" => "stage",
        "name" => "transform2",
        "transform" => %{"z" => "args['x'] + args['y']"}
      }

      stage_module = Kraken.Pipelines.MyPipeline.Transform2
      {:ok, ^stage_module} = Stage.define(transform_only_stage, stage_module)

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2, "z" => 3}
    end

    test "define and call stage with prepare only" do
      transform_only_stage = %{
        "type" => "stage",
        "name" => "transform3",
        "prepare" => %{"a" => "args['x']", "b" => "args['y']"}
      }

      stage_module = Kraken.Pipelines.MyPipeline.Transform3
      {:ok, ^stage_module} = Stage.define(transform_only_stage, stage_module)

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2}
    end

    test "define and call stage with empty transform" do
      transform_only_stage = %{
        "type" => "stage",
        "name" => "transform4",
        "prepare" => %{"a" => "args['x']", "b" => "args['y']"},
        "transform" => %{}
      }

      stage_module = Kraken.Pipelines.MyPipeline.Transform4
      {:ok, ^stage_module} = Stage.define(transform_only_stage, stage_module)

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2}
    end
  end

  describe "helpers in stage" do
    @component_with_helpers %{
      "type" => "stage",
      "name" => "add-with-helpers",
      "service" => %{"name" => "simple-math", "function" => "add"},
      "prepare" => %{"a" => "fetch(args, 'x')", "b" => "fetch(args, 'y')"},
      "transform" => %{"z" => "fetch(args, 'sum')"},
      "helpers" => ["Helpers.FetchHelper"]
    }

    test "define and call stage" do
      stage_module = Kraken.Pipelines.MyPipeline.AddWithHelpers
      {:ok, ^stage_module} = Stage.define(@component_with_helpers, stage_module)

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2, "z" => 3}
    end

    @pipeline_with_helpers %{
      "name" => "PipelineWithHelpers",
      "components" => [
        Map.put(@component_with_helpers, "transform", %{"z" => "get(args, 'sum')"})
      ],
      "helpers" => ["Helpers.GetHelper"]
    }

    test "pipeline helpers are added to the component ones" do
      Pipeline.define(@pipeline_with_helpers)
      apply(Kraken.Pipelines.PipelineWithHelpers, :start, [])

      result = apply(Kraken.Pipelines.PipelineWithHelpers, :call, [%{"x" => 1, "y" => 2}])
      assert result == %{"x" => 1, "y" => 2, "z" => 3}
    end
  end
end
