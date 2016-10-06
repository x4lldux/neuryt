defmodule Neuryt.AggregateRoot.Registry do
  use GenServer

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def loaded_aggregates_count do
    GenServer.call(__MODULE__, :loaded_aggregates_count)
  end

  def load(aggregate, agg_id, opts \\ []) do
    GenServer.call(__MODULE__, {:load, aggregate, agg_id, opts})
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

  def handle_call({:load, aggregate, agg_id, opts}, _from, state) do
    res = case Process.whereis aggregate do
            pid when is_pid pid ->
              GenServer.cast pid, :asked_for
              {:ok, pid}
            _ ->
              add_queue aggregate
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

  defp add_queue(aggregate) do
    queue_name = queue_name(aggregate)
    case :jobs.queue_info queue_name do
      :undefined ->
        :jobs.add_queue queue_name, standard_counter: 1
      {:queue, _} ->
        :ok
    end
  end

  defp queue_name(aggregate) do
    {:ar_queue, aggregate}
  end
end
