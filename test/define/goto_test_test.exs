defmodule Kraken.Define.GotoTest do
  use ExUnit.Case

  alias Kraken.Test.Definitions
  alias Kraken.Define.Clone
  alias Kraken.Define.Pipeline

  describe "simple pipeline with goto" do
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
        "upload" => %{
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
      Kraken.Pipelines.GotoPipeline.start()

      Kraken.Pipelines.GotoPipeline.MyGoto.call(%{"x" => 2}, %{})

      assert %{"x" => 4} = Kraken.Pipelines.GotoPipeline.call(%{"x" => 1})
    end
  end
end
