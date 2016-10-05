defmodule Neuryt.AggregateRoot.Registry do
  use GenServer

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def loaded_aggregates_count do
    GenServer.call(__MODULE__, :loaded_aggregates_count)
  end

  def load(aggregate, opts \\ []) do
    GenServer.call(__MODULE__, {:load, aggregate, opts})
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

  def handle_call({:load, aggregate, opts}, _from, state) do
    res = case Process.whereis aggregate do
            pid when is_pid pid ->
              {:ok, pid}
            _ ->
              :jobs.add_queue queue_name(aggregate), standard_counter: 1
              Supervisor.start_child Neuryt.AggregateRoot.ServerSupervisor,
                [aggregate, opts]
          end
    GenServer.cast aggregate, :asked_for

    {:reply, res, state}
  end

  defp queue_name(aggregate) do
    {:ar_queue, aggregate}
  end
end
