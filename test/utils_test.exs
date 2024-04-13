defmodule Kraken.UtilsTest do
  use ExUnit.Case, async: true
  alias Kraken.Utils

  describe "struct_to_map" do
    test "simple case" do
      assert %{composed: false} = Utils.struct_to_map(%ALF.IP{})
    end

    test "for list" do
      assert [%{composed: false}, %{}] = Utils.struct_to_map([%ALF.IP{}, %ALF.IP{}])
    end

    test "nested case" do
      struct = %ALF.IP{
        event: %ALF.IP{
          event: [%ALF.IP{}, %ALF.IP{}]
        },
        history: [%ALF.IP{}, %ALF.IP{}]
      }

      assert %{
               event: %{
                 event: [%{composed: false}, %{}]
               },
               history: [%{composed: false}, %{}]
             } = Utils.struct_to_map(struct)
    end
  end
end
