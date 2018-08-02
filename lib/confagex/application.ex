defmodule Confagex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    import Supervisor.Spec

    args = [
      Application.get_env(:confagex, :host) || {127, 0, 0, 1},
      Application.get_env(:confagex, :port) || 6666,
      []
    ]

    children = [
      # Starts a worker by calling: Confagex.Worker.start_link(arg)
      worker(Confagex.TCPClient, args)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Confagex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
