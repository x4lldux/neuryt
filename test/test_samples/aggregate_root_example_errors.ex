defmodule AggregateRootExample.Errors do
  use DiscUnion

  defunion ItemAllreadyPresent | NoSuchItem
end
