defmodule Kraken.Define.DoneTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Define.Pipeline

  setup do
    define_and_start_service("simple-math")

    on_exit(fn ->
      Octopus.delete("simple-math")
    end)
  end

  describe "simple pipeline with done" do
    @components [
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
        "type" => "done",
        "name" => "done-if-more-than-2",
        "condition" => "args['x'] > 2"
      },
      %{
        "type" => "stage",
        "name" => "mult_by_two",
        "service" => %{
          "name" => "simple-math",
          "function" => "mult_by_two"
        },
        "transform" => %{
          "x" => "args['result']"
        }
      }
    ]

    @pipeline %{
      "name" => "DonePipeline",
      "components" => @components
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline)
      apply(Kraken.Pipelines.DonePipeline, :start, [])

      assert apply(Kraken.Pipelines.DonePipeline, :call, [%{"x" => 1}]) == %{"x" => 4}
      assert apply(Kraken.Pipelines.DonePipeline, :call, [%{"x" => 2}]) == %{"x" => 3}
    end
  end

  describe "done without condition (true by default)" do
    @components [
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
        "type" => "done",
        "name" => "done-always"
      },
      %{
        "type" => "stage",
        "name" => "mult_by_two",
        "service" => %{
          "name" => "simple-math",
          "function" => "mult_by_two"
        },
        "transform" => %{
          "x" => "args['result']"
        }
      }
    ]

    @pipeline %{
      "name" => "DoneTruePipeline",
      "components" => @components
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline)
      apply(Kraken.Pipelines.DoneTruePipeline, :start, [])

      assert apply(Kraken.Pipelines.DoneTruePipeline, :call, [%{"x" => 1}]) == %{"x" => 2}
      assert apply(Kraken.Pipelines.DoneTruePipeline, :call, [%{"x" => 2}]) == %{"x" => 3}
    end
  end

  describe "error in done" do
    @components_with_error_in_condition [
      %{
        "type" => "done",
        "name" => "done-if-more-than-2",
        "condition" => "args['x'] > qwerty"
      }
    ]

    @pipeline_with_error_in_condition %{
      "name" => "DonePipelineWithError",
      "components" => @components_with_error_in_condition
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline_with_error_in_condition)
      apply(Kraken.Pipelines.DonePipelineWithError, :start, [])

      result = apply(Kraken.Pipelines.DonePipelineWithError, :call, [%{"x" => 1}])
      assert %ALF.ErrorIP{error: %CompileError{}} = result
    end
  end

  describe "pipeline with done and helpers" do
    @components_with_helpers [
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
        "type" => "done",
        "name" => "done-if-big-enough",
        "condition" => "(fetch(args, 'x') + get(args, 'x')) > 4",
        "helpers" => ["Helpers.FetchHelper"]
      },
      %{
        "type" => "stage",
        "name" => "mult_by_two",
        "service" => %{
          "name" => "simple-math",
          "function" => "mult_by_two"
        },
        "transform" => %{
          "x" => "args['result']"
        }
      }
    ]

    @pipeline_with_helpers %{
      "name" => "DonePipelineWithHelpers",
      "helpers" => ["Helpers.GetHelper"],
      "components" => @components_with_helpers
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline_with_helpers)
      apply(Kraken.Pipelines.DonePipelineWithHelpers, :start, [])

      assert apply(Kraken.Pipelines.DonePipelineWithHelpers, :call, [%{"x" => 1}]) == %{"x" => 4}
      assert apply(Kraken.Pipelines.DonePipelineWithHelpers, :call, [%{"x" => 2}]) == %{"x" => 3}
    end
  end
end
