defmodule Neuryt.AggregateRoot.Server do
  @moduledoc """
  Server responsible for loading and keep AR state in memory, and applying
  events to it's state.
  Most of the time it will not be needed at all.
  """
  use GenServer

  @default_opts [idle_timeout: 5000]

  # Client API
  def start_link(module, agg_id, events, opts \\ []) do
    opts = opts ++ @default_opts

    aggregate_server_name = {:via, :gproc, server_name(module, agg_id)}
    GenServer.start_link(__MODULE__, {module, agg_id, events, opts},
      name: aggregate_server_name)
  end

  def server_name(aggregate, agg_id) do
    {:n, :l, {aggregate, agg_id}}
  end

  def whereis(aggregate, agg_id) do
    :gproc.where server_name(aggregate, agg_id)
  end

  def get_aggregate_state(ar_pid) do
    GenServer.call ar_pid, :get_aggregate_state
  end

  def handle_command(ar_pid, command_handler, %Neuryt.Command{} = command) do
    GenServer.call ar_pid, {:handle_command, command_handler, command}
  end

  def apply_events(ar_pid, events) do
    GenServer.call(ar_pid, {:apply_events, events})
  end

  def asked_for(ar_pid) do
    GenServer.cast ar_pid, :asked_for
  end

  # Server callbacks
  def init({module, agg_id, events, opts}) do
    idle_timeout = Keyword.get opts, :idle_timeout
    ar_state = module.load(agg_id, events)
    state = %{
      module: module,
      agg_id: agg_id,
      idle_timeout: idle_timeout,
      ar_state: ar_state,
    }

    {:ok, state, state.idle_timeout}
  end

  def handle_call({:handle_command, command_handler, command}, _from, state) do
    module = command_handler
    res = module.handle(command, state.ar_state)

    {:reply, res, state, state.idle_timeout}
  end

  def handle_call({:apply_events, events}, _from, state) do
    module = state.module
    ar_state = module.update(state.ar_state, events)
    state = %{state | ar_state: ar_state}

    {:reply, :ok, state, state.idle_timeout}
  end

  def handle_call(:get_aggregate_state, _from, state) do
    {:reply, state.ar_state, state, state.idle_timeout}
  end

  def handle_cast(:asked_for, state) do # just as a safety mechanism for
                                        # situations when a slow client asks
                                        # before timeout on idle
    {:noreply, state, state.idle_timeout}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end
end
