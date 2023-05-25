defmodule Kraken.Api.Router do
  use Plug.Router

  alias Kraken.Api.Services

  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "Hey! I'm Kraken!")
  end

  get "/favicon.ico" do
    send_resp(conn, 200, "sorry, no icon")
  end

  post "/services/define" do
    {:ok, body, conn} = read_body(conn)

    case Services.define(body) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/services/start/:name" do
    {:ok, body, conn} = read_body(conn)

    case Services.start(conn.params["name"], body) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/services/call/:name/:function" do
    {:ok, body, conn} = read_body(conn)

    case Services.call(conn.params["name"], conn.params["function"], body) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/services/stop/:name" do
    {:ok, body, conn} = read_body(conn)

    case Services.stop(conn.params["name"], body) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end


  post "/services/delete/:name" do
    case Services.delete(conn.params["name"]) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/services/status/:name" do
    {:ok, response} = Services.status(conn.params["name"])
    send_resp(conn, 200, response)
  end

  get "/services/status/:name" do
    {:ok, response} = Services.status(conn.params["name"])
    send_resp(conn, 200, response)
  end

  match _ do
    send_resp(conn, 404, "NOT FOUND")
  end
end
