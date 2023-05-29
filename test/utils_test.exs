defmodule Kraken.UtilsTest do
  use ExUnit.Case
  alias Kraken.Utils

  describe "struct_to_map" do
    test "simple case" do
      assert %{decomposed: false} = Utils.struct_to_map(%ALF.IP{})
    end

    test "for list" do
      assert [%{decomposed: false}, %{}] = Utils.struct_to_map([%ALF.IP{}, %ALF.IP{}])
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
                 event: [%{decomposed: false}, %{}]
               },
               history: [%{decomposed: false}, %{}]
             } = Utils.struct_to_map(struct)
    end
  end
end
