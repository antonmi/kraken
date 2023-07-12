defmodule Kraken.Define.SwitchTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Define.Switch
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

  @switch %{
    "type" => "switch",
    "name" => "my-switch",
    "prepare" => %{
      "number" => "args['x']"
    },
    "branches" => %{
      "branch1" => [],
      "branch2" => []
    },
    "condition" => "if args['number'] <= 3, do: \"branch1\", else: \"branch2\""
  }

  test "define and call stage" do
    switch_module = Kraken.Pipelines.SwitchPipeline.MySwitch
    {:ok, ^switch_module} = Switch.define(@switch, switch_module)

    assert "branch1" = apply(switch_module, :call, [%{"x" => 2}, %{}])
    assert "branch2" = apply(switch_module, :call, [%{"x" => 4}, %{}])

    assert_raise RuntimeError, "Event must be a map", fn ->
      apply(switch_module, :call, ["error", %{}])
    end
  end

  @add %{
    "type" => "stage",
    "name" => "add",
    "service" => %{
      "name" => "simple-math",
      "function" => "add"
    },
    "transform" => %{
      "sum" => "args['sum']"
    }
  }

  @mult %{
    "type" => "stage",
    "name" => "mult",
    "service" => %{
      "name" => "simple-math",
      "function" => "mult_by_two"
    },
    "prepare" => %{
      "x" => "args['sum']"
    },
    "transform" => %{
      "x" => "args['result']"
    }
  }

  @add_one %{
    "type" => "stage",
    "name" => "add-one",
    "service" => %{
      "name" => "simple-math",
      "function" => "add_one"
    },
    "prepare" => %{
      "x" => "args['sum']"
    },
    "transform" => %{
      "x" => "args['result']"
    }
  }

  describe "simple pipeline with switch" do
    @components [
      @add,
      %{
        "type" => "switch",
        "name" => "my-switch",
        "prepare" => %{
          "number" => "args['sum']"
        },
        "branches" => %{
          "branch1" => [@mult],
          "branch2" => [@add_one]
        },
        "condition" => "if args['number'] <= 3, do: \"branch1\", else: \"branch2\""
      }
    ]

    @pipeline %{
      "name" => "SwitchPipeline",
      "components" => @components
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline)
      apply(Kraken.Pipelines.SwitchPipeline, :start, [])

      result = apply(Kraken.Pipelines.SwitchPipeline, :call, [%{"a" => 1, "b" => 2}])
      assert result == %{"a" => 1, "b" => 2, "sum" => 3, "x" => 6}

      result = apply(Kraken.Pipelines.SwitchPipeline, :call, [%{"a" => 2, "b" => 2}])
      assert result == %{"a" => 2, "b" => 2, "sum" => 4, "x" => 5}
    end
  end

  describe "error in condition" do
    @components_with_error_in_condition [
      %{
        "type" => "switch",
        "name" => "my-switch",
        "prepare" => %{
          "number" => "args['sum']"
        },
        "branches" => %{"branch1" => []},
        "condition" => "ifffff args['number'] <= 3, do: \"branch1\", else: \"branch2\""
      }
    ]

    @pipeline_with_error_in_condition %{
      "name" => "SwitchPipelineWithError",
      "components" => @components_with_error_in_condition
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline_with_error_in_condition)
      apply(Kraken.Pipelines.SwitchPipelineWithError, :start, [])

      result = apply(Kraken.Pipelines.SwitchPipelineWithError, :call, [%{"sum" => 1}])
      assert %ALF.ErrorIP{error: %CompileError{}} = result
    end
  end

  describe "simple pipeline with switch and helpers" do
    @components_with_helpers [
      @add,
      %{
        "type" => "switch",
        "name" => "my-switch",
        "helpers" => ["Helpers.FetchHelper"],
        "prepare" => %{
          "number" => "fetch(args, 'sum')"
        },
        "branches" => %{
          "branch1" => [@mult],
          "branch2" => [@add_one]
        },
        "condition" => "if get(args, 'number') <= 3, do: \"branch1\", else: \"branch2\""
      }
    ]

    @pipeline_with_helpers %{
      "name" => "SwitchPipelineWithHelpers",
      "helpers" => ["Helpers.GetHelper"],
      "components" => @components_with_helpers
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline_with_helpers)
      apply(Kraken.Pipelines.SwitchPipelineWithHelpers, :start, [])

      result = apply(Kraken.Pipelines.SwitchPipelineWithHelpers, :call, [%{"a" => 1, "b" => 2}])
      assert result == %{"a" => 1, "b" => 2, "sum" => 3, "x" => 6}

      result = apply(Kraken.Pipelines.SwitchPipelineWithHelpers, :call, [%{"a" => 2, "b" => 2}])
      assert result == %{"a" => 2, "b" => 2, "sum" => 4, "x" => 5}
    end
  end
end
