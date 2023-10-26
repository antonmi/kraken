defmodule Kraken.PipelinesTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Pipelines

  setup do
    define_and_start_service("simple-math")

    on_exit(fn ->
      Octopus.stop("simple-math")
      Octopus.delete("simple-math")
      Pipelines.delete("the-pipeline")
    end)
  end

  test "simple-math service" do
    {:ok, result} = Octopus.call("simple-math", "add", %{"a" => 1, "b" => 2})
    assert result == %{"sum" => 3}
  end

  @component %{
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
  }

  @definition %{
    "name" => "the-pipeline",
    "components" => [@component]
  }

  describe "define" do
    test "success case" do
      assert {:ok, "the-pipeline"} = Pipelines.define(@definition)
      # define one more time
      assert {:ok, "the-pipeline"} = Pipelines.define(@definition)
    end

    test "define when started" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")
      # define one more time
      assert {:error, :already_started} = Pipelines.define(@definition)
    end
  end

  describe "pipelines" do
    setup do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, "another"} = Pipelines.define(Map.put(@definition, "name", "another"))

      on_exit(fn ->
        Pipelines.delete("another")
      end)
    end

    test "list of defined pipelines" do
      defined_pipelines = Pipelines.pipelines()
      assert Enum.member?(defined_pipelines, "the-pipeline")
      assert Enum.member?(defined_pipelines, "another")
    end
  end

  describe "start" do
    test "success case" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      assert {:ok, Kraken.Pipelines.ThePipeline} = Pipelines.start("the-pipeline")
      assert {:error, :already_started} = Pipelines.start("the-pipeline")
    end

    test "undefined" do
      assert {:error, :undefined} = Pipelines.start("undefined-pipeline")
    end
  end

  describe "stop" do
    test "success case" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")
      assert Pipelines.status("the-pipeline") == :ready
      assert :ok = Pipelines.stop("the-pipeline")
      assert Pipelines.status("the-pipeline") == :not_ready
    end

    test "not_ready" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      assert {:error, :not_ready} = Pipelines.stop("the-pipeline")
    end

    test "undefined" do
      assert {:error, :undefined} = Pipelines.stop("undefined-pipeline")
    end
  end

  describe "status" do
    test "undefined" do
      assert Pipelines.status("ThePipeline") == :undefined
      assert Pipelines.status("the_pipeline") == :undefined
      assert Pipelines.status("the-pipeline") == :undefined
    end

    test "not_ready" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      assert Pipelines.status("ThePipeline") == :not_ready
      assert Pipelines.status("the_pipeline") == :not_ready
      assert Pipelines.status("the-pipeline") == :not_ready
    end

    test "ready" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, Kraken.Pipelines.ThePipeline} = Pipelines.start("ThePipeline")
      assert Pipelines.status("ThePipeline") == :ready
      assert Pipelines.status("the_pipeline") == :ready
      assert Pipelines.status("the-pipeline") == :ready
    end
  end

  describe "definition" do
    test "success case" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      assert Pipelines.definition("the_pipeline") == {:ok, @definition}
    end

    test "when undefined" do
      assert Pipelines.definition("undefined") == {:error, :undefined}
    end
  end

  describe "delete" do
    test "success case" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      assert :ok = Pipelines.delete("the-pipeline")
      assert Pipelines.status("the-pipeline") == :undefined
    end

    test "when started" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")
      assert Pipelines.status("the-pipeline") == :ready
      assert :ok = Pipelines.delete("the-pipeline")
      assert Pipelines.status("the-pipeline") == :undefined
    end

    test "when undefined" do
      assert Pipelines.definition("undefined") == {:error, :undefined}
    end
  end

  describe "call" do
    test "success case" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")

      assert Pipelines.call("the_pipeline", %{"x" => 1, "y" => 2}) == %{
               "x" => 1,
               "y" => 2,
               "z" => 3
             }
    end

    test "success case with debug: true" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")

      assert %ALF.IP{} =
               Pipelines.call("the_pipeline", %{"x" => 1, "y" => 2}, %{"debug" => true})
    end

    test "error in the pipeline, it returns error ip" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")
      assert %ALF.ErrorIP{} = Pipelines.call("the_pipeline", %{"x" => 1, "y" => "string"})
    end

    test "call with a list of arguments" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")
      events = [%{"x" => 1, "y" => 2}, %{"x" => 3, "y" => 4}]

      assert Pipelines.call("the_pipeline", events) == [
               %{"x" => 1, "y" => 2, "z" => 3},
               %{"x" => 3, "y" => 4, "z" => 7}
             ]
    end

    test "when is not started" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      assert {:error, :not_ready} = Pipelines.call("the_pipeline", %{"x" => 1, "y" => 2})
    end

    test "when undefined" do
      assert {:error, :undefined} = Pipelines.call("undefined", %{"x" => 1, "y" => 2})
    end
  end

  describe "cast" do
    test "success case" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")

      ref = Pipelines.cast("the_pipeline", %{"x" => 1, "y" => 2})
      assert is_reference(ref)
    end

    test "success case with send_result: true" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")

      ref = Pipelines.cast("the_pipeline", %{"x" => 1, "y" => 2}, %{"send_result" => true})

      receive do
        {^ref, %ALF.IP{event: event}} ->
          assert event == %{"x" => 1, "y" => 2, "z" => 3}
      end
    end

    test "call with a list of arguments" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")
      events = [%{"x" => 1, "y" => 2}, %{"x" => 3, "y" => 4}]

      [ref1, ref2] = Pipelines.cast("the_pipeline", events)
      assert is_reference(ref1)
      assert is_reference(ref2)
    end

    test "call with a list of arguments and send_result => true" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")
      events = [%{"x" => 1, "y" => 2}, %{"x" => 3, "y" => 4}]

      [ref1, ref2] = Pipelines.cast("the_pipeline", events, %{"send_result" => "true"})

      receive do
        {^ref1, %ALF.IP{event: event}} ->
          assert event == %{"x" => 1, "y" => 2, "z" => 3}
      end

      receive do
        {^ref2, %ALF.IP{event: event}} ->
          assert event == %{"x" => 3, "y" => 4, "z" => 7}
      end
    end

    test "when is not started" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      assert {:error, :not_ready} = Pipelines.cast("the_pipeline", %{"x" => 1, "y" => 2})
    end

    test "when undefined" do
      assert {:error, :undefined} = Pipelines.cast("undefined", %{"x" => 1, "y" => 2})
    end
  end

  describe "stream" do
    test "success case" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")

      events = [%{"x" => 1, "y" => 2}, %{"x" => 3, "y" => 4}]

      stream = Pipelines.stream("the_pipeline", events)
      assert is_function(stream)

      assert Enum.to_list(stream) == [
               %{"x" => 1, "y" => 2, "z" => 3},
               %{"x" => 3, "y" => 4, "z" => 7}
             ]
    end

    test "success case with debug: true" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      {:ok, _module} = Pipelines.start("the-pipeline")

      events = [%{"x" => 1, "y" => 2}, %{"x" => 3, "y" => 4}]
      stream = Pipelines.stream("the_pipeline", events, %{"debug" => "true"})

      assert [%ALF.IP{}, %ALF.IP{}] = Enum.to_list(stream)
    end

    test "when is not started" do
      {:ok, "the-pipeline"} = Pipelines.define(@definition)
      assert {:error, :not_ready} = Pipelines.stream("the_pipeline", [%{"x" => 1, "y" => 2}])
    end

    test "when undefined" do
      assert {:error, :undefined} = Pipelines.stream("undefined", [%{"x" => 1, "y" => 2}])
    end
  end
end
