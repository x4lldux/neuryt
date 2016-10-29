defmodule Neuryt.AggregateRoot.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(Neuryt.AggregateRoot.Registry, []),
      supervisor(Neuryt.AggregateRoot.ServerSupervisor, []),
    ]
    supervise(children, strategy: :one_for_all)
  end
end
