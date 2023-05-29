defmodule Kraken.Api.Router do
  use Plug.Router

  alias Kraken.Api.{Pipelines, Services}
  alias Kraken.Utils

  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "Hey! I'm Kraken!")
  end

  get "/favicon.ico" do
    send_resp(conn, 200, "sorry, no icon")
  end

  # services

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

  get "/services/status/:name" do
    {:ok, response} = Services.status(conn.params["name"])
    send_resp(conn, 200, response)
  end

  get "/services/definition/:name" do
    case Services.definition(conn.params["name"]) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  get "/services/state/:name" do
    case Services.state(conn.params["name"]) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  # pipelines

  post "/pipelines/define" do
    {:ok, body, conn} = read_body(conn)

    case Pipelines.define(body) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  get "/pipelines/status/:name" do
    {:ok, response} = Pipelines.status(conn.params["name"])
    send_resp(conn, 200, response)
  end

  get "/pipelines/definition/:name" do
    case Pipelines.definition(conn.params["name"]) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/pipelines/start/:name" do
    {:ok, body, conn} = read_body(conn)
    conn = fetch_query_params(conn)

    case Pipelines.start(conn.params, body) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/pipelines/stop/:name" do
    case Pipelines.stop(conn.params["name"]) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/pipelines/delete/:name" do
    case Pipelines.delete(conn.params["name"]) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/pipelines/call/:name" do
    {:ok, body, conn} = read_body(conn)
    conn = fetch_query_params(conn)

    case Pipelines.call(conn.params, body) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/pipelines/cast/:name" do
    {:ok, body, conn} = read_body(conn)
    conn = fetch_query_params(conn)

    case Pipelines.cast(conn.params, body) do
      {:ok, response} ->
        send_resp(conn, 200, response)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  post "/pipelines/stream/:name" do
    {:ok, body, conn} = read_body(conn)
    conn = fetch_query_params(conn)

    case Pipelines.stream(conn.params, body) do
      {:ok, stream} ->
        conn = send_chunked(conn, 200)

        Enum.reduce_while(stream, conn, fn event, conn ->
          chunk =
            event
            |> Utils.struct_to_map()
            |> Jason.encode!()

          case Plug.Conn.chunk(conn, chunk) do
            {:ok, conn} ->
              {:cont, conn}

            {:error, :closed} ->
              {:halt, conn}
          end
        end)

      {:error, response} ->
        send_resp(conn, 400, response)
    end
  end

  match _ do
    send_resp(conn, 404, "NOT FOUND")
  end
end
