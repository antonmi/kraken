defmodule Kraken.Define.StageTest do
  use ExUnit.Case

  alias Kraken.Test.Definitions
  alias Kraken.Define.Stage

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
  end

  @component %{
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
  }

  test "define and call stage" do
    {:ok, stage_module} = Stage.define(@component, Kraken.Pipelines.MyPipeline)
    assert stage_module == Kraken.Pipelines.MyPipeline.Add

    assert %{"z" => 3} = apply(stage_module, :call, [%{"x" => 1, "y" => 2}, %{}])

    assert_raise RuntimeError, "Event must be a map", fn ->
      apply(stage_module, :call, ["error", %{}])
    end

    assert_raise RuntimeError, fn ->
      apply(stage_module, :call, [%{"x" => "error"}, %{}])
    end
  end
  
  describe "opts in stage" do
    
  end
end
