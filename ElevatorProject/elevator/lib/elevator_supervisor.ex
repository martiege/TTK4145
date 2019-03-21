defmodule ElevatorSupervisor do
  use Supervisor

  def start_link(node_number) do
    driver_port = 20000 + node_number * 1000
    node_name = "n" <> to_string(node_number)
    ElevatorSupervisor.start_link(driver_port, node_name, 0, 3) # standard
  end

  def start_link(driver_port, node_name, bottom_floor, top_floor) do
    Supervisor.start_link(__MODULE__, {driver_port, node_name, bottom_floor, top_floor}, name: __MODULE__)
  end

  def init({driver_port, node_name, bottom_floor, top_floor}) do
    children = [
      %{
        id: Driver,
        start: {Driver, :start_link, [ElevatorFinder.get_ip_tuple(), driver_port]}, 
        restart: :permanent,
        shutdown: 5000,
        type: :worker
      },
      %{
        id: ElevatorFinder,
        start: {ElevatorFinder, :start_link, [node_name]},
        restart: :permanent,
        shutdown: 5000,
        type: :worker
      },
      %{
        id: SimpleElevator,
        start: {SimpleElevator, :start_link, [bottom_floor, top_floor]},
        restart: :permanent,
        shutdown: 5000,
        type: :worker
      },
      %{
        id: Events,
        start: {Events, :start_link, [bottom_floor, top_floor]},
        restart: :permanent,
        shutdown: :infinity,
        type: :supervisor
      },

      # {Driver, [ElevatorFinder.get_ip_tuple(), driver_port]}, #ElevatorFinder.get_ip_tuple()
      # {ElevatorFinder, [node_name]},
      # {SimpleElevator, [0, 3]},
      # {Events, [0, 3]},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
