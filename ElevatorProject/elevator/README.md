# Elevator Project TTK4145

## Libraries
During this project, we have utilized the Driver as given out by the [course](https://github.com/TTK4145/driver-elixir). Furthermore, the [GenServer](https://hexdocs.pm/elixir/GenServer.html) module, as provided by the Elixir standard library, is used. 

## Structure
This project is structured using a [Supervisor](https://hexdocs.pm/elixir/Supervisor.html), implemented in the submodule ElevatorSupervisor. This supervises the other modules, and handles any errors. 

The other modules, excluding the ElevatorSupervisor and Driver, are:
* ElevatorFinder: A UDP broadcasting module implemented using GenServer. Broadcasts itself to the other elevators, to connect them using the [Node](https://hexdocs.pm/elixir/Node.html) module. 
* ElevatorState: A statemachine implemented using GenServer. Also keeps track of the other elevators' state.
* Events: A module for supervising modules for polling for events at the buttons and changes to the floor. Implemented using Supervisor. 
* Events.Button: A module for polling a specific button. Calls the ElevatorState to update the current orders. 
* Events.Arrive: A module for polling for changes to the floor. Calls the ElevatorState to update the current orders.

