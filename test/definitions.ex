defmodule Kraken.Test.Definitions do
  def read_and_decode(file) do
    path = Path.expand("../definitions", __ENV__.file)

    "#{path}/#{file}"
    |> File.read!()
    |> Jason.decode!()
  end
end
