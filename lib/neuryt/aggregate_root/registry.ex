defmodule Neuryt.AggregateRoot.Registry do
  use GenServer

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def list_loaded_aggregates do
    GenServer.call(__MODULE__, :list_loaded_aggregates)
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

  def get_aggregate_root_pid(aggregate, agg_id) do
    Neuryt.AggregateRoot.Server.get_pid(aggregate, agg_id)
  end

  # Server callbacks
  def init(:ok) do
    {:ok, []}
  end

  def handle_call(:list_loaded_aggregates, _from, state) do
    list =
      :gproc.table({:l, :n}, [:check_pids])
      |> :qlc.eval
      |> Enum.map(fn {{:n, :l, aggregate}, _, _} -> aggregate end)

    {:reply, list, state}
  end

  def handle_call({:ensure_queue_is_present, aggregate, agg_id}, _from, state) do
    add_queue aggregate, agg_id
    {:reply, :ok, state}
  end

  def handle_call({:open, aggregate, agg_id, opts}, _from, state) do
    res = case get_aggregate_root_pid(aggregate, agg_id) do
            pid when is_pid pid ->
              Neuryt.AggregateRoot.Server.asked_for pid # prolong activity, in
              # case idle-timeout would occur right after returning AR's pid
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
    {:ok, events} = event_store.load_stream_events(agg_id)
    events
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
