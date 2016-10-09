defmodule CommandRouterExample do
  use Neuryt.Command.Router

  route AggregateRootExample.Commands, to: AggregateRootExample
end
