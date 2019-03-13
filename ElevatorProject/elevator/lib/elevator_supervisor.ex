defmodule ElevatorSupervisor do
  use Supervisor

  def start_link(driver_port, node_name) do
    Supervisor.start_link(__MODULE__, {driver_port, node_name}, name: __MODULE__)
  end

  def init({driver_port, node_name}) do
    children = [
      {Driver, [{10, 24, 33, 248}, driver_port]}, #ElevatorFinder.get_ip_tuple()
      {ElevatorFinder, [node_name]},
      {SimpleElevator, []},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end