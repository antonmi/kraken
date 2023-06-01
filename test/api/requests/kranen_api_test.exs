defmodule Kraken.Api.Requests.KrakenApiTest do
  use ExUnit.Case
  use Plug.Test

  import Kraken.TestHelpers
  alias Kraken.Api.Router
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

  @definition %{
    "name" => "the-pipeline",
    "components" => [@component]
  }

  @routes %{"math" => "the-pipeline"}

  @event %{"type" => "math", "x" => 1, "y" => 2}

  setup do
    define_and_start_service("simple-math")

    Pipelines.define(@definition)
    Pipelines.start("the-pipeline")
    {:ok, _module} = Kraken.Routes.define(@routes)

    on_exit(fn ->
      Octopus.stop("simple-math")
      Octopus.delete("simple-math")
      Pipelines.delete("the-pipeline")
      Kraken.Routes.delete()
    end)
  end

  describe "call" do
    test "success" do
      conn =
        :post
        |> conn("/call", Jason.encode!(@event))
        |> Router.call(%{})

      assert conn.resp_body == "{\"type\":\"math\",\"x\":1,\"y\":2,\"z\":3}"
    end

    test "success with return_ip true" do
      conn =
        :post
        |> conn(
          "/pipelines/call/the-pipeline?return_ip=true",
          Jason.encode!(@event)
        )
        |> Router.call(%{})

      ip = Jason.decode!(conn.resp_body)
      assert ip["event"] == %{"type" => "math", "x" => 1, "y" => 2, "z" => 3}
    end

    test "success with list of events" do
      list = [@event, %{"type" => "math", "x" => 1, "y" => 2}]

      conn =
        :post
        |> conn("/call", Jason.encode!(list))
        |> Router.call(%{})

      assert conn.resp_body ==
               "[{\"type\":\"math\",\"x\":1,\"y\":2,\"z\":3},{\"type\":\"math\",\"x\":1,\"y\":2,\"z\":3}]"
    end

    test "when error, returns error_ip" do
      conn =
        :post
        |> conn("/call", Jason.encode!(%{"type" => "math", "x" => "string"}))
        |> Router.call(%{})

      error_ip = Jason.decode!(conn.resp_body)
      assert error_ip["error"]["message"] =~ "Expected Number but got String"
    end

    test "error, no type" do
      conn =
        :post
        |> conn("/call", Jason.encode!(%{"x" => "string"}))
        |> Router.call(%{})

      assert Jason.decode!(conn.resp_body) == %{"error" => ":no_type"}
    end

    test "error, no route for type" do
      conn =
        :post
        |> conn("/call", Jason.encode!(Map.put(@event, "type", "undefined")))
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":no_route_for_type\"}"
    end

    test "error, pipeline is not_ready" do
      Pipelines.stop("the-pipeline")

      conn =
        :post
        |> conn("/call", Jason.encode!(@event))
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":not_ready\"}"
    end
  end

  describe "cast" do
    test "success" do
      conn =
        :post
        |> conn("/cast", Jason.encode!(@event))
        |> Router.call(%{})

      assert conn.resp_body =~ "{\"ok\":\"0"
    end

    test "success with list of events" do
      list = [@event, %{"type" => "math", "x" => 3, "y" => 4}]

      conn =
        :post
        |> conn("/cast", Jason.encode!(list))
        |> Router.call(%{})

      assert conn.resp_body =~ "{\"ok\":[\"0."
    end

    test "error, pipeline is not_ready" do
      Pipelines.stop("the-pipeline")

      conn =
        :post
        |> conn("/cast", Jason.encode!(@event))
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":not_ready\"}"
    end
  end

  describe "stream" do
    test "success" do
      events = [@event, %{"type" => "math", "x" => 3, "y" => 4}]

      conn =
        :post
        |> conn("/stream", Jason.encode!(events))
        |> Router.call(%{})

      assert conn.resp_body ==
               "{\"type\":\"math\",\"x\":1,\"y\":2,\"z\":3}{\"type\":\"math\",\"x\":3,\"y\":4,\"z\":7}"
    end

    test "success with return_ip=true" do
      events = [@event, %{"type" => "math", "x" => 3, "y" => 4}]

      conn =
        :post
        |> conn("/stream?return_ip=true", Jason.encode!(events))
        |> Router.call(%{})

      assert conn.resp_body =~ "event\":{\"type\":\"math\",\"x\":1,\"y\":2,\"z\":3}"
      assert conn.resp_body =~ "event\":{\"type\":\"math\",\"x\":3,\"y\":4,\"z\":7}"
    end

    test "when error, pipeline is not_ready" do
      Pipelines.stop("the-pipeline")
      events = [@event, %{"type" => "math", "x" => 3, "y" => 4}]

      conn =
        :post
        |> conn("/stream", Jason.encode!(events))
        |> Router.call(%{})

      assert conn.resp_body == "[\"error\",\"not_ready\"][\"error\",\"not_ready\"]"
    end
  end
end
