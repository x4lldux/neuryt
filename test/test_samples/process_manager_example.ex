defmodule ProcessManagerExample do
  @behaviour Neuryt.ProcessManager
  use GenServer
  alias Neuryt.{Event, EventBus}
  require SomeEvents

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def wake_up?(%Event{event: SomeEvents.c(Event2, _agg_id, _pid)}), do: true
  def wake_up?(_), do: false

  # Server callbacks
  def init(:ok) do
    EventBus.subscribe_to_all_events

    {:ok, nil}
  end

  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info(%Event{event: SomeEvents.c(Event2, _agg_id, pid)}, state) do
    send pid, :event_recieved
    {:noreply, state}
  end

  def handle_info(%Event{event: SomeEvents.c(Stop, _agg_id)}, state) do
    {:stop, :normal, state}
  end
end
