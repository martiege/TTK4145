defmodule ElevatorSupervisor do
  use Supervisor

  def start_link(node_number) do
    driver_port = 20000 + node_number * 1000
    node_name = "n" <> to_string(node_number)
    ElevatorSupervisor.start_link(driver_port, node_name)
  end

  def start_link(driver_port, node_name) do
    Supervisor.start_link(__MODULE__, {driver_port, node_name}, name: __MODULE__)
  end

  def init({driver_port, node_name}) do
    children = [
      {Driver, [ElevatorFinder.get_ip_tuple(), driver_port]}, #ElevatorFinder.get_ip_tuple()
      {ElevatorFinder, [node_name]},
      {SimpleElevator, []},
      {Events, [0, 3]},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
