defmodule Neuryt.ProcessManagerStarterSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      supervisor(Task.Supervisor, [[name: Neuryt.ProcessManagerStarter.SenderSupervisor]]),
    ]
    supervise(children, strategy: :one_for_one)
  end
end
