defmodule Events do
  use Supervisor

  # TODO: use supervisor
  # TODO: change internal floor, top and bottom floors to calls to the SimpleElevator

  def start_link(bottom_floor, top_floor) do
    Supervisor.start_link(__MODULE__, [bottom_floor, top_floor])
  end

  # def init([bottom_floor, top_floor]) do
  #   Events.init(bottom_floor, top_floor)
  # end

  def init([bottom_floor, top_floor]) do
    IO.inspect(__MODULE__, label: "Initializing starting")
    # TODO: clean up bellow, maybe add button_floor range to the config in SimpleElevator?
    button_floor = %{
      :command => bottom_floor..top_floor,
      :call_up => bottom_floor..(top_floor - 1),
      :call_down => (bottom_floor + 1)..top_floor
    }

    children = Enum.map(Map.keys(button_floor),
      fn button_type ->
        Enum.map(button_floor[button_type],
          fn floor ->
            # GenServer.cast(Driver, {:set_order_button_light, button_type, floor, :off})
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
      # GenStateMachine.cast(SimpleElevator, {:send_request, floor, button_type})
      # GenStateMachine.call(SimpleElevator, :share_state)
      # TODO: change polling_period when found a button press?
    end

    Process.send_after(self(), :poll, @polling_period)

    {:noreply, {floor, button_type}}
  end

end


defmodule Events.Arrive do
  use GenServer

  @polling_period 100

  def start_link(start_floor, bottom_floor, top_floor) do
    GenServer.start_link(__MODULE__, [start_floor, bottom_floor, top_floor])
  end

  def init([start_floor, bottom_floor, top_floor]) do
    # GenStateMachine.cast(SimpleElevator, {:set_floor, start_floor})
    GenServer.cast(ElevatorState, {:set_floor, start_floor})

    Process.send_after(self(), :poll, @polling_period)

    {:ok, {start_floor, bottom_floor, top_floor}}
  end

  def handle_info(:poll, {floor, bottom_floor, top_floor}) do
    state = GenServer.call(ElevatorState, :get_state)
    {request_list, _} = GenServer.multi_call([Node.self() | Node.list()], RequestManager, :get_request, 100)
    request_list = request_list |> Map.new() |> Map.values()

    new_floor = GenServer.call(Driver, :get_floor_sensor_state)
    {reached_target, new_assignment, request_id} = GenServer.call(RequestManager, {:is_target, new_floor, state[:behaviour], request_list})
    # IO.inspect(request_id, label: "Current request")
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
        GenServer.cast(SimpleElevator, {:set_dir, :stop})
      end

      new_floor
    else
      floor
    end

    Process.send_after(self(), :poll, @polling_period)

    {:noreply, {floor, bottom_floor, top_floor}}
  end

end
