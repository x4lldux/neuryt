defmodule AggregateRootExample.Events do
  use DiscUnion

  @type item :: any
  @type agg_id :: any
  @type delay :: non_neg_integer
  defunion ItemAdded in agg_id * item
  | ItemRemoved in agg_id * item
  | ItemsProcessed in agg_id * delay
  | ItemsCleared in agg_id
end
