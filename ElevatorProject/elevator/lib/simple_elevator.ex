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
  @door_timeout 2000
  # @base_cost 100
  # @top_floor 3
  # @base_floor 0

  use GenStateMachine

  def start_link([bottom_floor, top_floor]) do
    SimpleElevator.start_link(bottom_floor, top_floor)
  end

  def start_link(bottom_floor, top_floor) do
    GenStateMachine.start_link(__MODULE__, [bottom_floor, top_floor], [name: __MODULE__])
  end

  def init([bottom_floor, top_floor]) do
    SimpleElevator.init(bottom_floor, top_floor)
  end

  def init(bottom_floor, top_floor) do
    IO.inspect(__MODULE__, label: "Initializing starting")


    # local state
    state = SimpleElevator.initialize_state(bottom_floor, top_floor)
    # global states, ghost states
    data  = %{}

    IO.inspect(__MODULE__, label: "Initializing finished")

    {:ok, state, data}
  end

  def initialize_state(bottom_floor, top_floor) do
    # init_request        = {false, @base_cost} # request base, initialized as false and base cost

    # init_list           = List.duplicate(false, @top_floor - @base_floor) # request list base
    # init_list_command   = [false | init_list] # command request list
    # init_list_call_down = [:invalid] ++ init_list # first element of call down is invalid, last of call up
    # init_list_call_up   = init_list ++ [:invalid]

    list = List.duplicate(false, top_floor - bottom_floor + 1)

    %{
      :dir => :stop,
      :behaviour => :idle,
      :door => :closed,
      :floor => 0,
      :command => list,      # init_list_command,
      :call_up => list,      # init_list_call_up,
      :call_down => list,    # init_list_call_down,
      :config => %{:bottom_floor => bottom_floor, :top_floor => top_floor}
    }
  end

  def handle_event({:call, from}, :get_state, state, data) do
    {:next_state, state, data, [{:reply, from, state}]}
  end

  def handle_event({:call, from}, :get_data, state, data) do
    {:next_state, state, data, [{:reply, from, data}]}
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
    GenServer.cast(Driver, {:set_floor_indicator, floor})

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
  def handle_event(:cast, {:set_motor_direction, dir}, state, data) do
    state = Map.replace!(state, :dir, dir)
    GenServer.cast(Driver, {:set_motor_direction, dir})

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

  # add request
  def handle_event(:cast, {:send_request, floor, button_type}, state, data) do
    state = helper_update_state_request(state, floor, button_type)

    {replies, bad_nodes} = if (button_type != :command) do
      GenServer.multi_call(Node.list(), SimpleElevator, {:get_request, floor, button_type}, @sync_timeout)
    else
      {[], []}
    end

    replies = replies ++ handle_bad_nodes(bad_nodes, {:get_request, floor, button_type})

    # TODO: check if reply length is correct, handle spending time in handle_bad_nodes
    # TODO: ask how to implement this best...
    GenServer.cast(Driver, {:set_order_button_light, button_type, floor, :on})

    {replies, bad_nodes} = if (button_type != :command) do
      GenServer.multi_call(Node.list(), SimpleElevator, {:set_order_button_light, button_type, floor, :on})
    else
      {[], []}
    end

    replies = replies ++ handle_bad_nodes(bad_nodes, {:set_order_button_light, button_type, floor, :on})

    {:next_state, state, data}
  end

  def handle_event({:call, from}, {:should_stop, floor}, state, data) do
    IO.inspect(state)
    global_stop = case state[:dir] do
      :up   -> 
        Enum.at(state[:call_up], floor )
      :down -> 
        Enum.at(state[:call_down], floor)
      :stop -> 
        Enum.at(state[:call_up], floor) or Enum.at(state[:call_down], floor)
      what  -> 
        IO.puts("Something happened in should_stop")
        IO.inspect(what)
        false
    end

    local_stop = Enum.at(state[:command], floor)

    {:next_state, state, data, [{:reply, from, global_stop or local_stop}]}
  end

  # call-wrapper around Driver set_order_button_light
  def handle_event({:call, from}, {:set_order_button_light, button_type, floor, button_state}, state, data) do
    GenServer.cast(Driver, {:set_order_button_light, button_type, floor, button_state})

    {:next_state, state, data, [{:reply, from, :ack}]}
  end

  # get request
  def handle_event({:call, from}, {:get_request, floor, button_type}, state, data) do
    state = helper_update_state_request(state, floor, button_type)

    {:next_state, state, data, [{:reply, from, :ack}]}
  end

  defp helper_update_state_request(state, floor, button_type) do
    {_, state} = Map.get_and_update(state, button_type,
      fn request_list ->
        {request_list, helper_update_request_list(request_list, floor)}
      end)
    state
  end

  defp helper_update_request_list(request_list, floor) do
    # TODO: recalculate cost!
    # {_, cost} = Enum.at(request_list, floor)
    List.replace_at(request_list, floor, true)
  end

  # clear requests
  def handle_event({:call, from}, {:clear, floor, node_name}, state, data) do
    IO.puts "Cleaning floor #{floor}"

    # make this it's own function such that we can call this independantly
    data = helper_clear_requests_data(floor, node_name, data)
    state = helper_clear_requests_state(floor, state)

    IO.puts "Done cleaning"
    {:next_state, state, data, [{:reply, from, :cleared}]}
  end

  def helper_clear_requests_state(floor, state) do
    IO.puts "State: "
    IO.inspect(state)

    state = helper_clear_requests(state, floor)
    helper_clear_request(state, floor, :command)
  end

  def helper_clear_requests_data(floor, node_name, data) do
    IO.puts "Data: "
    IO.inspect(data)

    for node <- Node.list() do
      IO.puts "Node: "
      IO.inspect(node)

      data = if Map.has_key?(data, node)do

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
      else
        data
      end
    end

    data
  end

  def helper_clear_requests(state, floor) do
    state = helper_clear_request(state, floor, :call_up)
    state = helper_clear_request(state, floor, :call_down)
    state
  end

  def helper_clear_request(state, floor, button_type) do
    req_state = Map.get(state, button_type)
    # cleared = helper_clear_request_invalid(Enum.at(req_state, floor))
    cleard_list = List.replace_at(req_state, floor, false)
    GenServer.cast(Driver, {:set_order_button_light, button_type, floor, :off})
    state = Map.replace!(state, button_type, cleard_list)
    state
  end

  # def helper_clear_request_invalid({_bool, cost}) do
  #   false
  # end
  #
  # def helper_clear_request_invalid(:invalid) do
  #   :invalid
  # end

  def handle_event({:call, from}, {:requests_at_floor, floor}, state, data) do
    request = Enum.at(state[:command], floor) or Enum.at(state[:call_down], floor) or Enum.at(state[:call_up], floor)
    {:next_state, state, data, [{:reply, from, request}]}
  end

  # door
  def handle_event(:cast, {:open_door, floor}, state, data) do
    Process.send_after(self(), :close_door, @door_timeout)

    GenServer.cast(Driver, {:set_motor_direction, :stop})
    GenServer.cast(Driver, {:set_door_open_light, :on})

    # state = Map.replace!(state, :dir, :stop)
    state = Map.replace!(state, :door, :open)
    state = Map.replace!(state, :behaviour, :open_door)

    # remove the requests here and globally
    # GenStateMachine.call(SimpleElevator, {:clear, floor, self()}, @sync_timeout)
    data = helper_clear_requests_data(floor, self(), data)
    state = helper_clear_requests_state(floor, state)
    {replies, bad_nodes} = GenServer.multi_call(Node.list(), SimpleElevator, {:clear, floor, self()}, @sync_timeout)

    state = helper_clear_requests_state(floor, state)

    IO.puts "Replies"
    IO.inspect(replies)
    IO.puts "Bad nodes"
    IO.inspect(bad_nodes)

    {:next_state, state, data}
  end

  def handle_event(:info, :close_door, state, data) do
    GenServer.cast(Driver, {:set_door_open_light, :off})
    GenServer.cast(Driver, {:set_motor_direction, state[:dir]})

    # state = Map.replace!(state, :dir, :stop) # change to move to next request
    state = Map.replace!(state, :door, :closed)
    state = if state[:dir] == :stop do
      Map.replace!(state, :door, :idle)  
    else
      Map.replace!(state, :door, :moving)
    end

    # TODO: Cost 

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

  # request all potential backup states
  def handle_event(:cast, :get_backup, state, data) do

    {replies, bad_nodes} = GenServer.multi_call(Node.list(), SimpleElevator, {:send_backup, Node.self()}, @sync_timeout)

    replies = replies ++ handle_bad_nodes(bad_nodes, {:send_backup, Node.self()})

    # IO.puts "Replies from requesting backups"
    # IO.inspect(replies)
    # TODO: handle replies

    merged_state = Enum.reduce(replies, state, fn {_node_name, reply}, acc ->
      if is_map(reply) do
        merge_states(acc, reply, length(Map.keys(state)))
      else
        acc
      end
    end)

    {:next_state, merged_state, data}
  end

  # get a backup state
  def handle_event({:call, from}, {:send_backup, node_name}, state, data) do
    # IO.puts "Current data"
    # IO.inspect(data)
    {:next_state, state, data, [{:reply, from, Map.get(data, node_name, false) }]}
  end

  # start sending local state
  def handle_event(:cast, :share_state, state, data) do
    # IO.puts "\n"
    # IO.puts "Start sharing state..."

    # only send to other nodes
    # may need special handeling later? tough doubt it...
    {replies, bad_nodes} = GenServer.multi_call(Node.list(), SimpleElevator, {:sync_state, state, Node.self()}, @sync_timeout)

    # cast function, no use replies for now...
    replies = replies ++ handle_bad_nodes(bad_nodes, {:sync_state, state, Node.self()})

    {:next_state, state, data}
  end

  # sync ghost state from other nodes (or itself)
  def handle_event({:call, from}, {:sync_state, other_state, node_name}, state, data) do
    # IO.puts "Getting another state..."
    # IO.inspect(from)

    # {_pid, {_ref, node_name}} = from

    # update and merge ghost state
    # everything "should" be up to date, as we are sending each individual event
      # TODO IMPLEMENT THIS!
    # merge the requests
    # IO.puts "Node name: "
    # IO.inspect(node_name)

    # IO.puts "Old data"
    # IO.inspect(data)

    data = if Map.has_key?(data, node_name) do
      # merged_state = Map.get(data, node_name) |> Map.merge(other_state, fn k, p, s -> helper_merge(k, p, s) end)
      Map.replace!(data, node_name, merge_states(Map.get(data, node_name), other_state, length(Map.keys(state))))
    else
      Map.put(data, node_name, other_state)
    end

    # IO.puts "New data"
    # IO.inspect(data)

    {:next_state, state, data, [{:reply, from, :ack}]}
  end

  # merging list of states into one
  # defp merge_states([head_state | tail_states]) do
  #   Enum.reduce(states, head_state, fn state, accumulative_state -> merge_states(state, accumulative_state) end)
  # end

  defp merge_states(primary_state, secondary_state, state_size) when is_map(primary_state) and is_map(secondary_state) do
    primary_valid = primary_state |> Map.keys() |> length() == state_size
    secondary_valid = secondary_state |> Map.keys() |> length() == state_size

    if (not primary_valid) or (not secondary_valid) do
      IO.puts "An invalid state..."
      IO.inspect(primary_state, label: "Primary state")
      IO.inspect(secondary_state, label: "Secondary state")
      IO.inspect(state_size, label: "State size")
    end

    cond do
      primary_valid and secondary_valid ->
        primary_state |> Map.merge(secondary_state, fn k, p, s -> helper_merge(k, p, s) end)
      (not primary_valid) and secondary_valid ->
        secondary_state
      (not secondary_valid) and primary_valid ->
        primary_state
      (not primary_valid) and (not secondary_valid) ->
        # empty state in case of all invalid states
        IO.inspect(primary_state, "Primary state")
        IO.inspect(secondary_state, "Secondary state")
    end
  end

  defp helper_merge(key, primary_value, secondary_value) do
    if (key == :command or key == :call_up or key == :call_down) do
      Enum.map(Enum.zip(primary_value, secondary_value), fn e -> helper_merge_element(e) end)
    else
      primary_value
    end
  end


  defp helper_merge_element({p_bool, s_bool}) do
    p_bool or s_bool
  end

  defp handle_bad_nodes(bad_nodes, message) when length(bad_nodes) != 0 do
    IO.puts "Handling bad nodes"
    IO.inspect(bad_nodes)
    IO.puts "Handling this message"
    IO.inspect(message)
    # find bad nodes still alive, union of Node.list() and bad_nodes
    bad_nodes = Node.list() -- (Node.list() -- bad_nodes)
    # might be "stuck" if nodes are cont. using long time to reply
    # is fine, but might be handled (finite steps)
    # though not needed for this project
    {replies, bad_nodes} = GenServer.multi_call(bad_nodes, SimpleElevator, message, @sync_timeout)

    replies ++ handle_bad_nodes(bad_nodes,  message)
  end

  defp handle_bad_nodes([], _message) do
    IO.puts "Done with bad nodes"
    []
  end

end
