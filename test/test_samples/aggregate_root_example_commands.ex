defmodule AggregateRootExample.Commands do
  use DiscUnion

  @type item :: any
  @type agg_id :: any
  defunion AddItem in agg_id * item
  | RemoveItem in agg_id * item
  | ClearItems in agg_id
end
