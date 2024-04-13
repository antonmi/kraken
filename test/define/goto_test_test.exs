defmodule Kraken.Define.GotoTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Define.Pipeline

  setup do
    define_and_start_service("simple-math")

    on_exit(fn ->
      Octopus.delete("simple-math")
    end)
  end

  test "simple-math service" do
    assert {:ok, %{"sum" => 3}} = Octopus.call("simple-math", "add", %{"a" => 1, "b" => 2})
    assert {:ok, %{"result" => 10}} = Octopus.call("simple-math", "mult_by_two", %{"x" => 5})
    assert {:ok, %{"result" => 6}} = Octopus.call("simple-math", "add_one", %{"x" => 5})
  end

  describe "simple pipeline with goto" do
    @components [
      %{
        "type" => "goto-point",
        "name" => "my-goto-point"
      },
      %{
        "type" => "stage",
        "name" => "add_one",
        "service" => %{
          "name" => "simple-math",
          "function" => "add_one"
        },
        "transform" => %{
          "x" => "args['result']"
        }
      },
      %{
        "type" => "goto",
        "name" => "my-goto",
        "to" => "my-goto-point",
        "condition" => "args['x'] <= 3"
      }
    ]

    @pipeline %{
      "name" => "GotoPipeline",
      "components" => @components
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline)
      apply(Kraken.Pipelines.GotoPipeline, :start, [])

      assert apply(Kraken.Pipelines.GotoPipeline.MyGoto, :call, [%{"x" => 2}, %{}]) == true
      assert apply(Kraken.Pipelines.GotoPipeline, :call, [%{"x" => 1}]) == %{"x" => 4}
    end
  end

  describe "goto without condition (true by default)" do
    @goto_true_components [
      %{
        "type" => "goto",
        "name" => "my-goto",
        "to" => "my-goto-point"
      },
      %{
        "type" => "goto-point",
        "name" => "my-goto-point"
      }
    ]

    @goto_true_pipeline %{
      "name" => "GotoTruePipeline",
      "components" => @goto_true_components
    }

    test "define and call pipeline" do
      Pipeline.define(@goto_true_pipeline)
      apply(Kraken.Pipelines.GotoTruePipeline, :start, [])
      Process.sleep(100)

      assert apply(Kraken.Pipelines.GotoTruePipeline, :call, [%{"x" => 1}]) == %{"x" => 1}
    end
  end

  describe "error in goto" do
    @components_with_error_in_condition [
      %{
        "type" => "goto-point",
        "name" => "my-goto-point"
      },
      %{
        "type" => "goto",
        "name" => "my-goto",
        "to" => "my-goto-point",
        "condition" => "args['x'] <= qwerty"
      }
    ]

    @pipeline_with_error_in_condition %{
      "name" => "GotoPipelineWithError",
      "components" => @components_with_error_in_condition
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline_with_error_in_condition)
      apply(Kraken.Pipelines.GotoPipelineWithError, :start, [])

      result = apply(Kraken.Pipelines.GotoPipelineWithError, :call, [%{"x" => 1}])
      assert %ALF.ErrorIP{error: %CompileError{}} = result
    end
  end

  describe "pipeline with goto and helpers" do
    @components_with_helpers [
      %{
        "type" => "goto-point",
        "name" => "my-goto-point"
      },
      %{
        "type" => "stage",
        "name" => "add_one",
        "service" => %{
          "name" => "simple-math",
          "function" => "add_one"
        },
        "transform" => %{
          "x" => "args['result']"
        }
      },
      %{
        "type" => "goto",
        "name" => "my-goto",
        "to" => "my-goto-point",
        "condition" => "(fetch(args, 'x') + get(args, 'x')) <= 5",
        "helpers" => ["Helpers.FetchHelper"]
      }
    ]

    @pipeline_with_helpers %{
      "name" => "GotoPipelineWithHelpers",
      "helpers" => ["Helpers.GetHelper"],
      "components" => @components_with_helpers
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline_with_helpers)
      apply(Kraken.Pipelines.GotoPipelineWithHelpers, :start, [])

      assert apply(Kraken.Pipelines.GotoPipelineWithHelpers.MyGoto, :call, [%{"x" => 2}, %{}]) ==
               true

      assert apply(Kraken.Pipelines.GotoPipelineWithHelpers, :call, [%{"x" => 1}]) == %{"x" => 3}
    end
  end
end
