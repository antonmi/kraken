ExUnit.start()

path = Path.expand("..", __ENV__.file)
Code.compile_file("definitions.ex", path)

path = Path.expand("..", __ENV__.file)
Code.compile_file("helpers.ex", path)

defmodule Kraken.TestHelpers do
  alias Kraken.Test.Definitions

  def define_and_start_service(name) do
    {:ok, ^name} =
      "services/#{name}.json"
      |> Definitions.read_and_decode()
      |> Octopus.define()

    {:ok, _code} = Octopus.start(name)
  end
end
