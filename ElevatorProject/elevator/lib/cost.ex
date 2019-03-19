defmodule Cost do

  @floor_penalty 1
  @direction_penalty 1

  def get_cost(state, request_floor, button_type) do
    f_pen = @floor_penalty * abs(state[:floor] - request_floor)
    d_pen = @direction_penalty * case state[:dir] do
      :up   ->
      :down ->
      :stop ->
    end
  end

  def in_direction(dir, button_type, state_floor, request_floor) do
    if request_floor < state_floor and 
  end

end
