defmodule Helpers.FetchHelper do
  def fetch(args, arg) do
    get_in(args, [arg])
  end
end

defmodule Helpers.GetHelper do
  def get(args, arg) do
    get_in(args, [arg])
  end
end
