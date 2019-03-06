defmodule Events do
    
    # use GenStage

    # def start_link() do
    #     GenStage.start_link(__MODULE__, :no_state)
    # end

    # def init(state) do
    #     {:consumer, state, subscribe_to: [Events.Arrive]}
    # end

    # def handle_events(events, _from, state) do
    #     # handle events!
    #     # pattern matching 

    #     {:noreply, [], state}
    # end

end

defmodule Events.Button do

end

defmodule Events.Button.Command do

end

defmodule Events.Button.CallUp do 

end

defmodule Events.Button.CallDown do

    # def start(pid) do
    #     start(pid, 1, [])
    # end

    # def start(pid, floor, buttons) when floor <= 3 do
    #     start(pid, floor + 1, [spawn(handle_call_down(pid, floor, Driver.get_order_button_state(pid, floor, :call_down))) | buttons])
    # end

    # def start(_pid, _floor, buttons) do
    #     buttons
    # end
    
    # def handle_call_down(pid, floor, button_pressed) when button_pressed == 1 do
    #     # add request
    #     # send to the rest of the network
    #     # turn light on 
    #     IO.puts("Button called down nn floor: #{floor}")
    #     Process.sleep(1000)
    #     handle_call_down(pid, floor, Driver.get_order_button_state(pid, floor, :call_down))
    # end

    # def handle_call_down(pid, floor, _button_pressed) do
    #     IO.puts("Waiting for button on floor: #{floor}")
    #     Process.sleep(1000)
    #     handle_call_down(pid, floor, Driver.get_order_button_state(pid, floor, :call_down))
    # end

end

defmodule Events.Arrive do

    @floor_timeout 100

    def start_link(driver_pid, state_pid) do 
        Driver.set_floor_indicator(driver_pid, 0)
        # TODO: change to use GenServer, and send_after (see udp_server module)
        pid = spawn_link(fn -> find_floor(driver_pid, state_pid, 0) end)
        {:ok, pid}
    end

    def find_floor(driver_pid, state_pid, old_floor) do 
        new_floor = Driver.get_floor_sensor_state(driver_pid)

        #IO.inspect new_floor
        if new_floor != old_floor do
            GenStateMachine.cast(SimpleElevator, {:set_floor, new_floor})

            # TODO: clean up
            direction = GenStateMachine.call(:get_dir)
            floor_call = GenStateMachine.call({:get_command, new_floor})
            floor_command_up = (GenStateMachine.call({:get_call_up, new_floor}) and direction == :up)
            floor_command_down = (GenStateMachine.call({:get_call_down, new_floor}) and direction == :down)
            if floor_call or floor_command_up or floor_command_down do
                # stop for x amount of time
                # open door for x amount of time
                Process.send(Events.Door, :open, [])
                
                # clear requests for this floor
                    # state and driver
                    # command and call locally
                    # calls globally

                calculate_new_direction = :stop
                Process.send_after(Events.Door, {:close, calculate_new_direction}, @floor_timeout)
                # close door 
                # get new direction
            end

            # change the local state
            # GenStateMachine.cast(state_pid, {:set_floor, new_floor})
            # fulfill the request commands locally
            # GenStateMachine.cast(state_pid, {:set_command, new_floor, false})
            # fulfill the request calls globally
            # GenServer.abcast() eventually
            # GenStateMachine.cast(state_pid, {:set_call_up, new_floor, false})

            
            Driver.set_floor_indicator(driver_pid, new_floor)
        end
        # send_after
        #Process.sleep(@floor_timeout)
        find_floor(driver_pid, new_floor)
    end


    
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

defmodule Events.Door do
    
    use GenServer

    def start_link do 
        GenServer.start_link(__MODULE__, [], [name: __MODULE__])
    end

    def init(_) do
        door_state = GenStateMachine.call(SimpleElevator, :get_door)

        {:ok, door_state}
    end

    def handle_info(:open, :closed) do
        GenServer.cast(Driver, {:set_motor_direction, :stop})
        GenServer.cast(Driver, {:set_door_open_light, :on})

        # changes to the state
        GenStateMachine.cast(SimpleElevator, {:set_dir, :stop})
        GenStateMachine.cast(SimpleElevator, {:set_door, :open})

        {:noreply, :open}
    end

    def handle_info({:close, dir}, :open) do
        GenServer.cast(Driver, {:set_door_open_light, :on})
        GenServer.cast(Driver, {:set_motor_direction, dir})

        # changes to the state
        GenStateMachine.cast(SimpleElevator, {:set_dir, dir})
        GenStateMachine.cast(SimpleElevator, {:set_door, :closed})

        {:noreply, :closed}
    end

    
end