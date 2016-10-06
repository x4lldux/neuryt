defmodule Neuryt.AggregateRoot.Server do
  use GenServer

  @default_opts [idle_timeout: 5000]

  # Client API
  def start_link(module, agg_id, events, opts \\ []) do
    opts = opts ++ @default_opts

    GenServer.start_link(__MODULE__, {module, agg_id, events, opts}, name: module)
  end

  # Server callbacks
  def init({module, agg_id, events, opts}) do
    idle_timeout = Keyword.get opts, :idle_timeout
    ar_state = module.load(agg_id, events)
    state = %{
      idle_timeout: idle_timeout,
      ar_state: ar_state,
    }

    {:ok, state, state.idle_timeout}
  end

  def handle_call(:get_aggregate_state, _from, state) do
    {:reply, state.ar_state, state.idle_timeout}
  end

  def handle_cast(:asked_for, state) do # just as a safety mechanism for
                                        # situation when a slow client asks
                                        # before timeout on idle
    {:noreply, state, state.idle_timeout}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

end
