defmodule AggregateRootExample.Events do
  use DiscUnion

  @type item :: any
  @type agg_id :: any
  defunion ItemAdded in agg_id * item
  | ItemRemoved in agg_id * item
  | ItemsCleared in agg_id
end
