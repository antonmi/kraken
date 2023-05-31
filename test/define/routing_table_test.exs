defmodule Kraken.Define.RoutingTableTest do
  use ExUnit.Case
  alias Kraken.Define.RoutingTable

  @routes %{
    "typeA" => "pipelineA",
    "typeB" => "pipelineB"
  }

  describe "define/1" do
    setup do
      RoutingTable.define(@routes)
      :ok
    end

    test "table" do
      assert apply(Kraken.RoutingTable, :routes, []) == @routes
      assert apply(Kraken.RoutingTable, :route, ["typeA"]) == "pipelineA"
      assert apply(Kraken.RoutingTable, :route, ["typeB"]) == "pipelineB"
    end
  end
end
