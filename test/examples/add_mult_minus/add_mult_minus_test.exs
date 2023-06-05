defmodule AddMultMinusTest do
  use ExUnit.Case
  use Plug.Test
  alias Kraken.Api.Router
  alias Kraken.{Pipelines, Routes}

  @path Path.expand("../..", __ENV__.file) <> "/add_mult_minus"

  setup do
    on_exit(fn ->
      Octopus.delete("add-mult-minus")
      Pipelines.delete("add-mult-minus-pipeline")
      Routes.delete()
    end)
  end

  def define_and_start_service() do
    service_json = File.read!("#{@path}/service.json")

    conn =
      :post
      |> conn("/services/define", service_json)
      |> Router.call(%{})

    assert conn.resp_body == "{\"ok\":\"add-mult-minus\"}"

    conn =
      :post
      |> conn("/services/start/add-mult-minus")
      |> Router.call(%{})

    assert conn.resp_body =~ "{\"ok\""
  end

  def define_and_start_pipeline() do
    pipeline_json = File.read!("#{@path}/pipeline.json")

    conn =
      :post
      |> conn("/pipelines/define", pipeline_json)
      |> Router.call(%{})

    assert conn.resp_body == "{\"ok\":\"add-mult-minus-pipeline\"}"

    conn =
      :post
      |> conn("/pipelines/start/add-mult-minus-pipeline")
      |> Router.call(%{})

    assert conn.resp_body =~ "{\"ok\""
  end

  test "define service and pipeline, start and call" do
    define_and_start_service()
    define_and_start_pipeline()

    event = Jason.encode!(%{event: 2})

    conn =
      :post
      |> conn("/pipelines/call/add-mult-minus-pipeline", event)
      |> Router.call(%{})

    assert conn.resp_body == "{\"event\":3}"
  end

  test "define and call via routes" do
    define_and_start_service()
    define_and_start_pipeline()

    routes = Jason.encode!(%{"add-mult-minus" => "add-mult-minus-pipeline"})

    conn =
      :post
      |> conn("/routes/define", routes)
      |> Router.call(%{})

    assert conn.resp_body =~ "{\"ok\""

    event = Jason.encode!(%{type: "add-mult-minus", event: 2})

    conn =
      :post
      |> conn("/call", event)
      |> Router.call(%{})

    assert conn.resp_body == "{\"event\":3,\"type\":\"add-mult-minus\"}"
  end
end
