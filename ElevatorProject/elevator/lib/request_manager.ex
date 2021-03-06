defmodule RequestManager do
  @moduledoc """
  The RequestManager module implements 
	keeping track of, moving towards and
	updating the current request target 
	of the elevator. 
	
  The module also implements a cost 
	function, to ensure the "best" elevator
	will take new requests. 
	
  The module receives calls from the 
	ElevatorState and Events.Arrive 
	modules, to ensure that only one elevator 
	will take a given request. 
	
  The module keeps track of the current 
	target request, given as 
	{button_type, floor}. In case there
	are no active targets, no target is 
	implemented as an empty tuple {}. 
	
  ## Starting the module: 
  
	iex> RequestManager.start_link(target)
	
  
  """
  use GenServer

  @get_state_timeout 100
  @clear_floor_timeout 100

  @floor_penalty 1
  @direction_penalty 1
  @behaviour_penalty 2
  @assigned_penalty 1

  def start_link() do
    RequestManager.start_link({})
  end

  def start_link(target) do
    GenServer.start_link(__MODULE__, [target], [name: __MODULE__])
  end

  def init([target]) do
    IO.inspect(__MODULE__, label: "Initializing starting")


    IO.inspect(__MODULE__, label: "Initializing finished")

    {:ok, target}
  end

  def handle_call(:get_request, _from, request_id) do
    {:reply, request_id, request_id}
  end

  def handle_call({:is_target, _floor, behaviour, request_list}, _from, {}) do
    request_id = if behaviour == :idle do
      get_new_request(request_list) |> assign_request(request_list)
    else
      {}
    end

    {:reply, {false, request_id != {}, request_id}, request_id}
  end

  def handle_call({:is_target, floor, behaviour, request_list}, _from, request_id) do
    {_, request_floor} = request_id

    if floor == request_floor do
      {replies, bad_nodes} = multi_call(Node.list(), ElevatorState, {:clear_floor, floor}, @clear_floor_timeout)
      Task.start_link(fn ->
        handle_bad_nodes(bad_nodes, ElevatorState, {:clear_floor, floor},
          @clear_floor_timeout, :all_requests_cleared, replies)
      end)

      GenServer.call(ElevatorState, {:clear_floor, floor}, @clear_floor_timeout)
      GenServer.call(ElevatorState, {:clear_request, floor, :command}, @clear_floor_timeout)

      request_id = get_new_request(request_list) |> assign_request(request_list)

      {:reply, {true, request_id != {}, request_id}, request_id}
    else
      request_id = if behaviour == :idle do
        request_id |> assign_request(request_list)
      else
        request_id
      end

      {:reply, {false, request_id != {}, request_id}, request_id}
    end
  end

  def handle_cast({:all_requests_cleared, _replies}, request_id) do
    {:noreply, request_id}
  end

  def handle_cast(:clear_request, _request_id) do
    {:noreply, {}}
  end

  def handle_cast({:add_request, {button_type, floor}}, request_id) do
    request_id = if request_id == {} do
      {button_type, floor}
    else
      request_id
    end

    {:noreply, request_id}
  end

  defp assign_request({}, _) do
    GenServer.cast(ElevatorState, {:set_dir, :stop})
    {}
  end

  defp assign_request(request_id, request_list) do
    cond do
      not (request_id in request_list) ->
        {_, floor} = request_id
        dir = get_direction(GenServer.call(ElevatorState, :get_floor), floor)
        GenServer.cast(ElevatorState, {:set_dir, dir})
        request_id
      request_id != {} ->
        {button_type, floor} = request_id
        if button_type == :command do
          dir = get_direction(GenServer.call(ElevatorState, :get_floor), floor)
          GenServer.cast(ElevatorState, {:set_dir, dir})
          request_id
        else
          GenServer.cast(ElevatorState, {:set_dir, :stop})
          {}
        end
      true ->
        GenServer.cast(ElevatorState, {:set_dir, :stop})
        {}
    end
  end

  defp get_new_request(request_list) do
    local_state = GenServer.call(ElevatorState, :get_state, @get_state_timeout)
    {replies, _bad_nodes} = multi_call(Node.list(), ElevatorState, :get_state, @get_state_timeout)
    state_map = [{Node.self(), local_state} | replies] |> Map.new()

    state_map |>
      get_cost_list(request_list) |>
      get_minimum_cost_list() |>
      get_minimum_node(Node.self())
  end

  def multi_call(nodes, name, args, timeout) do
    GenServer.multi_call(nodes, name, args, timeout)
  end

  def handle_bad_nodes(bad_nodes, name, args, timeout, answer_message, original_replies) do
    replies = RequestManager.handle_bad_nodes(bad_nodes, name, args, timeout)

    GenServer.cast(RequestManager, {answer_message, replies ++ original_replies})
  end

  def handle_bad_nodes(bad_nodes, name, args, timeout) when length(bad_nodes) != 0 do
    bad_nodes = Node.list() -- (Node.list() -- bad_nodes)

    {replies, bad_nodes} = RequestManager.multi_call(bad_nodes, name, args, timeout)

    replies ++ RequestManager.handle_bad_nodes(bad_nodes, name, args, timeout)
  end

  def handle_bad_nodes([], _name, _args, _timeout) do
    []
  end

  defp get_direction(state_floor, request_floor) do
    cond do
      state_floor < request_floor   -> :up
      state_floor == request_floor  -> :stop
      state_floor > request_floor   -> :down
    end
  end

  defp get_cost(state, request_floor, button_type, request_list) do
    f_pen = @floor_penalty * abs(state[:floor] - request_floor)
    d_pen = @direction_penalty * cond do
      state[:dir] == get_direction(state[:floor], request_floor) ->
        0
      state[:dir] == :stop and state[:behaviour] == :idle -> # maybe
        0
      button_type == :command ->
        0
      state[:dir] != get_direction(state[:floor], request_floor) ->
        1
      true ->
        1
    end

    b_pen = @behaviour_penalty * if state[:behaviour] == :open_door or state[:behaviour] == :moving do
      1
    else
      0
    end

    a_pen = @assigned_penalty * if {button_type, request_floor} in request_list do
      if {button_type != :command} do
        1
      else
        0
      end
    else
      0
    end

    f_pen + d_pen + b_pen + a_pen
  end

  defp get_cost_list(state_map, request_list) do
    Enum.map(Map.keys(state_map),
    fn node_name ->
      state = state_map[node_name]
      ranges = state[:config][:button_floor_range]
      Enum.map(Map.keys(ranges) ,
      fn button_type ->
        Enum.map(ranges[button_type],
        fn floor ->
          if state[button_type] |> Enum.at(floor) do
            {{button_type, floor}, node_name, get_cost(state, floor, button_type, request_list)}
          else
            nil
          end
        end)
      end)
    end) |> List.flatten() |> Enum.filter(fn x -> x != nil end)
  end

  defp get_minimum_cost_list(cost_list) do
    Enum.reduce(cost_list, %{},
    fn {request_id, node_name, cost}, acc ->
      {_, updated} = Map.get_and_update(acc, request_id,
      fn current ->
        if current != nil do
          {current_node_name, current_cost} = current
          if (cost < current_cost) or (cost == current_cost and node_name < current_node_name) do
            {current, {node_name, cost}}
          else
            {current, {current_node_name, current_cost}}
          end
        else
          {current, {node_name, cost}}
        end
      end)

      updated
    end)
  end

  defp get_minimum_node(minimum_cost_list, node_name) do
    result = Enum.reduce(Map.keys(minimum_cost_list), {},
    fn request_id, acc ->
      {request_node, request_cost} = minimum_cost_list[request_id]
      if acc != {} do
        {acc_cost, acc_id} = acc
        if node_name == request_node do
          if request_cost < acc_cost do
            {request_cost, request_id}
          else
            {acc_cost, acc_id}
          end
        else
          {acc_cost, acc_id}
        end
      else
        if node_name == request_node do
          {request_cost, request_id}
        else
          {}
        end
      end
    end)

    if result == {} do
      {}
    else
      {_, id} = result
      id
    end
  end

end
