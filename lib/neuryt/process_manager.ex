defmodule Neuryt.ProcessManager do
  @moduledoc """
  Modules implementing `ProcessManager` behaviour, must:

  * implement a `wake_up?/1` function which will return `true` or `false` if new
  process manager should be spawned to work on this event,
  * implement `start_link/1` function which will be called when spawning new PM,
  * and die after it's work is done.
  """

  @callback start_link() :: {:ok, pid}
  @callback wake_up?(%Neuryt.Event{event: any}) :: boolean
end
