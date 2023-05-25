defmodule Kraken.Api.Requests.ServicesTest do
  use ExUnit.Case
  use Plug.Test

  alias Kraken.Test.Definitions
  alias Kraken.Api.Router
  alias Kraken.Services

  @definition Definitions.read_and_decode("services/simple-math.json")

  setup do
    on_exit(fn ->
      Services.delete("simple-math")
    end)
  end

  describe "define" do
    test "success" do
      conn =
        :post
        |> conn("/services/define", Jason.encode!(@definition))
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":\"simple-math\"}"
    end

    test "error" do
      definition =
        @definition
        |> put_in(["name"], nil)

      conn =
        :post
        |> conn("/services/define", Jason.encode!(definition))
        |> Router.call(%{})

      assert String.contains?(conn.resp_body, "Missing service name!")
    end
  end

  describe "define several services" do
    @another_definition Map.put(@definition, "name", "the-same-simple-math")

    test "success" do
      definitions = [@definition, @another_definition]

      conn =
        :post
        |> conn("/services/define", Jason.encode!(definitions))
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":[\"simple-math\",\"the-same-simple-math\"]}"
    end

    test "error" do
      definition = Map.put(@definition, "name", nil)
      definitions = [definition, @another_definition]

      conn =
        :post
        |> conn("/services/define", Jason.encode!(definitions))
        |> Router.call(%{})

      assert String.contains?(conn.resp_body, "Missing service name!")
    end
  end

  describe "status" do
    setup do
      Services.define(@definition)
      :ok
    end

    test "works with get" do
      conn =
        :get
        |> conn("/services/status/simple-math")
        |> Router.call(%{})

      assert conn.resp_body == "{\"status\":\":not_ready\"}"
    end
  end

  describe "definition" do
    setup do
      Services.define(@definition)
      :ok
    end

    test "success case" do
      conn =
        :get
        |> conn("/services/definition/simple-math")
        |> Router.call(%{})

      assert conn.resp_body == Jason.encode!(@definition)
    end

    test "error case, undefined service" do
      conn =
        :get
        |> conn("/services/definition/undefined")
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":undefined\"}"
    end
  end

  describe "state" do
    setup do
      Services.define(@definition)
      :ok
    end

    test "success case" do
      Services.start("simple-math")

      conn =
        :get
        |> conn("/services/state/simple-math")
        |> Router.call(%{})

      assert conn.resp_body =~ "defmodule SimpleMath do"
    end

    test "error case, not ready" do
      conn =
        :get
        |> conn("/services/state/simple-math")
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":not_ready\"}"
    end

    test "error case, undefined service" do
      conn =
        :get
        |> conn("/services/state/undefined")
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":undefined\"}"
    end
  end

  describe "start" do
    setup do
      Services.define(@definition)
      :ok
    end

    test "success" do
      conn =
        :post
        |> conn("/services/start/simple-math")
        |> Router.call(%{})

      assert %{"ok" => code} = Jason.decode!(conn.resp_body)
      assert String.starts_with?(code, "defmodule SimpleMath do")
    end

    test "error" do
      conn =
        :post
        |> conn("/services/start/undefined-math")
        |> Router.call(%{})

      assert String.contains?(conn.resp_body, "{\"error\":\":undefined\"}")
    end
  end

  describe "call" do
    setup do
      Services.define(@definition)
      Services.start("simple-math")
      :ok
    end

    test "success" do
      conn =
        :post
        |> conn("/services/call/simple-math/add", Jason.encode!(%{"a" => 1, "b" => 2}))
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":{\"sum\":3}}"
    end

    test "error" do
      conn =
        :post
        |> conn("/services/call/simple-math/add", Jason.encode!(%{"x" => "5"}))
        |> Router.call(%{})

      assert String.contains?(conn.resp_body, "FunctionClauseError")
    end
  end

  describe "stop" do
    setup do
      Services.define(@definition)
      Services.start("simple-math")
      :ok
    end

    test "success" do
      conn =
        :post
        |> conn("/services/stop/simple-math")
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":\"ok\"}"
      assert Services.status("simple-math") == :not_ready
    end

    test "error, when not started" do
      Services.stop("simple-math")

      conn =
        :post
        |> conn("/services/stop/simple-math")
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":not_ready\"}"
    end
  end

  describe "delete" do
    setup do
      Services.define(@definition)
      :ok
    end

    test "success" do
      conn =
        :post
        |> conn("/services/delete/simple-math")
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":\"ok\"}"
      assert Services.status("simple-math") == :undefined
    end

    test "error, when not defined" do
      conn =
        :post
        |> conn("/services/delete/undefined")
        |> Router.call(%{})

      assert conn.resp_body == "{\"error\":\":undefined\"}"
    end
  end
end
