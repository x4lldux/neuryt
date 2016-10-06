defmodule AggregateRootExample.Events do
  use DiscUnion

  @type item :: any
  defunion ItemAdded in item | ItemRemoved in item | ItemsCleared
end
