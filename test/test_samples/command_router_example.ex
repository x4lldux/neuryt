defmodule CommandRouterExample do
  use Neuryt.Command.Router

  route AggregateRootExample.Commands, to: AggregateRootExample, ar_idle_timeout: 1000
end
