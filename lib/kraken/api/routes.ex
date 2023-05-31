defmodule Kraken.Api.Routes do
  alias Kraken.Routes

  def define(payload) do
    with {:ok, definition} <- Jason.decode(payload),
         {:ok, pipeline_name} <- Routes.define(definition) do
      {:ok, Jason.encode!(%{"ok" => pipeline_name})}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def all() do
    case Routes.all() do
      {:ok, routes} ->
        {:ok, Jason.encode!(routes)}

      {:error, :no_routes} ->
        {:error, Jason.encode!(%{"error" => "Routes are not defined!"})}
    end
  end
end
