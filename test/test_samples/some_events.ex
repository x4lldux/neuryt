defmodule SomeEvents do
  use DiscUnion

  @type agg_id :: Neuryt.UUID.t
  defunion Event1 in agg_id | Event2 in agg_id * any | Stop in agg_id
end
