defmodule AggregateRootExample.Commands do
  use DiscUnion

  @type item :: any
  @type agg_id :: any
  @type delay :: non_neg_integer
  defunion AddItem in agg_id * item
  | RemoveItem in agg_id * item
  | ProcessItems in agg_id * delay
  | ClearItems in agg_id
end
