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
    "download" => %{"a" => "args['x']", "b" => "args['y']"},
    "upload" => %{"z" => "args['sum']"}
  }

  test "define and call stage" do
    {:ok, stage_module} = Stage.define(@component, Kraken.Pipelines.MyPipeline)
    assert stage_module == Kraken.Pipelines.MyPipeline.Add

    result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
    assert result == %{"x" => 1, "y" => 2, "z" => 3}

    assert_raise RuntimeError, "Event must be a map", fn ->
      apply(stage_module, :call, ["error", %{}])
    end

    assert_raise RuntimeError, fn ->
      apply(stage_module, :call, [%{"x" => "error"}, %{}])
    end
  end

  test "without upload" do
    component = %{
      "type" => "stage",
      "name" => "add2",
      "service" => %{"name" => "simple-math", "function" => "add"},
      "download" => %{"a" => "args['x']", "b" => "args['y']"}
    }

    {:ok, stage_module} = Stage.define(component, Kraken.Pipelines.MyPipeline)
    assert stage_module == Kraken.Pipelines.MyPipeline.Add2

    result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
    assert result == %{"x" => 1, "y" => 2}
  end

  test "when upload is empty map" do
    component = %{
      "type" => "stage",
      "name" => "add3",
      "service" => %{"name" => "simple-math", "function" => "add"},
      "download" => %{"a" => "args['x']", "b" => "args['y']"},
      "upload" => %{}
    }

    {:ok, stage_module} = Stage.define(component, Kraken.Pipelines.MyPipeline)
    assert stage_module == Kraken.Pipelines.MyPipeline.Add3

    result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
    assert result == %{"x" => 1, "y" => 2}
  end

  describe "Transform only " do
    @transform_only_stage %{
      "type" => "stage",
      "name" => "transform",
      "download" => %{"a" => "args['x']", "b" => "args['y']"},
      "upload" => %{"z" => "args['a'] + args['b']"}
    }

    test "define and call stage" do
      {:ok, stage_module} = Stage.define(@transform_only_stage, Kraken.Pipelines.MyPipeline)
      assert stage_module == Kraken.Pipelines.MyPipeline.Transform

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2, "z" => 3}
    end

    test "define and call stage with upload only" do
      transform_only_stage = %{
        "type" => "stage",
        "name" => "transform2",
        "upload" => %{"z" => "args['x'] + args['y']"}
      }

      {:ok, stage_module} = Stage.define(transform_only_stage, Kraken.Pipelines.MyPipeline)
      assert stage_module == Kraken.Pipelines.MyPipeline.Transform2

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2, "z" => 3}
    end

    test "define and call stage with download only" do
      transform_only_stage = %{
        "type" => "stage",
        "name" => "transform3",
        "download" => %{"a" => "args['x']", "b" => "args['y']"}
      }

      {:ok, stage_module} = Stage.define(transform_only_stage, Kraken.Pipelines.MyPipeline)
      assert stage_module == Kraken.Pipelines.MyPipeline.Transform3

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2}
    end

    test "define and call stage with empty upload" do
      transform_only_stage = %{
        "type" => "stage",
        "name" => "transform4",
        "download" => %{"a" => "args['x']", "b" => "args['y']"},
        "upload" => %{}
      }

      {:ok, stage_module} = Stage.define(transform_only_stage, Kraken.Pipelines.MyPipeline)
      assert stage_module == Kraken.Pipelines.MyPipeline.Transform4

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2}
    end
  end

  describe "helpers in stage" do
    @component_with_helpers %{
      "type" => "stage",
      "name" => "add-with-helpers",
      "service" => %{"name" => "simple-math", "function" => "add"},
      "download" => %{"a" => "fetch(args, 'x')", "b" => "fetch(args, 'y')"},
      "upload" => %{"z" => "fetch(args, 'sum')"},
      "helpers" => ["Helpers.FetchHelper"]
    }

    test "define and call stage" do
      {:ok, stage_module} = Stage.define(@component_with_helpers, Kraken.Pipelines.MyPipeline)
      assert stage_module == Kraken.Pipelines.MyPipeline.AddWithHelpers

      result = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2, "z" => 3}
    end

    @pipeline_with_helpers %{
      "name" => "PipelineWithHelpers",
      "components" => [
        Map.put(@component_with_helpers, "upload", %{"z" => "get(args, 'sum')"})
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
