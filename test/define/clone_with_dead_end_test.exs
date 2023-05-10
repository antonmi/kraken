defmodule Kraken.Define.CloneWithDeadEndTest do
  use ExUnit.Case

  alias Kraken.Test.Definitions
  alias Kraken.Define.Clone
  alias Kraken.Define.Pipeline

  import ExUnit.CaptureLog

  describe "simple pipeline with clone and dead-end" do
    def define_and_start_service(name) do
      {:ok, ^name} =
        "services/#{name}.json"
        |> Definitions.read_and_decode()
        |> Octopus.define()

      {:ok, _code} = Octopus.start(name)
    end

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
      assert {:ok, %{"result" => 6}} = Octopus.call("simple-math", "add_one", %{"x" => 5})
    end

    @components [
      %{
        "type" => "stage",
        "name" => "add",
        "service" => %{
          "name" => "simple-math",
          "function" => "add"
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
        "download" => %{
          "x" => "args['sum']"
        },
        "upload" => %{
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
      Kraken.Pipelines.ClonePipeline.start()

      assert capture_log(fn ->
               assert %{"x" => 4} = Kraken.Pipelines.ClonePipeline.call(%{"a" => 1, "b" => 2})
             end) =~ "{\"sum\", 3}"
    end
  end
end
