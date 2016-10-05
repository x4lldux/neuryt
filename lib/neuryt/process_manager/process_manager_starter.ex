defmodule Neuryt.ProcessManager.Starter do
  @moduledoc """
  Starts a process manger when an wake up event arrives and then sends that
  event to the newly started process. Upper limit for each worker module can be
  set to gaurd from overfloading the system - events will be queued until a new
  process manager can be started.
  """

  use GenServer
  @valid_options [:max_count, :jobs_opts]
  @type option :: {:max_count, integer} | {:jobs_opts, jobs_opts}
  @type options :: [option]
  @type jobs_opts :: [{atom, any}]

  # Client API
  @doc """
  Starts a process manager starter.
  Accepts a single module name or a list of module names, of process managers to
  govern and options.
  """
  @spec start_link(atom, options) :: GenServer.on_start
  def start_link(module, opts \\ [max_count: 10])
  def start_link(module, opts) when is_atom module do
    start_link [module], opts
  end
  def start_link(modules, opts) when is_list(modules) do
    {queue_opts, gen_server_opts} = Keyword.split(opts, @valid_options)
    queue_opts = jobs_queue_options queue_opts

    GenServer.start_link(__MODULE__, {modules, queue_opts}, gen_server_opts)
  end

  @doc """
  Returns stats for defined process managers.
  """
  @spec stats(pid) :: %{required(atom) => %{running: integer, queued: integer, type: integer, regulators: integer}}
  def stats(pid) do
    GenServer.call(pid, :stats)
  end

  # Server callbacks
  def init({modules, opts}) do
    Neuryt.EventBus.subscribe_to_all_events

    modules
    |> Enum.each(&start_queue(&1, opts))

    {:ok, %{modules: modules}}
  end

  def handle_call(:stats, _from, %{modules: modules} = state) do
    stats =
      modules
      |> Enum.map(fn m -> {m, m |> queue_name |> queue_stats} end)
      |> Enum.into(%{})

    {:reply, stats, state}
  end

  def handle_info(%Neuryt.Event{} = event, %{modules: modules} = state) do
    handle_incoming_event(event, modules)

    {:noreply, state}
  end

  defp start_queue(name, opts) do
    queue_name = queue_name name

    :jobs.add_queue queue_name, opts
  end

  defp handle_incoming_event(event, modules) do
    modules
    |> Enum.filter(fn module -> module.wake_up? event end)
    |> Enum.each(&send_event(event, &1))
  end

  defp send_event(event, module) do
    Task.Supervisor.start_child(Neuryt.ProcessManager.SenderSupervisor,
      fn ->
        queue_name = queue_name module
        :jobs.run queue_name, fn ->
          {:ok, pm_worker} = start_worker module
          mref = Process.monitor pm_worker # monitor before sending, to detect
                                           # DOWNs caused by our message
          send pm_worker, event

          receive do
            {:DOWN, mref, :process, _, _} -> :ok # wait until worker dies
          end
        end
      end)
  end

  defp start_worker(module) do
    import Supervisor.Spec
    queue_name = queue_name(module)

    module.start_link
  end

  defp jobs_queue_options(opts) do
    queue_opts = cond do
      jobs_opts = Keyword.get(opts, :jobs_opts) ->
        jobs_opts
      true ->
        [standard_counter: Keyword.get(opts, :max_count)]
    end
  end

  defp queue_name(module) do
    {:pm_queue, module}
  end

  defp queue_stats(queue_name) do
    {:queue, stats} = :jobs.queue_info(queue_name)
    [running] =
      :jobs.info(:counters)
      |> Enum.filter(& match?({:cr, [{:name, {:counter, ^queue_name, _}} | _]}, &1))
      |> Enum.map(fn {:cr, x = [{:name, {:counter, ^queue_name, _}} | _]} ->
        Keyword.get(x, :value)
      end)

    %{
      running:    running,
      queued:     stats[:queued] + (stats[:check_counter] - stats[:approved]),
      type:       stats[:type],
      regulators: stats[:regulatros]
    }
  end
end
