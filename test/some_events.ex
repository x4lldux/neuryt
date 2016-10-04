defmodule SomeEvents do
  use DiscUnion

  defunion Event1 | Event2 in any | Stop
end
