defmodule CommandRouterExample do
  use Neuryt.Command.Router

  # if `:for_ar` is omitted, it's value will be the same as for `:to`
  # route AggregateRootExample.Commands, to: AggregateRootExample,
  #   ar_idle_timeout: 1000
  route AggregateRootExample.Commands, to: AggregateRootExample,
    for_ar: AggregateRootExample, ar_idle_timeout: 1000
end
