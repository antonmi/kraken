defmodule Kraken.Api.Requests.RoutesTest do
  use ExUnit.Case
  use Plug.Test

  alias Kraken.Api.Router

  @routes %{
    "typeA" => "pipelineA",
    "typeB" => "pipelineB"
  }

  describe "define" do
    test "success" do
      conn =
        :post
        |> conn("/routes/define", Jason.encode!(@routes))
        |> Router.call(%{})

      assert conn.resp_body == "{\"ok\":\"Elixir.Kraken.RoutingTable\"}"
    end

    test "error" do
      conn =
        :post
        |> conn("/routes/define", "wrong payload")
        |> Router.call(%{})

      assert String.contains?(conn.resp_body, "Jason.DecodeError")
    end
  end

  describe "routes" do
    test "success" do
      Kraken.Routes.define(@routes)

      conn =
        :get
        |> conn("/routes")
        |> Router.call(%{})

      assert Jason.decode!(conn.resp_body) == @routes
    end

    test "when routes undefined" do
      Kraken.Routes.delete()

      conn =
        :get
        |> conn("/routes")
        |> Router.call(%{})

      assert String.contains?(conn.resp_body, "{\"error\":\"Routes are not defined!\"}")
    end
  end
end
