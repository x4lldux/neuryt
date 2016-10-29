defmodule Neuryt do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Task.Supervisor, [[name: Neuryt.ProcessManager.SenderSupervisor]]),
      supervisor(Neuryt.AggregateRoot.Supervisor, []),

      # worker(Neuryt.ProcessManagerStarter, [SampleProcessManager, max_count: 10], id: :sample_pm),
    ]

    opts = [strategy: :one_for_one, name: Neuryt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
