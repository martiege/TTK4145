defmodule SimpleElevator do
  @moduledoc """
  Documentation for SimpleElevator.
  """

  @doc """
  Hello world.

  ## Examples

      iex> SimpleElevator.hello()
      :world

  """
  @sync_timeout 100
  @door_timeout 5000
  @base_cost 100
  @top_floor 3
  @base_floor 0

  use GenStateMachine

  def start_link([]) do
    SimpleElevator.start_link()
  end

  def start_link() do
    init_request        = {false, @base_cost} # request base, initialized as false and base cost

    init_list           = List.duplicate(init_request, @top_floor - @base_floor) # request list base
    init_list_command   = [init_request | init_list] # command request list
    init_list_call_down = [:invalid] ++ init_list # first element of call down is invalid, last of call up
    init_list_call_up   = init_list ++ [:invalid]

    # local state
    state = %{
              :dir => :stop,
              :behaviour => :idle,
              :door => :closed,
              :floor => 0,
              :command => init_list_command,
              :call_up => init_list_call_up, 
              :call_down => init_list_call_down
             }
    # global states, ghost states
    data  = %{}

    GenStateMachine.start_link(__MODULE__, {state, data}, [name: __MODULE__])
  end

  def handle_event(:cast, :data, state, data) do
    IO.inspect(data)
    {:next_state, state, data}
  end

  def handle_event(:cast, :state, state, data) do
    IO.inspect(state)
    {:next_state, state, data}
  end

  # Floor
  # cast
  def handle_event(:cast, {:set_floor, floor}, state, data) do
    state = Map.replace!(state, :floor, floor)
    {:next_state, state, data}
  end

  # call
  def handle_event({:call, from}, :get_floor, state, data) do
    {:next_state, state, data, [{:reply, from, state[:floor]}]}
  end

  # Requests
  # command
  # cast
  def handle_event(:cast, {:set_command, floor, new_state}, state, data) do
    # TODO: simplify
    state = Map.replace!(state, :command, List.replace_at(state[:command], floor, new_state))
    {:next_state, state, data}
  end

  # call
  def handle_event({:call, from}, {:get_command, floor}, state, data) do
    {:next_state, state, data, [{:reply, from, Enum.at(state[:command], floor)}]}
  end

  # call up
  # cast
  def handle_event(:cast, {:set_call_up, floor, new_state}, state, data) do
    state = Map.replace!(state, :call_up, List.replace_at(state[:call_up], floor, new_state))
    {:next_state, state, data}
  end

  # call
  def handle_event({:call, from}, {:get_call_up, floor}, state, data) do
    {:next_state, state, data, [{:reply, from, Enum.at(state[:call_up], floor)}]}
  end

  # call down
  # cast
  def handle_event(:cast, {:set_call_down, floor, new_state}, state, data) do
    state = Map.replace!(state, :call_down, List.replace_at(state[:call_down], floor, new_state))
    {:next_state, state, data}
  end

  # call
  def handle_event({:call, from}, {:get_call_down, floor}, state, data) do
    {:next_state, state, data, [{:reply, from, Enum.at(state[:call_down], floor)}]}
  end

  # direction
  # cast
  def handle_event(:cast, {:set_dir, dir}, state, data) do
    state = Map.replace!(state, :dir, dir)
    {:next_state, state, data}
  end

  # call
  def handle_event({:call, from}, :get_dir, state, data) do
    {:next_state, state, data, [{:reply, from, state[:dir]}]}
  end

  # behaviour
  # cast
  def handle_event(:cast, {:set_behaviour, behaviour}, state, data) do
    state = Map.replace!(state, :behaviour, behaviour)
    {:next_state, state, data}
  end

  # call
  def handle_event({:call, from}, :get_behaviour, state, data) do
    {:next_state, state, data, [{:reply, from, state[:behaviour]}]}
  end

  # clear requests
  def handle_event({:call, from}, {:clear, floor, node_name}, state, data) do
    IO.puts "Cleaning floor #{floor}"

    # make this it's own function such that we can call this independantly
    helper_clear_requests(floor, node_name, data)

    IO.puts "Done cleaning"
    {:next_state, state, data, [{:reply, from, :cleared}]}
  end

  def helper_clear_requests(floor, node_name, data) do
    IO.puts "Data: "
    IO.inspect(data)
    
    for node <- [self() | Node.list()] do
      IO.puts "Node: "
      IO.inspect(node)

      data = if Map.has_key?(data, node) do
        
        node_state = Map.get(data, node)
      
        IO.inspect(node_state)

        node_state = if node == node_name do
          node_state = helper_clear_requests(node_state, floor)
          node_state = helper_clear_request(node_state, floor, :command)
          node_state
        else
          node_state = helper_clear_requests(node_state, floor)
          node_state
        end
  
        data = Map.replace!(data, node, node_state)
        data
      end
    end
  end

  def helper_clear_requests(state, floor) do
    state = helper_clear_request(state, floor, :call_up)
    state = helper_clear_request(state, floor, :call_up)
    state
  end

  def helper_clear_request(state, floor, request) do
    req_state = Map.get(state, request)
    cleared = helper_clear_request_invalid(Enum.at(req_state, floor))
    cleard_list = List.replace_at(req_state, floor, cleared)
    state = Map.replace!(state, request, cleard_list)
    state
  end

  def helper_clear_request_invalid({_bool, cost}) do
    {true, cost}
  end

  def helper_clear_request_invalid(:invalid) do
    :invalid
  end

  # door
  def handle_event(:cast, {:open_door, floor}, state, data) do
    Process.send_after(self(), :close_door, @door_timeout)

    GenServer.cast(Driver, {:set_motor_direction, :stop})
    GenServer.cast(Driver, {:set_door_open_light, :on})

    state = Map.replace!(state, :dir, :stop)
    state = Map.replace!(state, :door, :open)

    # remove the requests here and globally
    # GenStateMachine.call(SimpleElevator, {:clear, floor, self()}, @sync_timeout)
    helper_clear_requests(floor, self(), data)
    {replies, bad_nodes} = GenServer.multi_call(Node.list(), SimpleElevator, {:clear, floor, self()}, @sync_timeout)

    IO.puts "Replies"
    IO.inspect(replies)
    IO.puts "Bad nodes"
    IO.inspect(bad_nodes)

    {:next_state, state, data}
  end

  def handle_event(:info, :close_door, state, data) do
    GenServer.cast(Driver, {:set_motor_direction, :stop})
    GenServer.cast(Driver, {:set_door_open_light, :off})

    state = Map.replace!(state, :dir, :stop) # change to move to next request
    state = Map.replace!(state, :door, :closed)

    {:next_state, state, data}
  end

  # cast
  def handle_event(:cast, {:set_door, door_state}, state, data) do
    state = Map.replace!(state, :door, door_state)
    {:next_state, state, data}
  end

  # call
  def handle_event({:call, from}, :get_door, state, data) do
    {:next_state, state, data, [{:reply, from, state[:door]}]}
  end

  # start sending local state
  def handle_event(:cast, :share_state, state, data) do
    # IO.puts "\n"
    # IO.puts "Start sharing state..."

    # only send to other nodes
    # may need special handeling later? tough doubt it...
    {replies, bad_nodes} = GenServer.multi_call(Node.list(), SimpleElevator, {:sync_state, state}, @sync_timeout)

    # IO.puts "Replies"
    # IO.inspect(replies)
    # IO.puts "Bad nodes"
    # IO.inspect(bad_nodes)

    #handle_bad_nodes(bad_nodes, state)

    {:next_state, state, data}
  end

  def handle_bad_nodes(bad_nodes, state) do
    IO.puts "Handling bad nodes"
    # might be "stuck" if nodes are cont. using long time to reply
    # is fine, but might be handled (finite steps)
    # though not needed for this project
    {_replies, bad_nodes} = GenServer.multi_call(Node.list(), SimpleElevator, {:sync_state, state}, @sync_timeout)

    handle_bad_nodes(bad_nodes,  state)
  end

  def handle_bad_nodes([], _state) do
    IO.puts "Done with bad nodes"
    :ok
  end

  # sync ghost state from other nodes (or itself)
  def handle_event({:call, from}, {:sync_state, other_state}, state, data) do
    # IO.puts "Getting another state..."
    # IO.inspect(from)

    {_pid, {_ref, node_name}} = from

    # update and merge ghost state
    # everything "should" be up to date, as we are sending each individual event
      # TODO IMPLEMENT THIS!
    # merge the requests
    # IO.puts "Node name: "
    # IO.inspect(node_name)

    # IO.puts "Old data"
    # IO.inspect(data)

    data = case Map.has_key?(data, node_name) do
      true ->
        # merge
        merged_state = Map.get(data, node_name) |> Map.merge(other_state, fn k, p, s -> helper_merge(k, p, s) end)
        Map.replace!(data, node_name, merged_state)
      false ->
        # add new
        Map.put(data, node_name, other_state)
      _ ->
        # well this shouldn't happen... 
        data
    end


    # IO.puts "New data"
    # IO.inspect(data)

    {:next_state, state, data, [{:reply, from, :ack}]}
  end

  def helper_merge(key, primary_value, secondary_value) do
    if (key == :command or key == :call_up or key == :call_down) do
      Enum.map(Enum.zip(primary_value, secondary_value), fn e -> helper_merge_element(e) end)
    else 
      primary_value
    end
  end


  def helper_merge_element({{p_bool, p_cost}, {s_bool, s_cost}}) do
    {p_bool and s_bool, max(p_cost, s_cost)}
  end

  def helper_merge_element({:invalid, :invalid}) do
    :invalid
  end

end
