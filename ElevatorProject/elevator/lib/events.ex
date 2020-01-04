defmodule Events do
  @moduledoc """
  The Events module launches and 
	maintains one instance of the
	Events.Button modules for each 
	of the call and command buttons, 
	as well as one instance of the 
	Events.Arrive module. 
	
  The module does not receive or send any 
	messages.  
	
  ## Starting the module: 
  
	iex> Events.start_link(bottom_floor, top_floor)
	
  
  """

  use Supervisor

  def start_link(bottom_floor, top_floor) do
    Supervisor.start_link(__MODULE__, [bottom_floor, top_floor])
  end

  def init([bottom_floor, top_floor]) do
    IO.inspect(__MODULE__, label: "Initializing starting")
    button_floor = %{
      :command => bottom_floor..top_floor,
      :call_up => bottom_floor..(top_floor - 1),
      :call_down => (bottom_floor + 1)..top_floor
    }

    children = Enum.map(Map.keys(button_floor),
      fn button_type ->
        Enum.map(button_floor[button_type],
          fn floor ->
            %{ # specify child spec, and give each button it's own unique id atom
              id: (to_string(button_type) <> to_string(floor)) |> String.to_atom(),
              start: {Events.Button, :start_link, [floor, button_type]},
              restart: :permanent,
              shutdown: 5000,
              type: :worker
            }
          end)
      end) |> List.flatten() # finally, flatten the list

    children = [ %{ # specify child spec for the Events.Arrive module and concat it
    id: Events.Arrive,
    start: {Events.Arrive, :start_link, [bottom_floor, bottom_floor, top_floor]},
    restart: :permanent,
    shutdown: 5000,
    type: :worker} | children]

    IO.inspect(__MODULE__, label: "Initializing finished")

    Supervisor.init(children, strategy: :one_for_one)
  end
end


defmodule Events.Button do
  @moduledoc """
  The Events.Button module implements 
	polling a specific button type at 
	a specific floor, at a specific 
	polling period. 
	
  The module does not receive any messages 
	other than selfcalls to initiate 
	the next polling. 

  The module will send a cast to the
	ElevatorState if an event has been 
	registered. 
	
  ## Starting the module: 
  
	iex> Events.Button.start_link(floor, button_type)
	
  
  """
  use GenServer

  @polling_period 100 # 10 hz human reaction time

  def start_link(floor, button_type) do
    GenServer.start_link(__MODULE__, [floor, button_type])
  end

  def init([floor, button_type]) do
    Process.send_after(self(), :poll, @polling_period)

    {:ok, {floor, button_type}}
  end

  def handle_info(:poll, {floor, button_type}) do
    if GenServer.call(Driver, {:get_order_button_state, floor, button_type}) == 1 do
      GenServer.cast(ElevatorState, {:send_request, floor, button_type})
      GenServer.cast(RequestManager, {:add_request, {button_type, floor}})
    end

    Process.send_after(self(), :poll, @polling_period)

    {:noreply, {floor, button_type}}
  end

end


defmodule Events.Arrive do
  @moduledoc """
  The Events.Arrive module implements 
	periodic polling of changes to the 
	floor state. As well as updating the
	ElevatorState, it also keeps it's own
	floor state for redundancy. 
	
  The module does not receive any messages 
	other than selfcalls to initiate 
	the next polling. 

  The module will send a call to the
	ElevatorState if 
	  there are any changes to the floor
	  there is a reason to stop 
	  it should enter an open door state
	  
  ## Starting the module: 
  
	iex> Events.Arrive.start_link(start_floor, bottom_floor, top_floor)
	
  
  """
  use GenServer

  @polling_period 100

  def start_link(start_floor, bottom_floor, top_floor) do
    GenServer.start_link(__MODULE__, [start_floor, bottom_floor, top_floor])
  end

  def init([start_floor, bottom_floor, top_floor]) do
    GenServer.cast(ElevatorState, {:set_floor, start_floor})

    Process.send_after(self(), :poll, @polling_period)

    {:ok, {start_floor, bottom_floor, top_floor}}
  end

  def handle_info(:poll, {floor, bottom_floor, top_floor}) do
    state = GenServer.call(ElevatorState, :get_state)
    {request_list, _} = GenServer.multi_call([Node.self() | Node.list()], RequestManager, :get_request, 100)
    request_list = request_list |> Map.new() |> Map.values()

    new_floor = GenServer.call(Driver, :get_floor_sensor_state)
    {reached_target, _new_assignment, _request_id} = GenServer.call(RequestManager, {:is_target, new_floor, state[:behaviour], request_list})

    if (state[:behaviour] != :open_door) and
        (new_floor != :between_floors) and reached_target do
      GenServer.cast(ElevatorState, {:open_door, new_floor})
    end

    floor = if (state[:behaviour] != :open_door) and
                (new_floor != :between_floors) and
                (new_floor != floor) do
      GenServer.cast(ElevatorState, {:set_floor, new_floor})

      if GenServer.call(ElevatorState, {:should_stop, new_floor}) and
          (state[:behaviour] != :open_door) do
        GenServer.cast(ElevatorState, {:open_door, new_floor})
      end

      if (new_floor == bottom_floor) or (new_floor == top_floor) do
        GenServer.cast(ElevatorState, {:set_dir, :stop})
      end

      new_floor
    else
      floor
    end

    Process.send_after(self(), :poll, @polling_period)

    {:noreply, {floor, bottom_floor, top_floor}}
  end

end
