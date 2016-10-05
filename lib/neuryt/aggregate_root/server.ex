defmodule Neuryt.AggregateRoot.Server do
  use GenServer

  @default_opts [idle_timeout: 5000]

  # Client API
  def start_link(module, opts \\ []) do
    opts = opts ++ @default_opts

    GenServer.start_link(__MODULE__, {module, opts}, name: module)
  end

  # Server callbacks
  def init({module, opts}) do
    idle_timeout = Keyword.get opts, :idle_timeout
    state = %{
      idle_timeout: idle_timeout
    }

    {:ok, state, state.idle_timeout}
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
