defmodule KrakenTest do
  use ExUnit.Case, async: true
  import Kraken.TestHelpers
  alias Kraken.Pipelines

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

  @pipeline %{
    "name" => "the-pipeline",
    "components" => [@component]
  }

  @routes %{"the-event" => "the-pipeline"}

  setup do
    define_and_start_service("simple-math")
    {:ok, "the-pipeline"} = Pipelines.define(@pipeline)
    {:ok, _module} = Pipelines.start("the-pipeline")
    {:ok, _module} = Kraken.Routes.define(@routes)

    on_exit(fn ->
      Octopus.stop("simple-math")
      Octopus.delete("simple-math")
      Pipelines.delete("the-pipeline")
      Kraken.Routes.delete()
    end)
  end

  test "test pipeline" do
    out = %{"x" => 1, "y" => 2, "z" => 3}
    assert Pipelines.call("the_pipeline", %{"x" => 1, "y" => 2}) == out
  end

  test "route" do
    assert Kraken.Routes.all() == {:ok, @routes}
  end

  @event %{"type" => "the-event", "x" => 1, "y" => 2}

  describe "call" do
    test "success" do
      out = %{"type" => "the-event", "x" => 1, "y" => 2, "z" => 3}
      assert Kraken.call(@event) == out
    end

    test "success with return_ip option" do
      out = %{"type" => "the-event", "x" => 1, "y" => 2, "z" => 3}
      assert %ALF.IP{event: ^out} = Kraken.call(@event, %{"return_ip" => true})
    end

    test "when no type in event" do
      assert {:error, :no_type} = Kraken.call(Map.put(@event, "type", nil))
    end

    test "when no route for the type" do
      assert {:error, :no_route_for_type} = Kraken.call(Map.put(@event, "type", "unknown"))
    end

    test "when pipeline is not ready" do
      Pipelines.stop("the-pipeline")
      assert {:error, :not_ready} = Kraken.call(@event)
    end

    test "when service is stopped" do
      Octopus.stop("simple-math")
      %ALF.ErrorIP{error: error} = Kraken.call(@event)
      assert error == %RuntimeError{message: ":not_ready"}
    end
  end

  describe "call with list of different events" do
    @another_pipeline %{
      "name" => "another-pipeline",
      "components" => [@component]
    }

    @events [
      %{"type" => "the-event", "x" => 1, "y" => 2},
      %{"type" => "the-event", "x" => 3, "y" => 4},
      %{"type" => "another-event", "x" => 1, "y" => 2},
      %{"type" => "another-event", "x" => 3, "y" => 4}
    ]

    setup do
      {:ok, "another-pipeline"} = Pipelines.define(@another_pipeline)
      {:ok, _module} = Pipelines.start("another-pipeline")

      on_exit(fn ->
        Pipelines.delete("another-pipeline")
      end)

      :ok = Kraken.Routes.delete()
      routes = Map.put(@routes, "another-event", "another-pipeline")
      {:ok, _module} = Kraken.Routes.define(routes)
      :ok
    end

    test "success" do
      results = Kraken.call(@events)
      assert Enum.member?(results, %{"type" => "another-event", "x" => 1, "y" => 2, "z" => 3})
      assert Enum.member?(results, %{"type" => "another-event", "x" => 3, "y" => 4, "z" => 7})
      assert Enum.member?(results, %{"type" => "the-event", "x" => 1, "y" => 2, "z" => 3})
      assert Enum.member?(results, %{"type" => "the-event", "x" => 3, "y" => 4, "z" => 7})
    end

    test "success with return_ip=true" do
      results =
        @events
        |> Kraken.call(%{"return_ip" => true})
        |> Enum.map(& &1.event)

      assert Enum.member?(results, %{"type" => "another-event", "x" => 1, "y" => 2, "z" => 3})
      assert Enum.member?(results, %{"type" => "another-event", "x" => 3, "y" => 4, "z" => 7})
      assert Enum.member?(results, %{"type" => "the-event", "x" => 1, "y" => 2, "z" => 3})
      assert Enum.member?(results, %{"type" => "the-event", "x" => 3, "y" => 4, "z" => 7})
    end

    test "when no type in event" do
      events = [%{"x" => 1, "y" => 2} | @events]
      results = Kraken.call(events)
      assert length(results) == 5
      assert Enum.member?(results, {:error, :no_type})
    end

    test "when no route for the type" do
      events = [%{"type" => "unknown", "x" => 1, "y" => 2} | @events]
      results = Kraken.call(events)
      assert length(results) == 5
      assert Enum.member?(results, {:error, :no_route_for_type})
    end

    test "when pipeline is not ready" do
      Pipelines.stop("the-pipeline")
      results = Kraken.call(@events)
      assert length(results) == 3
      assert Enum.member?(results, {:error, :not_ready})
    end

    test "when service is stopped" do
      Octopus.stop("simple-math")
      results = Kraken.call(@events)
      assert length(results) == 4
      %ALF.ErrorIP{error: error} = hd(results)
      assert error == %RuntimeError{message: ":not_ready"}
    end
  end
end
