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

  use GenStateMachine

  def start_link do
    state = %{:dir => :stop, :behaviour => :idle, :door => :closed}
    data  = %{:floor => 0,
              :requests => %{ :command => [false, false, false, false],
                              :call_up => [false, false, false, :invalid],
                              :call_down => [:invalid, false, false, false] } }

    GenStateMachine.start_link(__MODULE__, {state, data}, [name: __MODULE__])
  end

  # Cast functions

  def handle_event(:cast, {:set_floor, floor}, state, data) do
    data = Map.replace!(data, :floor, floor)
    {:next_state, state, data}
  end

  def handle_event(:cast, {:set_command, floor, new_state}, state, data) do
    # TODO: simplify
    data = Map.replace!(data, :requests, Map.replace!(data[:requests], :command, List.replace_at(data[:requests][:command], floor, new_state)))
    {:next_state, state, data}
  end

  def handle_event(:cast, {:set_call_up, floor, new_state}, state, data) do
    data = Map.replace!(data, :requests, Map.replace!(data[:requests], :call_up, List.replace_at(data[:requests][:call_up], floor, new_state)))
    {:next_state, state, data}
  end

  def handle_event(:cast, {:set_call_down, floor, new_state}, state, data) do
    data = Map.replace!(data, :requests, Map.replace!(data[:requests], :call_down, List.replace_at(data[:requests][:call_down], floor, new_state)))
    {:next_state, state, data}
  end

  def handle_event(:cast, {:set_dir, dir}, state, data) do
    state = Map.replace!(state, :dir, dir)
    {:next_state, state, data}
  end

  def handle_event(:cast, {:set_behaviour, behaviour}, state, data) do
    state = Map.replace!(state, :behaviour, behaviour)
    {:next_state, state, data}
  end

  def handle_event(:cast, {:set_door, door_state}, state, data) do
    state = Map.replace!(state, :door, door_state)
    {:next_state, state, data}
  end

  # Call functions

  def handle_event({:call, from}, :get_floor, state, data) do
    {:next_state, state, data, [{:reply, from, data[:floor]}]}
  end

  def handle_event({:call, from}, {:get_command, floor}, state, data) do
    {:next_state, state, data, [{:reply, from, Enum.at(data[:requests][:command], floor)}]}
  end

  def handle_event({:call, from}, {:get_call_up, floor}, state, data) do
    {:next_state, state, data, [{:reply, from, Enum.at(data[:requests][:call_up], floor)}]}
  end

  def handle_event({:call, from}, {:get_call_down, floor}, state, data) do
    {:next_state, state, data, [{:reply, from, Enum.at(data[:requests][:call_down], floor)}]}
  end

  def handle_event({:call, from}, :get_dir, state, data) do
    {:next_state, state, data, [{:reply, from, state[:dir]}]} 
  end

  def handle_event({:call, from}, :get_behaviour, state, data) do
    {:next_state, state, data, [{:reply, from, state[:behaviour]}]} 
  end

  def handle_event({:call, from}, :get_door, state, data) do
    {:next_state, state, data, [{:reply, from, state[:door]}]} 
  end
 

  # use Agent

  # def start do
  #   Agent.start_link(fn -> %{
  #     :floor => 0,
  #     :dir => :stop,
  #     :behaviour => :idle,
  #     :requests => %{
  #       :command => [false, false, false, false],
  #       :call_up => [false, false, false, :invalid],
  #       :call_down => [:invalid, false, false, false],
  #       #:call => %{
  #       #  :up => [false, false, false, :invalid],
  #       #  :down => [:invalid, false, false, false]
  #       #}
  #     },
  #     :config => %{
  #       :clear_request_variant => :clear_all,
  #       :open_door => 10
  #     }
  #   } end)
  # end

  # def get_floor(pid) do
  #   Agent.get(pid, &Map.get(&1, :floor))
  # end

  # def set_floor(pid, value) do
  #   Agent.update(pid, &Map.put(&1, :floor, value))
  # end

  #defstruct
    #floor: 0,
    #dir: :stop,
    #behaviour: :idle,
    #requests: %{
      #command: [false, false, false, false],
      #call_up: [false, false, false, :invalid],
      #call_down: [:invalid, false, false, false],
      #:call => %{
      #  :up => [false, false, false, :invalid],
      #  :down => [:invalid, false, false, false]
      #}
    #},
    #config: %{
      #clear_request_variant: :clear_all,
      #open_door: 10
    #}

end
