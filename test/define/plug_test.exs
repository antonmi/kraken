defmodule Kraken.Define.PlugTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Define.Pipeline

  setup do
    define_and_start_service("simple-math")

    on_exit(fn ->
      Octopus.stop("simple-math")
      Octopus.delete("simple-math")
    end)
  end

  test "simple-math service" do
    {:ok, result} = Octopus.call("simple-math", "add", %{"a" => 1, "b" => 2})
    assert result == %{"sum" => 3}
  end

  @components [
    %{
      "type" => "stage",
      "name" => "add",
      "service" => %{
        "name" => "simple-math",
        "function" => "add"
      },
      "download" => %{
        "a" => "args['x']",
        "b" => "args['y']"
      },
      "upload" => %{
        "z" => "args['sum']"
      }
    },
    %{
      "type" => "stage",
      "name" => "mult",
      "service" => %{
        "name" => "simple-math",
        "function" => "mult_by_two"
      },
      "download" => %{
        "x" => "args['z']"
      },
      "upload" => %{
        "z" => "args['result']"
      }
    }
  ]

  @pipeline %{
    "name" => "AddMultPipeline",
    "components" => @components
  }

  test "define and call pipeline" do
    Pipeline.define(@pipeline)
    apply(Kraken.Pipelines.AddMultPipeline, :start, [])

    result = apply(Kraken.Pipelines.AddMultPipeline, :call, [%{"x" => 1, "y" => 2}])
    assert result == %{"x" => 1, "y" => 2, "z" => 6}
  end

  describe "plug" do
    @plug %{
      "type" => "plug",
      "name" => "my-plug",
      "pipeline" => "AddMultPipeline",
      "download" => %{
        "x" => "args['xxx']",
        "y" => "args['yyy']"
      },
      "upload" => %{
        "zzz" => "args['z']"
      }
    }

    @extended_pipeline %{
      "name" => "ExtendedPipeline",
      "components" => [@plug]
    }

    test "plug module" do
      Pipeline.define(@pipeline)
      Pipeline.define(@extended_pipeline)
      plug_module = Kraken.Pipelines.ExtendedPipeline.MyPlug
      result = apply(plug_module, :plug, [%{"xxx" => 1, "yyy" => 2}, %{}])
      assert result == %{"x" => 1, "y" => 2}

      result = apply(plug_module, :unplug, [%{"z" => 3}, %{"xxx" => 1, "yyy" => 2}, %{}])
      assert result == %{"xxx" => 1, "yyy" => 2, "zzz" => 3}
    end

    test "define and call pipeline" do
      Pipeline.define(@pipeline)
      Pipeline.define(@extended_pipeline)
      apply(Kraken.Pipelines.ExtendedPipeline, :start, [])

      result = apply(Kraken.Pipelines.ExtendedPipeline, :call, [%{"xxx" => 1, "yyy" => 2}])
      assert result == %{"xxx" => 1, "yyy" => 2, "zzz" => 6}
    end
  end

  describe "plug with helpers" do
    @plug_with_helpers %{
      "type" => "plug",
      "name" => "my-plug",
      "pipeline" => "AddMultPipeline",
      "download" => %{
        "x" => "fetch(args, 'xxx')",
        "y" => "fetch(args, 'yyy')"
      },
      "upload" => %{
        "zzz" => "get(args, 'z')"
      },
      "helpers" => ["Helpers.FetchHelper"]
    }

    @extended_pipeline_with_helpers %{
      "name" => "ExtendedPipelineWithHelpers",
      "helpers" => ["Helpers.GetHelper"],
      "components" => [@plug_with_helpers]
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline)
      Pipeline.define(@extended_pipeline_with_helpers)
      apply(Kraken.Pipelines.ExtendedPipelineWithHelpers, :start, [])

      result =
        apply(Kraken.Pipelines.ExtendedPipelineWithHelpers, :call, [%{"xxx" => 1, "yyy" => 2}])

      assert result == %{"xxx" => 1, "yyy" => 2, "zzz" => 6}
    end
  end
end
