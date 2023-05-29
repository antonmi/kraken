defimpl Jason.Encoder, for: PID do
  def encode(value, opts) do
    inspect(value)
    |> String.replace("#PID<", "")
    |> String.replace(">", "")
    |> Jason.Encode.string(opts)
  end
end

defimpl Jason.Encoder, for: Reference do
  def encode(value, opts) do
    inspect(value)
    |> String.replace("#Reference<", "")
    |> String.replace(">", "")
    |> Jason.Encode.string(opts)
  end
end

defimpl Jason.Encoder, for: Tuple do
  def encode(value, opts) do
    value
    |> Tuple.to_list()
    |> Jason.Encode.list(opts)
  end
end
