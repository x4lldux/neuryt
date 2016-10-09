defmodule Neuryt.Command.Dispatcher do

  alias Neuryt.Command
  alias Neuryt.AggregateRoot

  # @spec dispatch(struct) :: :ok
  def dispatch(command, aggregate_module, service_data \\ nil) do
    agg_id = get_stream_id(command)
    {:ok, ref, ar_pid} = AggregateRoot.Registry.open(aggregate_module, agg_id)
    enveloped_command = Command.new(command, service_data: service_data)

    case AggregateRoot.Server.handle_command(ar_pid, enveloped_command) do
      {:ok, events} ->
        enveloped_events = envelope_events events, enveloped_command

        # process linked as a protection of AR state, in case saving succeed  but
        # client died before events where applied to AR state. this way, when client
        # dies, AR will die too and next time it will be reloaded with those events
        # applied.
        Process.link ar_pid
        save_events enveloped_events
        AggregateRoot.Server.apply_events ar_pid, enveloped_events
        Process.unlink ar_pid
        AggregateRoot.Registry.release ref

        # FIX: unfortunately, there is no mechanism for publishing events in
        # such a case!
        enveloped_events
        |> Enum.each(&Neuryt.EventBus.publish/1)

      {:error, reason} -> {:error, reason}
    end
  end

  defp envelope_events(events, command),
    do: Enum.map(events, &envelope_event(&1, command))
  defp envelope_event(%Neuryt.Event{} = event, _command), do: event
  defp envelope_event(event, command), do: Neuryt.Event.new event, command

  defp save_events(events) do
    event_store = Application.get_env :neuryt, :event_store

    events
    |> Enum.group_by(fn e -> get_stream_id e.event end)
    |> Enum.map(fn {stream_id, events} ->
      event_store.save_events(events, stream_id)
    end)
  end

  defp get_stream_id(%{case: thing}) when is_tuple(thing) do
    # get the first argument from the command, by convention, this should
    # always be aggregate id
    elem thing, 1
  end
end
