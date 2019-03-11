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
  @base_cost 100
  @top_floor 3
  @base_floor 0

  use GenStateMachine

  def start_link([]) do
    SimpleElevator.start_link()
  end

  def start_link() do
    init_request = {false, @base_cost} # request base, initialized as false and base cost
    init_list = List.duplicate(init_request, @top_floor - @base_floor) # request list base
    init_list_command = [init_request | init_list] # command request list
    init_list_call = [:invalid  | init_list] # first element of call down is invalid, last of call up

    state = %{
              :dir => :stop,
              :behaviour => :idle,
              :door => :closed,
              :floor => 0,
              :command => init_list_command,
              :call_up => Enum.reverse(init_list_call), # reversed such that last element is invalid
              :call_down => init_list_call
             }
    data  = %{}

    GenStateMachine.start_link(__MODULE__, {state, data}, [name: __MODULE__])
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

  # door 
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
    IO.puts "Start sharing state..."

    # self-call as well, might be useful in self-checks
    # keep ghost state on local machine of itself as well
    {replies, bad_nodes} = GenServer.multi_call([Node.self() | Node.list()], SimpleElevator, {:sync_state, state}, @sync_timeout)

    IO.puts "Replies"
    IO.inspect(replies)
    IO.puts "Bad nodes"
    IO.inspect(bad_nodes)

    #handle_bad_nodes(bad_nodes, state)

    {:next_state, state, data}
  end

  def handle_bad_nodes(bad_nodes, state) do
    IO.puts "Handling bad nodes"
    # might be "stuck" if nodes are cont. using long time to reply
    # is fine, but might be handled (finite steps)
    # though not needed for this project
    {_replies, bad_nodes} = GenServer.multi_call([Node.self() | Node.list()], SimpleElevator, {:sync_state, state}, @sync_timeout)

    handle_bad_nodes(bad_nodes, state)
  end

  def handle_bad_nodes([], _state) do
    IO.puts "Done with bad nodes"
    :ok
  end

  # sync ghost state from other nodes (or itself)
  def handle_event({:call, from}, {:sync_state, other_state}, state, data) do
    IO.puts "Getting another state..."
    IO.inspect(from)

    {_pid, {_ref, node_name}} = from

    # update and merge ghost state
    # everything "should" be up to date, as we are sending each individual event 
      # TODO IMPLEMENT THIS!
    # merge the requests
    if not Map.has_key?(data, node_name) do
      IO.puts "Ooh first time"
      Map.put(data, node_name, other_state)
    else 
      IO.puts "Merging..."
    end


    {:next_state, state, data, [{:reply, from, :ack}]}
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
