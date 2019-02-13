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
  use Agent

  def start do
    Agent.start_link(fn -> %{
      :floor => 0, 
      :dir => :stop, 
      :behaviour => :idle, 
      :requests => %{
        :command => [false, false, false, false],
        :call_up => [false, false, false, :invalid],
        :call_down => [:invalid, false, false, false],
        #:call => %{
        #  :up => [false, false, false, :invalid],
        #  :down => [:invalid, false, false, false]
        #}
      },
      :config => %{
        :clear_request_variant => :clear_all, 
        :open_door => 10
      }
    } end)
  end

  def get_floor(pid) do
    Agent.get(pid, &Map.get(&1, :floor))
  end

  def set_floor(pid, value) do
    Agent.update(pid, &Map.put(&1, :floor, value))
  end

end
