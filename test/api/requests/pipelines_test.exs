defmodule Kraken.Api.Requests.PipelinesTest do
  use ExUnit.Case
  use Plug.Test

  import Kraken.TestHelpers
  alias Kraken.Api.Router
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
    test "success" do
      conn =
        :post
        |> conn("/pipelines/define", Jason.encode!(@definition))
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":\"the-pipeline\"}"
    end

    test "error, no name" do
      definition =
        @definition
        |> put_in(["name"], nil)

      conn =
        :post
        |> conn("/pipelines/define", Jason.encode!(definition))
        |> Router.call(%{})

      assert String.contains?(conn.resp_body, "Pipeline must have name!")
    end

    test "error, no components" do
      definition =
        @definition
        |> put_in(["components"], nil)

      conn =
        :post
        |> conn("/pipelines/define", Jason.encode!(definition))
        |> Router.call(%{})

      assert String.contains?(conn.resp_body, "Missing 'components'!")
    end
  end

  describe "pipelines" do
    setup do
      Pipelines.define(@definition)
      :ok
    end

    test "returns list of defined pipelines" do
      conn =
        :get
        |> conn("/pipelines")
        |> Router.call(%{})

      pipelines = Jason.decode!(conn.resp_body)

      assert Enum.member?(pipelines, "the-pipeline")
    end
  end

  describe "status" do
    test "undefined" do
      conn =
        :get
        |> conn("/pipelines/status/undefined")
        |> Router.call(%{})

      assert conn.resp_body == "{\"status\":\":undefined\"}"
    end

    test "not_ready" do
      Pipelines.define(@definition)

      conn =
        :get
        |> conn("/pipelines/status/the-pipeline")
        |> Router.call(%{})

      assert conn.resp_body == "{\"status\":\":not_ready\"}"
    end

    test "ready" do
      Pipelines.define(@definition)
      Pipelines.start("the-pipeline")

      conn =
        :get
        |> conn("/pipelines/status/the-pipeline")
        |> Router.call(%{})

      assert conn.resp_body == "{\"status\":\":ready\"}"
    end
  end

  describe "definition" do
    setup do
      Pipelines.define(@definition)
      :ok
    end

    test "success case" do
      conn =
        :get
        |> conn("/pipelines/definition/the-pipeline")
        |> Router.call(%{})

      assert conn.resp_body == Jason.encode!(@definition)
    end

    test "error case, undefined service" do
      conn =
        :get
        |> conn("/pipelines/definition/undefined")
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":undefined\"}"
    end
  end

  describe "start" do
    setup do
      Pipelines.define(@definition)
      :ok
    end

    test "success" do
      conn =
        :post
        |> conn("/pipelines/start/the-pipeline")
        |> Router.call(%{})

      assert Jason.decode!(conn.resp_body) == %{"ok" => "Elixir.Kraken.Pipelines.ThePipeline"}
    end

    test "start with args" do
      conn =
        :post
        |> conn(
          "/pipelines/start/the-pipeline",
          Jason.encode!(%{"sync" => true, "telemetry_enabled" => true})
        )
        |> Router.call(%{})

      assert Jason.decode!(conn.resp_body) == %{"ok" => "Elixir.Kraken.Pipelines.ThePipeline"}

      Kraken.Pipelines.ThePipeline
      |> apply(:components, [])
      |> Enum.each(fn component ->
        assert component.telemetry_enabled
        assert is_reference(component.pid)
      end)
    end

    test "start with args as parameters" do
      conn =
        :post
        |> conn("/pipelines/start/the-pipeline?sync=true&telemetry_enabled=true")
        |> Router.call(%{})

      assert Jason.decode!(conn.resp_body) == %{"ok" => "Elixir.Kraken.Pipelines.ThePipeline"}

      Kraken.Pipelines.ThePipeline
      |> apply(:components, [])
      |> Enum.each(fn component ->
        assert component.telemetry_enabled
        assert is_reference(component.pid)
      end)
    end

    test "when pipeline is undefined" do
      conn =
        :post
        |> conn("/pipelines/start/undefined")
        |> Router.call(%{})

      assert String.contains?(conn.resp_body, "{\"error\":\":undefined\"}")
    end
  end

  describe "call" do
    setup do
      Pipelines.define(@definition)
      Pipelines.start("the-pipeline")
      :ok
    end

    test "success" do
      conn =
        :post
        |> conn("/pipelines/call/the-pipeline", Jason.encode!(%{"x" => 1, "y" => 2}))
        |> Router.call(%{})

      assert conn.resp_body == "{\"x\":1,\"y\":2,\"z\":3}"
    end

    test "success with return_ip true" do
      conn =
        :post
        |> conn(
          "/pipelines/call/the-pipeline?return_ip=true",
          Jason.encode!(%{"x" => 1, "y" => 2})
        )
        |> Router.call(%{})

      ip = Jason.decode!(conn.resp_body)
      assert ip["event"] == %{"x" => 1, "y" => 2, "z" => 3}
    end

    test "success with list of events" do
      list = [%{"x" => 1, "y" => 2}, %{"x" => 3, "y" => 4}]

      conn =
        :post
        |> conn("/pipelines/call/the-pipeline", Jason.encode!(list))
        |> Router.call(%{})

      assert conn.resp_body == "[{\"x\":1,\"y\":2,\"z\":3},{\"x\":3,\"y\":4,\"z\":7}]"
    end

    test "when error, returns error_ip" do
      conn =
        :post
        |> conn("/pipelines/call/the-pipeline", Jason.encode!(%{"x" => "5"}))
        |> Router.call(%{})

      error_ip = Jason.decode!(conn.resp_body)
      assert error_ip["error"]["message"] =~ "Expected Number but got String"
    end

    test "when error, pipeline is undefined" do
      conn =
        :post
        |> conn("/pipelines/call/undefined", Jason.encode!(%{}))
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":undefined\"}"
    end

    test "when error, pipeline is not_ready" do
      Pipelines.stop("the-pipeline")

      conn =
        :post
        |> conn("/pipelines/call/the-pipeline", Jason.encode!(%{}))
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":not_ready\"}"
    end
  end

  describe "cast" do
    setup do
      Pipelines.define(@definition)
      Pipelines.start("the-pipeline")
      :ok
    end

    test "success" do
      conn =
        :post
        |> conn("/pipelines/cast/the-pipeline", Jason.encode!(%{"x" => 1, "y" => 2}))
        |> Router.call(%{})

      assert conn.resp_body =~ "{\"ok\":\"0"
    end

    test "success with list of events" do
      list = [%{"x" => 1, "y" => 2}, %{"x" => 3, "y" => 4}]

      conn =
        :post
        |> conn("/pipelines/cast/the-pipeline", Jason.encode!(list))
        |> Router.call(%{})

      assert conn.resp_body =~ "{\"ok\":[\"0."
    end

    test "when error, pipeline is undefined" do
      conn =
        :post
        |> conn("/pipelines/cast/undefined", Jason.encode!(%{}))
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":undefined\"}"
    end

    test "when error, pipeline is not_ready" do
      Pipelines.stop("the-pipeline")

      conn =
        :post
        |> conn("/pipelines/cast/the-pipeline", Jason.encode!(%{}))
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":not_ready\"}"
    end
  end

  describe "stream" do
    setup do
      Pipelines.define(@definition)
      Pipelines.start("the-pipeline")
      :ok
    end

    test "success" do
      events = [%{"x" => 1, "y" => 2}, %{"x" => 3, "y" => 4}]

      conn =
        :post
        |> conn("/pipelines/stream/the-pipeline", Jason.encode!(events))
        |> Router.call(%{})

      assert conn.resp_body == "{\"x\":1,\"y\":2,\"z\":3}{\"x\":3,\"y\":4,\"z\":7}"
    end

    test "success with return_ip=true" do
      list = [%{"x" => 1, "y" => 2}, %{"x" => 3, "y" => 4}]

      conn =
        :post
        |> conn("/pipelines/stream/the-pipeline?return_ip=true", Jason.encode!(list))
        |> Router.call(%{})

      assert conn.resp_body =~ "event\":{\"x\":1,\"y\":2,\"z\":3}"
      assert conn.resp_body =~ "event\":{\"x\":3,\"y\":4,\"z\":7}"
    end

    test "when error, pipeline is undefined" do
      conn =
        :post
        |> conn("/pipelines/stream/undefined", Jason.encode!(%{}))
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":undefined\"}"
    end

    test "when error, pipeline is not_ready" do
      Pipelines.stop("the-pipeline")

      conn =
        :post
        |> conn("/pipelines/stream/the-pipeline", Jason.encode!(%{}))
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":not_ready\"}"
    end
  end

  describe "stop" do
    setup do
      Pipelines.define(@definition)
      Pipelines.start("the-pipeline")
      :ok
    end

    test "success" do
      conn =
        :post
        |> conn("/pipelines/stop/the-pipeline")
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":\"ok\"}"
      assert Pipelines.status("the-pipeline") == :not_ready
    end

    test "error, when not started" do
      Pipelines.stop("the-pipeline")

      conn =
        :post
        |> conn("/pipelines/stop/the-pipeline")
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":not_ready\"}"
    end

    test "error, when undefined" do
      conn =
        :post
        |> conn("/pipelines/stop/undefined")
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":undefined\"}"
    end
  end

  describe "delete" do
    setup do
      Pipelines.define(@definition)
      :ok
    end

    test "success when not ready" do
      assert Pipelines.status("the-pipeline") == :not_ready

      conn =
        :post
        |> conn("/pipelines/delete/the-pipeline")
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":\"ok\"}"
      assert Pipelines.status("the-pipeline") == :undefined
    end

    test "success when ready" do
      Pipelines.start("the-pipeline")
      assert Pipelines.status("the-pipeline") == :ready

      conn =
        :post
        |> conn("/pipelines/delete/the-pipeline")
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":\"ok\"}"
      assert Pipelines.status("the-pipeline") == :undefined
    end

    test "error, when not defined" do
      conn =
        :post
        |> conn("/pipelines/delete/undefined")
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":undefined\"}"
    end
  end
end
