defmodule ElevatorSupervisor do
  @moduledoc """
  The ElevatorSupervisor module supervises
	the other main modules of this system: 
	  Driver, the elevator driver
	  ElevatorFinder, for finding other nodes
	  ElevatorState, for keeping and modifying 
		the state
	  Events, for supervising the button and 
		floor events
	  RequestManager, for fulfilling the 
		requests. 

  The module will start and maintain the 
	modules mentioned above, and restart 
	those that are needed, if anything 
	should happen. 
	
  The module is started depening on several
	factors: 
	If using this to test with simulators
		iex> ElevatorSupervisor.start_link(node_number)
	
	If using on the elevator hardware
		iex> ElevatorSupervisor.start_link(node_name)
		
	If specifying configurations: 
		iex> ElevatorSupervisor.start_link(driver_port, 
		 ...  node_name, bottom_floor, top_floor)
  
  """
  use Supervisor

  def start_link(node_number) when is_integer(node_number) do
    driver_port = 20000 + node_number * 1000
    node_name = "n" <> to_string(node_number)
    ElevatorSupervisor.start_link(driver_port, node_name, 0, 3) # standard
  end

  def start_link(node_name) do
    Supervisor.start_link(__MODULE__, {15657, node_name, 0, 3})
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
        id: ElevatorState,
        start: {ElevatorState, :start_link, [bottom_floor, top_floor]},
        restart: :permanent,
        shutdown: 5000,
        type: :worker
      },
      %{
        id: RequestManager,
        start: {RequestManager, :start_link, [{}]},
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
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
