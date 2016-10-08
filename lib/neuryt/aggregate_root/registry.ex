defmodule Neuryt.AggregateRoot.Registry do
  use GenServer

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def loaded_aggregates_count do
    GenServer.call(__MODULE__, :loaded_aggregates_count)
  end

  def open(aggregate, agg_id, opts \\ []) do
    :ok = GenServer.call(__MODULE__, {:ensure_queue_is_present, aggregate, agg_id})

    {:ok, ref} = :jobs.ask queue_name(aggregate, agg_id)
    with {:ok, pid} <- GenServer.call(__MODULE__, {:open, aggregate, agg_id, opts}),
      do: {:ok, ref, pid}
  end

  def release(ref) do
    try do
      :jobs.done(ref)
    catch
      _, _ -> :ok
    end
    :ok
  end

  # Server callbacks
  def init(:ok) do
    {:ok, []}
  end

  def handle_call(:loaded_aggregates_count, _from, state) do
    count =
      Supervisor.which_children(Neuryt.AggregateRoot.ServerSupervisor)
      |> length
    {:reply, count, state}
  end

  def handle_call({:ensure_queue_is_present, aggregate, agg_id}, _from, state) do
    add_queue aggregate, agg_id
    {:reply, :ok, state}
  end

  def handle_call({:open, aggregate, agg_id, opts}, _from, state) do
    res = case Neuryt.AggregateRoot.Server.get_pid(aggregate, agg_id) do
            pid when is_pid pid ->
              GenServer.cast pid, :asked_for
              {:ok, pid}
            _ ->
              add_queue aggregate, agg_id
              all_events = load_all_events agg_id
              Supervisor.start_child Neuryt.AggregateRoot.ServerSupervisor,
                [aggregate, agg_id, all_events, opts]
          end

    {:reply, res, state}
  end

  defp load_all_events(agg_id) do
    event_store = Application.get_env :neuryt, :event_store
    event_store.load_stream_events(agg_id)
  end

  defp add_queue(aggregate, agg_id) do
    queue_name = queue_name(aggregate, agg_id)
    case :jobs.queue_info queue_name do
      :undefined ->
        :jobs.add_queue queue_name, standard_counter: 1
      {:queue, _} ->
        :ok
    end
  end

  defp queue_name(aggregate, agg_id) do
    {:ar_queue, aggregate, agg_id}
  end
end
