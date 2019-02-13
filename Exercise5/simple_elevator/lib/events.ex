defmodule Events do
    
    use GenStage

    def start_link() do
        GenStage.start_link(__MODULE__, :no_state)
    end

    def init(state) do
        {:consumer, state, subscribe_to: [Events.Arrive]}
    end

    def handle_events(events, _from, state) do
        # handle events!
        # pattern matching 

        {:noreply, [], state}
    end

end

defmodule Events.Button do

end

defmodule Events.Button.Command do

end

defmodule Events.Button.CallUp do 

end

defmodule Events.Button.CallDown do

    def start(pid) do
        start(pid, 1, [])
    end

    def start(pid, floor, buttons) when floor <= 3 do
        start(pid, floor + 1, [spawn(handle_call_down(pid, floor, Driver.get_order_button_state(pid, floor, :call_down))) | buttons])
    end

    def start(_pid, _floor, buttons) do
        buttons
    end
    
    def handle_call_down(pid, floor, button_pressed) when button_pressed == 1 do
        # add request
        # send to the rest of the network
        # turn light on 
        IO.puts("Button called down nn floor: #{floor}")
        Process.sleep(1000)
        handle_call_down(pid, floor, Driver.get_order_button_state(pid, floor, :call_down))
    end

    def handle_call_down(pid, floor, _button_pressed) do
        IO.puts("Waiting for button on floor: #{floor}")
        Process.sleep(1000)
        handle_call_down(pid, floor, Driver.get_order_button_state(pid, floor, :call_down))
    end

end

defmodule Events.Arrive do

    use GenStage

    def start_link(pid) do
        GenStage.start_link(__MODULE__, pid, name: __MODULE__)
    end

    def init(pid) do
        {:producer, pid}
    end

    def handle_demand(demand, state) do
        event = Driver.get_floor_sensor_state(state)
        # add an identifier? [floor_state: event]
        {:noreply, event, state} # empty list implies no events?
    end





    def start(pid) do
        handle_floor(pid, Driver.get_floor_sensor_state(pid))
    end

    def handle_floor(pid, :between_floors) do
        IO.puts("Between floors!")
        Process.sleep(1000)
        handle_floor(pid, Driver.get_floor_sensor_state(pid))
    end

    def handle_floor(pid, floor) do
        # handle reaching a floor
        # open door (STOP)
        # clear requests
        # change state
        # sleep?
        IO.puts("On floor #{floor}!")
        Process.sleep(1000)
        handle_floor(pid, Driver.get_floor_sensor_state(pid))
    end

end

