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

  describe "simple pipeline with goto" do
    test "simple-math service" do
      assert {:ok, %{"sum" => 3}} = Octopus.call("simple-math", "add", %{"a" => 1, "b" => 2})
      assert {:ok, %{"result" => 10}} = Octopus.call("simple-math", "mult_by_two", %{"x" => 5})
      assert {:ok, %{"result" => 6}} = Octopus.call("simple-math", "add_one", %{"x" => 5})
    end

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

  describe "pipeline with goto and helpers" do
    test "simple-math service" do
      assert {:ok, %{"sum" => 3}} = Octopus.call("simple-math", "add", %{"a" => 1, "b" => 2})
      assert {:ok, %{"result" => 10}} = Octopus.call("simple-math", "mult_by_two", %{"x" => 5})
      assert {:ok, %{"result" => 6}} = Octopus.call("simple-math", "add_one", %{"x" => 5})
    end

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
