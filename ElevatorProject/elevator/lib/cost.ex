defmodule Cost do

  @floor_penalty 1
  @direction_penalty 1

  def get_cost(state, request_floor, button_type) do
    f_pen = @floor_penalty * abs(state[:floor] - request_floor)
    # TODO: consider get_direction :stop, state[:dir] not?
    d_pen = @direction_penalty * cond do
      state[:dir] == get_direction(state[:floor], request_floor) ->
        0
      state[:dir] == :stop and state[:behaviour] == :idle -> # maybe
        0
      state[:dir] != get_direction(state[:floor], request_floor) ->
        1
      state[:behaviour] == :open_door or state[:behaviour] == :moving ->
        2
      true ->
        1
    end

    f_pen + d_pen
  end

  def get_direction(state_floor, request_floor) do
    cond do
      state_floor < request_floor   -> :up
      state_floor == request_floor  -> :stop
      state_floor > request_floor   -> :down
    end
  end

  def get_cost_list(state, data, request_floor, button_type) do
    local = get_cost(state, request_floor, button_type)
    [{Node.self(), local} | Enum.map(Node.list(), fn node -> 
      if Map.has_key?(data, node) do
        {node, get_cost(data[node], request_floor, button_type)}
      end
    end) |> Enum.filter(fn x -> x != nil end)]
  end

  def get_all_cost_lists(state, data) do
    button_floor = %{
      :command => state[:config][:bottom_floor]..state[:config][:top_floor],
      :call_up => state[:config][:bottom_floor]..(state[:config][:top_floor] - 1),
      :call_down => (state[:config][:bottom_floor] + 1)..state[:config][:top_floor]
    }
    request_map = %{}

    # TODO: clean up this
    Enum.map(Map.keys(button_floor),
      fn button_type ->
        Enum.map(button_floor[button_type],
          fn floor ->
            # assume the state requests are up to date
            # TODO: look at possiblilty to check data as well
            IO.puts "Checking at #{button_type}, #{floor}"
            IO.inspect(Enum.at(state[button_type], floor))
            if Enum.at(state[button_type], floor) do
              IO.inspect(request_map)
              cost_list = if button_type == :command do
                # commands can't be shared by the elevators
                get_cost_list(state, %{}, floor, button_type)
              else
                get_cost_list(state, data, floor, button_type)
              end
              IO.inspect(request_map)

              {{button_type, floor}, cost_list}
            end
          end)
      end) |> List.flatten() |> Enum.filter(fn x -> x != nil end)
  end

  def get_elevator_node(cost_list) do
    # get first element, Node.self()
    [{min_node, min_cost} | cost_list] = cost_list
    Enum.each(cost_list, fn {node, cost} ->
      cond do
        cost < min_cost ->
          min_cost = cost
          min_node = node
        cost == min_cost ->
          if node < min_node do
            min_cost = cost
            min_node = node
          end
        true ->
          :ok
      end
    end)

    {min_node, min_cost}
  end

  def get_all_request_nodes(request_list) do
    Enum.map(request_list, fn {request_id, cost_list} ->
      {request_id, get_elevator_node(cost_list)}
    end)
  end

  def get_next_request(request_list) do
    # remove other nodes
    this_request_list = request_list |> Enum.filter(fn {_, {node_name, _}} ->
      node_name == Node.self()
    end)

    {request_id, _} = Enum.min_by(request_list, fn {request_id, {node_name, cost}} ->
      cost
    end, fn -> {{}, {}} end) # empty tuple if empty request list

    request_id
  end
  
end
