defmodule Cost do

  @floor_penalty 1
  @direction_penalty 1

  def get_cost(state, request_floor, button_type) do
    f_pen = @floor_penalty * abs(state[:floor] - request_floor)
    # TODO: consider get_direction :stop, state[:dir] not?
    d_pen = @direction_penalty * cond do
      state[:dir] == get_direction(state_floor, request_floor) ->
        0
      state[:dir] == :stop -> # maybe
        0
      state[:dir] != get_direction(state_floor, request_floor) ->
        1
    end
  end

  def get_direction(state_floor, request_floor) do
    cond do
      state_floor < request_floor   -> :up
      state_floor == request_floor  -> :stop
      state_floor > request_floor   -> :down
    end
  end

end
