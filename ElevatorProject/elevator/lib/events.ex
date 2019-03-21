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
      GenStateMachine.cast(SimpleElevator, {:send_request, floor, button_type})
      GenStateMachine.call(SimpleElevator, :share_state)
      # TODO: speed up polling_period when found a button press?
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
    GenStateMachine.cast(SimpleElevator, {:set_floor, start_floor})

    Process.send_after(self(), :poll, @polling_period)

    {:ok, {start_floor, bottom_floor, top_floor}}
  end

  def handle_info(:poll, {floor, bottom_floor, top_floor}) do
    # TODO: poll at different periods if new floor found?

    # TODO: open door when a request is issued on this floor
    # this actually doesn't work properly
    # if GenStateMachine.call(SimpleElevator, {:requests_at_floor, floor}) do
    #   GenStateMachine.cast(SimpleElevator, {:open_door, floor})
    # end

    new_floor = GenServer.call(Driver, :get_floor_sensor_state)

    floor = if (new_floor != :between_floors) and (new_floor != floor) do
      GenStateMachine.cast(SimpleElevator, {:set_floor, new_floor})

      # GenServer.cast(Driver, {:set_floor_indicator, new_floor})
      # TODO: also update the SimpleElevator GenStateMachine

      if GenStateMachine.call(SimpleElevator, {:should_stop, new_floor}) do
        # GenStateMachine.cast(SimpleElevator, {:set_motor_direction, :stop})
        GenStateMachine.cast(SimpleElevator, {:open_door, new_floor})
        # GenServer.cast(Driver, {:set_motor_direction, :stop})
      end

      if (new_floor == bottom_floor) or (new_floor == top_floor) do
        # if at the top or bottom floors, stop anyways. no out of bounds.
        # TODO: maybe add this to the SimpleElevator call?
        GenStateMachine.cast(SimpleElevator, {:set_motor_direction, :stop})
      end

      GenStateMachine.cast(SimpleElevator, :share_state)

      new_floor
    else
      floor
    end

    Process.send_after(self(), :poll, @polling_period)

    {:noreply, {floor, bottom_floor, top_floor}}
  end

end
