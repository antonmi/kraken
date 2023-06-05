defmodule Kraken.Define.PipelineTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Define.Pipeline
  import ExUnit.CaptureLog

  setup do
    define_and_start_service("simple-math")

    on_exit(fn ->
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
      "service" => %{
        "name" => "simple-math",
        "function" => "add"
      },
      "prepare" => %{
        "a" => "args['x']",
        "b" => "args['y']"
      },
      "transform" => %{
        "z" => "args['sum']"
      }
    },
    %{
      "type" => "stage",
      "service" => %{
        "name" => "simple-math",
        "function" => "mult_by_two"
      },
      "prepare" => %{
        "x" => "args['z']"
      },
      "transform" => %{
        "z" => "args['result']"
      }
    },
    %{
      "type" => "stage",
      "name" => "log",
      "service" => %{
        "name" => "simple-math",
        "function" => "log"
      }
    }
  ]

  @pipeline %{
    "name" => "MyPipeline",
    "components" => @components
  }

  test "define and call pipeline" do
    Pipeline.define(@pipeline)
    apply(Kraken.Pipelines.MyPipeline, :start, [])

    assert capture_log(fn ->
             result = apply(Kraken.Pipelines.MyPipeline, :call, [%{"x" => 1, "y" => 2}])
             assert result == %{"x" => 1, "y" => 2, "z" => 6}
           end) =~ "{\"z\", 6}"

    assert apply(Kraken.Pipelines.MyPipeline, :definition, []) == @pipeline
  end

  test "define and call sync pipeline" do
    Pipeline.define(Map.put(@pipeline, "name", "SyncRun"))
    apply(Kraken.Pipelines.SyncRun, :start, [[sync: true]])

    components = apply(Kraken.Pipelines.SyncRun, :components, [])
    assert Enum.all?(components, &is_reference(&1.pid))

    assert capture_log(fn ->
             result = apply(Kraken.Pipelines.SyncRun, :call, [%{"x" => 1, "y" => 2}])
             assert result == %{"x" => 1, "y" => 2, "z" => 6}
           end) =~ "{\"z\", 6}"
  end
end
