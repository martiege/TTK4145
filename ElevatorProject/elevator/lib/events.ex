defmodule Events do
  use GenServer

  def start_link([bottom_floor, top_floor]) do
    GenServer.start_link(__MODULE__, [bottom_floor, top_floor])
  end

  def init([bottom_floor, top_floor]) do
    Events.init(bottom_floor, top_floor)
  end

  def init(bottom_floor, top_floor) do
    # lol how did this even work?
    # TODO: remove above comment
    # TODO: clean up bellow
    button_floor = %{
      :command => bottom_floor..top_floor,
      :call_up => bottom_floor..(top_floor - 1),
      :call_down => (bottom_floor + 1)..top_floor
    }
    buttons = Enum.map(Map.keys(button_floor), # [:command, :call_up, :call_down],
      fn button_type ->
        Enum.map(button_floor[button_type], # bottom_floor..top_floor,
          fn floor ->
            {:ok, pid} = Events.Button.start_link(floor, button_type)
            pid
            # IO.puts "Button type: #{button_type}, Floor: #{floor}"
            # {button_type, floor}
          end)
      end)
    {:ok, [Events.Arrive.start_link(bottom_floor, bottom_floor, top_floor) | buttons]}
  end
end


defmodule Events.Button do
  use GenServer

  @polling_period 100 # 10 hz human reaction time

  def start_link(floor, button_type) do
    GenServer.start_link(__MODULE__, [floor, button_type])
  end

  def init([floor, button_type]) do
    Events.Button.init(floor, button_type)
  end

  def init(floor, button_type) do
    Process.send_after(self(), :poll, @polling_period)

    {:ok, {floor, button_type}}
  end

  def handle_info(:poll, {floor, button_type}) do
    if GenServer.call(Driver, {:get_order_button_state, floor, button_type}) == 1 do
      GenStateMachine.cast(SimpleElevator, {:send_request, floor, button_type})
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
    Events.Arrive.init(start_floor, bottom_floor, top_floor)
  end

  def init(start_floor, bottom_floor, top_floor) do
    GenServer.cast(Driver, {:set_floor_indicator, start_floor})

    Process.send_after(self(), :poll, @polling_period)

    {:ok, {start_floor, bottom_floor, top_floor}}
  end

  def handle_info(:poll, {floor, bottom_floor, top_floor}) do
    # TODO: poll at different periods if new floor found?

    new_floor = GenServer.call(Driver, :get_floor_sensor_state)
    floor = if (new_floor != :between_floors) and (new_floor != floor) do
      GenStateMachine.cast(SimpleElevator, {:set_floor, new_floor})

      GenServer.cast(Driver, {:set_floor_indicator, new_floor})

      if (new_floor == bottom_floor) or (new_floor == top_floor) do
        # if at the top or bottom floors, stop anyways. no out of bounds.
        GenServer.cast(Driver, {:set_motor_direction, :stop})
      end

      new_floor
    else
      floor
    end

    Process.send_after(self(), :poll, @polling_period)

    {:noreply, {floor, bottom_floor, top_floor}}
  end

    # def start_link(driver_pid, state_pid) do
    #     Driver.set_floor_indicator(driver_pid, 0)
    #     # TODO: change to use GenServer, and send_after (see udp_server module)
    #     pid = spawn_link(fn -> find_floor(driver_pid, state_pid, 0) end)
    #     {:ok, pid}
    # end
    #
    # def find_floor(driver_pid, state_pid, old_floor) do
    #     new_floor = Driver.get_floor_sensor_state(driver_pid)
    #
    #     #IO.inspect new_floor
    #     if new_floor != old_floor do
    #         GenStateMachine.cast(SimpleElevator, {:set_floor, new_floor})
    #
    #         # TODO: clean up? this is messy and might not even work
    #         direction = GenStateMachine.call(:get_dir)
    #         floor_call = GenStateMachine.call({:get_command, new_floor})
    #         floor_command_up = (GenStateMachine.call({:get_call_up, new_floor}) and direction == :up)
    #         floor_command_down = (GenStateMachine.call({:get_call_down, new_floor}) and direction == :down)
    #         if floor_call or floor_command_up or floor_command_down do
    #             # stop for x amount of time
    #             # open door for x amount of time
    #             # Process.send(Events.Door, :open, [])
    #
    #             # clear requests for this floor
    #                 # state and driver
    #                 # command and call locally
    #                 # calls globally
    #
    #             calculate_new_direction = :stop
    #             Process.send_after(Events.Door, {:close, calculate_new_direction}, @floor_timeout)
    #             # close door
    #             # get new direction
    #         end
    #
    #         # change the local state
    #         # GenStateMachine.cast(state_pid, {:set_floor, new_floor})
    #         # fulfill the request commands locally
    #         # GenStateMachine.cast(state_pid, {:set_command, new_floor, false})
    #         # fulfill the request calls globally
    #         # GenServer.abcast() eventually
    #         # GenStateMachine.cast(state_pid, {:set_call_up, new_floor, false})
    #
    #
    #         Driver.set_floor_indicator(driver_pid, new_floor)
    #     end
    #     # send_after
    #     #Process.sleep(@floor_timeout)
    #     #find_floor(driver_pid, new_floor)
    # end



    # use GenStage

    # def start_link(pid) do
    #     GenStage.start_link(__MODULE__, pid, name: __MODULE__)
    # end

    # def init(pid) do
    #     {:producer, pid}
    # end

    # def handle_demand(demand, state) do
    #     event = Driver.get_floor_sensor_state(state)
    #     # add an identifier? [floor_state: event]
    #     {:noreply, event, state} # empty list implies no events?
    # end





    # def start(pid) do
    #     handle_floor(pid, Driver.get_floor_sensor_state(pid))
    # end

    # def handle_floor(pid, :between_floors) do
    #     IO.puts("Between floors!")
    #     Process.sleep(1000)
    #     handle_floor(pid, Driver.get_floor_sensor_state(pid))
    # end

    # def handle_floor(pid, floor) do
    #     # handle reaching a floor
    #     # open door (STOP)
    #     # clear requests
    #     # change state
    #     # sleep?
    #     IO.puts("On floor #{floor}!")
    #     Process.sleep(1000)
    #     handle_floor(pid, Driver.get_floor_sensor_state(pid))
    # end

end

# defmodule Events.Door do
#
#     use GenServer
#
#     def start_link do
#         GenServer.start_link(__MODULE__, [], [name: __MODULE__])
#     end
#
#     def init(_) do
#         door_state = GenStateMachine.call(SimpleElevator, :get_door)
#
#         {:ok, door_state}
#     end
#
#     def handle_info(:open, :closed) do
#         GenServer.cast(Driver, {:set_motor_direction, :stop})
#         GenServer.cast(Driver, {:set_door_open_light, :on})
#
#         # changes to the state
#         GenStateMachine.cast(SimpleElevator, {:set_dir, :stop})
#         GenStateMachine.cast(SimpleElevator, {:set_door, :open})
#
#         {:noreply, :open}
#     end
#
#     def handle_info({:close, dir}, :open) do
#         GenServer.cast(Driver, {:set_door_open_light, :on})
#         GenServer.cast(Driver, {:set_motor_direction, dir})
#
#         # changes to the state
#         GenStateMachine.cast(SimpleElevator, {:set_dir, dir})
#         GenStateMachine.cast(SimpleElevator, {:set_door, :closed})
#
#         {:noreply, :closed}
#     end
#
#
# end
