defmodule ProcessManagerTest do
  use ExUnit.Case
  require SomeEvents

  alias Neuryt.ProcessManager
  alias Neuryt.{Event, EventBus}

  setup do
    {:ok, pid} = ProcessManager.Starter.start_link ProcessManagerExample, max_count: 2

    on_exit fn ->
      kill_sender_tasks
      :jobs.delete_queue {:pm_queue, ProcessManagerExample}
    end

    %{pm_pid: pid}
  end

  test "wake_up? function returns boolean" do
    assert ProcessManagerExample.wake_up?(%Event{event: SomeEvents.c(Event1, 123)}) == false
    assert ProcessManagerExample.wake_up?(%Event{event: SomeEvents.c(Event2, 123, self)}) == true
  end


  test "starter listens to all events", %{pm_pid: pid} do
    assert [pid] == EventBus.list_subscribers_to_all_events
  end

  test "starter starts new PM when wake up event is published", %{pm_pid: pid}  do
    EventBus.publish %Event{event: SomeEvents.c(Event2, 123, self)}
    assert_receive :event_recieved, 1000
    assert %{ProcessManagerExample => %{running: 1}} = ProcessManager.Starter.stats(pid)

    EventBus.publish %Event{event: SomeEvents.c(Stop, 123)}
  end

  test "starter allows only limited number of workers of each PM", %{pm_pid: pid} do
    EventBus.publish %Event{event: SomeEvents.c(Event2, 123, self)}
    assert_receive :event_recieved, 1000
    assert %{ProcessManagerExample => %{running: 1, queued: 0}} = ProcessManager.Starter.stats(pid)

    EventBus.publish %Event{event: SomeEvents.c(Event2, 123, self)}
    assert_receive :event_recieved, 1000
    assert %{ProcessManagerExample => %{running: 2, queued: 0}} = ProcessManager.Starter.stats(pid)

    EventBus.publish %Event{event: SomeEvents.c(Event2, 123, self)}
    Process.sleep 100
    assert %{ProcessManagerExample => %{running: 2, queued: 1}} = ProcessManager.Starter.stats(pid)
  end

  defp kill_sender_tasks do
    Supervisor.which_children(Neuryt.ProcessManager.SenderSupervisor)
    |> Enum.map(fn {_, pid, _, _} ->
      Process.monitor pid
      Process.exit pid, :kill
    end)
    |> Enum.each(fn _ ->
      receive do
        {:DOWN, _, _, _, _} -> :ok
      after
        500 -> :ok
      end end)
  end
end
