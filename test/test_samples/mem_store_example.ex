defmodule MemStoreExample do
  @behaviour Neuryt.EventStore
  @agent __MODULE__

  def save_event(event, stream_id) do
    Agent.update @agent, fn store ->
      Map.update store, stream_id, [], fn stream -> [event | stream] end
    end
    :ok
  end

  def save_events(events, stream_id) do
    Agent.update @agent, fn store ->
      Map.update store, stream_id, events, fn stream -> events ++ stream end
    end
    :ok
  end

  def load_all_events() do
    events =
      Agent.get(@agent, fn store -> store |> Map.values |> List.flatten end)
    {:ok, events}
  end

  def count_all_events(),
    do: {:ok, load_all_events() |> elem(1) |> length}

  def load_stream_events(stream_id) do
    events =
      Agent.get(@agent, fn store -> store |> Map.get(stream_id, []) end)
    {:ok, events}
  end

  def count_stream_events(stream_id),
    do: {:ok, load_stream_events(stream_id) |> elem(1) |> length}

  def list_streams() do
    streams =
      Agent.get(@agent, fn store -> store |> Map.keys end)
    {:ok, streams}
  end

  def start_link() do
    Agent.start_link fn -> %{} end, name: __MODULE__
  end

  def reset() do
    Agent.update @agent, fn _ -> %{} end
  end
end
