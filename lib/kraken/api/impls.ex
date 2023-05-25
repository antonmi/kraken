defimpl Jason.Encoder, for: PID do
  def encode(value, opts) do
    inspect(value)
    |> String.replace("#PID<", "")
    |> String.replace(">", "")
    |> Jason.Encode.string(opts)
  end
end
