defmodule Kraken.Api.Router do
  use Plug.Router

  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "Hey! I'm Kraken!")
  end

  get "/favicon.ico" do
    send_resp(conn, 200, "sorry, no icon")
  end
#
#  post "/define" do
#    {:ok, body, conn} = read_body(conn)
#
#    case OctopusAgent.define(body) do
#      {:ok, response} ->
#        send_resp(conn, 200, response)
#
#      {:error, response} ->
#        send_resp(conn, 400, response)
#    end
#  end
#
#  post "/start/:name" do
#    {:ok, body, conn} = read_body(conn)
#
#    case OctopusAgent.start(conn.params["name"], body) do
#      {:ok, response} ->
#        send_resp(conn, 200, response)
#
#      {:error, response} ->
#        send_resp(conn, 400, response)
#    end
#  end
#
#  post "call/:name/:function" do
#    {:ok, body, conn} = read_body(conn)
#
#    case OctopusAgent.call(conn.params["name"], conn.params["function"], body) do
#      {:ok, response} ->
#        send_resp(conn, 200, response)
#
#      {:error, response} ->
#        send_resp(conn, 400, response)
#    end
#  end
#
#  post "stop/:name" do
#    {:ok, body, conn} = read_body(conn)
#
#    case OctopusAgent.stop(conn.params["name"], body) do
#      {:ok, response} ->
#        send_resp(conn, 200, response)
#
#      {:error, response} ->
#        send_resp(conn, 400, response)
#    end
#  end
#
#  post "restart/:name" do
#    {:ok, body, conn} = read_body(conn)
#
#    case OctopusAgent.restart(conn.params["name"], body) do
#      {:ok, response} ->
#        send_resp(conn, 200, response)
#
#      {:error, response} ->
#        send_resp(conn, 400, response)
#    end
#  end
#
#  post "delete/:name" do
#    case OctopusAgent.delete(conn.params["name"]) do
#      {:ok, response} ->
#        send_resp(conn, 200, response)
#
#      {:error, response} ->
#        send_resp(conn, 400, response)
#    end
#  end
#
#  post "/status/:name" do
#    {:ok, response} = OctopusAgent.status(conn.params["name"])
#    send_resp(conn, 200, response)
#  end
#
#  get "/status/:name" do
#    {:ok, response} = OctopusAgent.status(conn.params["name"])
#    send_resp(conn, 200, response)
#  end
#
#  match _ do
#    send_resp(conn, 404, "NOT FOUND")
#  end
end
