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

    # concat local solution with solution from the data
    [{Node.self(), local} | Enum.map(Node.list(), fn node ->
      if Map.has_key?(data, node) do
        {node, get_cost(data[node], request_floor, button_type)}
      end
    end) |> Enum.filter(fn x -> x != nil end)]
    # filter out nil,
  end

  def get_all_cost_lists(state, data) do
    button_floor = %{
      :command => state[:config][:bottom_floor]..state[:config][:top_floor],
      :call_up => state[:config][:bottom_floor]..(state[:config][:top_floor] - 1),
      :call_down => (state[:config][:bottom_floor] + 1)..state[:config][:top_floor]
    }

    # TODO: clean up this, possibly divide into different parts
    Enum.map(Map.keys(button_floor),
      fn button_type ->
        Enum.map(button_floor[button_type],
          fn floor ->
            local = if Enum.at(state[button_type], floor) do
              {Node.self(), Cost.get_cost(state, floor, button_type)}
            end

            global_list = Enum.map(Node.list(),
            fn node_name ->
              if Enum.at(data[node_name][button_type], floor) do
                {node_name, Cost.get_cost(data[node_name], floor, button_type)}
              end
            end) |> Enum.filter(fn x -> x != nil end)

            command_list = if button_type == :command do
              # for commands, create a request for each elevator where
              # there is a command request
              # TODO: please clean this up...
              data_list = Enum.map(Node.list(),
              fn node_name ->
                if Enum.at(data[node_name][button_type], floor) do
                  {{button_type, floor},
                  [{node_name, Cost.get_cost(data[node_name], floor, button_type)}]}
                end
              end) |> Enum.filter(fn x -> x != nil end)

              if Enum.at(state[button_type], floor) do
                [{{button_type, floor},
                 [{Node.self(), Cost.get_cost(state, floor, button_type)}]}
                | data_list]
              else
                data_list
              end
            end
            # each request_id with all possible "solutions"
            cond do
              button_type == :command                         ->
                command_list
              not Enum.empty?(global_list) and local != nil   ->
                {{button_type, floor}, [local | global_list]}
              Enum.empty?(global_list) and local != nil       ->
                {{button_type, floor}, [local]}
              not Enum.empty?(global_list) and local == nil   ->
                {{button_type, floor}, global_list}
              true ->
                nil
            end
          end)
      end) |> List.flatten() |> Enum.filter(fn x -> x != nil end)
      # flatten and filter result
  end

  def get_elevator_node(cost_list) do
    [{min_node, min_cost} | cost_list] = cost_list

    {min_node, min_cost} = Enum.reduce(cost_list, {min_node, min_cost},
    fn {node, cost}, {min_node, min_cost} ->
      cond do
        cost < min_cost ->
          {node, cost}
        cost == min_cost ->
          if node < min_node do
            {node, cost}
          else
            {min_node, min_cost}
          end
        true ->
          {min_node, min_cost}
      end
    end)

    {min_node, min_cost}
  end

  def get_all_request_nodes(all_cost_lists) do
    Enum.map(all_cost_lists, fn {request_id, cost_list} ->
      {request_id, get_elevator_node(cost_list)}
    end)
  end

  def get_next_request(request_list, node_name) do
    # remove other nodes
    this_request_list = request_list |> Enum.filter(fn {_, {node_name, _}} ->
      node_name == node_name
    end)

    {request_id, _} = Enum.min_by(request_list, fn {request_id, {node_name, cost}} ->
      cost
    end, fn -> {{}, {}} end) # empty tuple if empty request list

    request_id
  end

  def get_all_next_request(request_list) do
    # TODO: something about handling requests at the same floor for different elevators
    # depending on several factors, these could be handled by the same elevator
    # as well as :command cannot be handled by other elevators and
    # must be handled by that elevator.

    # NOTE: this problem might manifest itself earlier in the code
    # TODO: add these special cases here and elsewhere if needed
    # might not be needed as these shouldn't be added to other nodes'
    # requests. needs to be tested for anyways
    Enum.reduce(request_list, %{},
    fn {request_id, {node_name, cost}}, acc ->
      # {button_type, floor} = request_id
      if node_name in [Node.self() | Node.list] do
        if Map.has_key?(acc, node_name) do
          {current_request_id, current_cost} = Map.get(acc, node_name)
          if cost < current_cost do
            Map.put(acc, node_name, {request_id, cost})
          else
            acc
          end
        else
          Map.put(acc, node_name, {request_id, cost})
        end
      else
        acc
      end
    end)
  end

end
