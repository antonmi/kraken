defmodule Kraken.Define.CloneWithDeadEndTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Define.Pipeline
  import ExUnit.CaptureLog

  describe "simple pipeline with clone and dead-end" do
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

    @components [
      %{
        "type" => "stage",
        "name" => "add",
        "service" => %{
          "name" => "simple-math",
          "function" => "add"
        },
        "transform" => %{
          "sum" => "args['sum']"
        }
      },
      %{
        "type" => "clone",
        "name" => "my-clone",
        "to" => [
          %{
            "type" => "stage",
            "name" => "log",
            "service" => %{
              "name" => "simple-math",
              "function" => "log"
            }
          },
          %{
            "type" => "dead-end",
            "name" => "dead-end"
          }
        ]
      },
      %{
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
    ]

    @pipeline %{
      "name" => "ClonePipeline",
      "components" => @components
    }

    test "define and call pipeline" do
      Pipeline.define(@pipeline)
      apply(Kraken.Pipelines.ClonePipeline, :start, [])

      assert capture_log(fn ->
               result = apply(Kraken.Pipelines.ClonePipeline, :call, [%{"a" => 1, "b" => 2}])
               assert result == %{"a" => 1, "b" => 2, "x" => 4, "sum" => 3}
             end) =~ "{\"sum\", 3}"
    end
  end
end
