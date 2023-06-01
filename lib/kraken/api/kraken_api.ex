defmodule Kraken.Api.KrakenApi do
  alias Kraken.Utils

  def call(opts, payload) do
    with {:ok, event} <- Jason.decode(payload),
         result when is_map(result) or is_list(result) <-
           Kraken.call(event, opts) do
      {:ok, Jason.encode!(Utils.struct_to_map(result))}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def cast(opts, payload) do
    with {:ok, event} <- Jason.decode(payload),
         result when is_reference(result) or is_list(result) <-
           Kraken.cast(event, opts) do
      {:ok, Jason.encode!(%{"ok" => result})}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def stream(opts, payload) do
    with {:ok, event} <- Jason.decode(payload),
         stream when is_function(stream) <- Kraken.stream(event, opts) do
      {:ok, stream}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end
end
