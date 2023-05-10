defmodule Kraken.Define.PipelineTest do
  use ExUnit.Case

  alias Kraken.Test.Definitions
  alias Kraken.Define.Pipeline

  import ExUnit.CaptureLog

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
      # TODO it seems that the only way to use it is in "download" and "upload".
      "opts" => %{},
      "download" => %{
        # TODO what if opts can be accessed here?
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
      "opts" => %{},
      "download" => %{
        "x" => "args['z']"
      },
      "upload" => %{
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
    Kraken.Pipelines.MyPipeline.start()

    assert capture_log(fn ->
             assert %{"z" => 6} = Kraken.Pipelines.MyPipeline.call(%{"x" => 1, "y" => 2})
           end) =~ "{\"z\", 6}"
  end
end
