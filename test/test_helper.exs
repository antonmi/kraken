ExUnit.start()

path = Path.expand("..", __ENV__.file)
Code.compile_file("definitions.ex", path)

path = Path.expand("..", __ENV__.file)
Code.compile_file("helpers.ex", path)
