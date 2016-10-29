defmodule Neuryt.Command.Dispatcher do
  @moduledoc false

  alias Neuryt.Command
  alias Neuryt.AggregateRoot

  @type opt :: {:service_data, any} | {:reaction_to, atom} |
  {:ar_idle_timeout, pos_integer}
  @type opts :: [opt]

  @spec dispatch(%{}, atom, atom, opts) :: :ok
  def dispatch(command, command_handler, aggregate_module, opts) do
    service_data = Keyword.get opts, :service_data, nil
    reaction_to_event = Keyword.get opts, :reaction_to, nil
    ar_opts = case Keyword.get opts, :ar_idle_timeout, nil do
                nil -> []
                ar_idle_timeout -> [idle_timeout: ar_idle_timeout]
              end

    agg_id = get_stream_id(command)
    {:ok, ref, ar_pid} = AggregateRoot.Registry.open(aggregate_module, agg_id,
      ar_opts)
    enveloped_command = envelope_command(command, reaction_to_event, service_data)
    res =
      case AggregateRoot.Server.handle_command(ar_pid, command_handler,
            enveloped_command) do
        {:ok, events} ->
          enveloped_events = envelope_events events, enveloped_command

          # process linked as a protection of AR state, in case saving succeed
          # but client died before events where applied to AR state. This way,
          # when client dies, AR will die too and next time it will be reloaded
          # with those events applied.
          Process.link ar_pid
          save_events enveloped_events
          AggregateRoot.Server.apply_events ar_pid, enveloped_events
          Process.unlink ar_pid

          # HACK: unfortunately, there is no mechanism for publishing events in
          # such a case!
          # so for this case a new UNLINKED process is just spawned
          spawn fn -> Enum.each(enveloped_events, &Neuryt.EventBus.publish/1) end

          :ok

        {:error, reason} -> {:error, reason}
      end

    AggregateRoot.Registry.release ref

    res
  end

  defp envelope_command(command, nil, service_data),
    do: Command.new(command, service_data: service_data)
  defp envelope_command(command, reaction_to_event, service_data),
    do: Command.new(command, reaction_to_event, service_data: service_data)

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
