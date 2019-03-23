defmodule ElevatorState do
  @moduledoc """
  Documentation for Elevator.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Elevator.hello()
      :world

  """

  use GenServer

  @type state() :: map()
  @type floor :: integer()

  @sync_timeout 100
  @door_timeout 2000

  def start_link([bottom_floor, top_floor]) do
    GenServer.start_link(__MODULE__, [bottom_floor, top_floor])
  end

  def init([bottom_floor, top_floor]) do
    IO.inspect(__MODULE__, label: "Initializing starting")

    {state, backup} = ElevatorState.initialize_state(bottom_floor, top_floor)
    ElevatorState.initialize_driver(state)

    IO.inspect(__MODULE__, label: "Initializing finished")

    {:ok, {state, backup}}
  end

  @spec initialize_state(floor(), floor()) :: state()
  def initialize_state(bottom_floor, top_floor) do

    list = List.duplicate(false, top_floor - bottom_floor + 1)

    {%{
      :dir => :stop,
      :behaviour => :idle,
      :door => :closed,
      :floor => 0,
      :command => list,
      :call_up => list,
      :call_down => list,
      :config => %{:bottom_floor => bottom_floor, :top_floor => top_floor,
                   :button_floor_range => %{
                     :command => bottom_floor..top_floor,
                     :call_up => bottom_floor..(top_floor - 1),
                     :call_down => (bottom_floor + 1)..top_floor}}
    }, %{}}
  end

  def initialize_driver(state) do
    # button_floor = %{
    #   :command => state[:config][:bottom_floor]..state[:config][:top_floor],
    #   :call_up => state[:config][:bottom_floor]..(state[:config][:top_floor] - 1),
    #   :call_down => (state[:config][:bottom_floor] + 1)..state[:config][:top_floor]
    # }

    Driver.set_motor_direction(Driver, :stop)
    Driver.set_stop_button_light(Driver, :off)
    Driver.set_door_open_light(Driver, :off)

    Enum.each(Map.keys(state[:config][:button_floor_range]), fn button_type ->
      Enum.each(state[:config][:button_floor_range][button_type], fn floor ->
        Driver.set_order_button_light(Driver, button_type, floor, :off)
      end)
    end)

    :ok
  end


  # :get_state
  # useful for getting the state of the local elevator
  def handle_call(:get_state, _from, {state, backup}) do
    {:reply, {Node.self(), state}, {state, backup}}
  end

  # :set_floor
  # useful for changing the floor of the state and the floor indicator of the driver
  def handle_cast({:set_floor, floor}, {state, backup}) do
    GenServer.cast(Driver, {:set_floor_indicator, floor})

    {:noreply, {state |> Map.replace!(:floor, floor), backup}}
  end

  def handle_cast(:share_state, {state, backup}) do
    {_replies, _bad_nodes} = multi_call({:sync_backup, state, Node.self()}, @sync_timeout)
    # TODO: handle bad calls, maybe limit to within the "calling module" timeout?

    {:noreply, {state, backup}}
  end

  def handle_call({:sync_backup, backup_state, node_name}, _from, {state, backup}) do
    {:reply, :ack, {state, backup |> Map.put(node_name, backup_state)}}
  end

  def handle_cast(:get_backup, {state, backup}) do
    {replies, _bad_nodes} = multi_call({:send_backup, Node.self()}, @sync_timeout)
    # TODO: find out if checking for bad nodes is unnecessary

    Enum.reduce(replies |> Enum.filter(fn x -> x != nil end), state,
    fn backup_state, acc ->
      Enum.zip(backup_state[:command], acc[:command]) |>
        Enum.map(fn {e1, e2} -> e1 or e2 end)
    end)

    # TODO: add these to the order module
    replies |> Enum.filter(fn x -> x != nil end) |> Enum.reduce(state, fn element, acc ->
      Map.merge(element, acc, fn key, elem_list, acc_list ->
        if key in [:command, :call_up, :call_down] do
          Enum.zip(elem_list, acc_list) |>
            Enum.map(fn {elem_bool, acc_bool} -> elem_bool or acc_bool end)
        else
          acc_list
        end
      end)
    end)

    {:noreply, {state, backup}}
  end

  def handle_call({:send_backup, node_name}, _from, {state, backup}) do
    {:reply, Map.get(backup, node_name, nil), {state, backup}}
  end


  # :send_request
  # useful for sending newly aquired requests from the local to the global elevators
  def handle_cast({:send_request, floor, button_type}, {state, backup}) do
    # TODO: simplify the multi_calls, use module defined function instead
    state = if button_type != :command do
      # tell everyone to change their state
      {replies, bad_nodes} = GenServer.multi_call(Node.list(), ElevatorState, {:get_request, floor, button_type}, @sync_timeout)
      if not :nack in replies and Enum.empty?(bad_nodes) do
        # tell everyone to light up the order button
        {replies, bad_nodes} = GenServer.multi_call(Node.list(), ElevatorState, {:set_order_button_light, button_type, floor, :on}, @sync_timeout)
        if Enum.empty?(bad_nodes) and not :nack in replies do
          # only accept a request locally if it is received on the other nodes
          # NOTE: stricter than previous implementation
          {_, state} = Map.get_and_update(state, button_type,
            fn request_list ->
              {request_list, List.replace_at(request_list, floor, true)}
            end)
          state
        else
          # if not received at the other nodes for whatever reason:
          # sending a counter message to clear the resulting change from the
          # other nodes.
          # TODO: make this more robust
          {_replies, _bad_nodes} = GenServer.multi_call(Node.list(), ElevatorState, {:clear_request, floor, button_type}, @sync_timeout)
          state
        end
      else
        state
      end
    else
      state
    end

    {:noreply, {state, backup}}
  end

  def handle_call({:get_request, floor, button_type}, _from, {state, backup}) do
    # change the state at button_type and floor to true
    {_, state} = Map.get_and_update(state, button_type,
      fn request_list ->
        {request_list, List.replace_at(request_list, floor, true) }
      end)
    # GenServer.cast(Driver, {:set_order_button_light, button_type, floor, button_state})
    # Driver.set_order_button_light(Driver, button_type, floor, :off)

    {:reply, :ack, state}
  end

  def handle_call({:set_order_button_light, button_type, floor}, _from, {state, backup}) do
    answer = if state[button_type] |> Enum.at(floor) do
      # GenServer.cast(Driver, {:set_order_button_light, button_type, floor, :on})
      Driver.set_order_button_light(Driver, button_type, floor, :on)
      :ack
    else
      # shouldn't happen, but is nice to have this case for extra reassurance
      # TODO: handle this in :send_request
      :nack
    end
    # GenServer.cast(Driver, {:set_order_button_light, button_type, floor, button_state})

    {:reply, answer, {state, backup}}
  end

  def handle_call({:clear_request, floor, button_type}, _from, {state, backup}) do
    # NOTE: this might end up clearing existing requests!!
    # TODO: ask the Order module if the request is accepted as an order
    {_, state} = Map.get_and_update(state, button_type,
      fn request_list ->
        {request_list, List.replace_at(request_list, floor, false) }
      end)

    # GenServer.cast(Driver, {:set_order_button_light, button_type, floor, :off})
    Driver.set_order_button_light(Driver, button_type, floor, :off)

    {:reply, :ack, {state, backup}}
  end

  def handle_call({:clear_floor, floor}, _from, {state, backup}) do

    # TODO: also clear from Order module
    state = state |>
            set_button(:call_up, floor, :off) |>
            set_button(:call_down, floor, :off)

    {:reply, :ack, {state, backup}}
  end



  # door things

  # open door
  def handle_cast({:open_door, floor}, {state, backup}) do

    Driver.set_motor_direction(Driver, :stop)
    Driver.set_door_open_light(Driver, :on)

    state = state |>  Map.replace!(:door, :open) |>
                      Map.replace!(:behaviour, :open_door)

    # {_, state} = Map.get_and_update(state, :command, fn cmd_list -> {cmd_list, cmd_list |> List.replace_at(floor, false)} end)
    state = state |>
            set_button(:command, floor, :off) |>
            set_button(:call_up, floor, :off) |>
            set_button(:call_down, floor, :off)

    # don't care if this is not completed, as it then would be handled
    # by that node locally
    {_, _} = multi_call({:clear_floor, floor}, @sync_timeout)

    # sends after approximatly door timeout milliseconds
    Process.send_after(self(), :close_door, @door_timeout)

    {:noreply, {state, backup}}
  end

  # close door, only called by open door
  def handle_info(:close_door, {state, backup}) do
    state = state |>
            Map.replace!(:door, :closed) |>
            Map.replace!(:behaviour, if state[:dir] == :stop do :idle else :moving end)

    Driver.set_door_open_light(Driver, :off)
    Driver.set_motor_direction(Driver, state[:dir]) # continue on path

    {:noreply, {state, backup}}
  end







  # wrapper, simplify GenServer.multi_call
  defp multi_call(args, timeout) do
    GenServer.multi_call(Node.list(), ElevatorState, args, timeout)
  end

  # recursively call multi_call until all bad nodes are handled
  # should only be called in situations where it is possible to
  # terminate the recursion...
  defp handle_bad_nodes(bad_nodes, message) do
    handle_bad_nodes(bad_nodes, message, @sync_timeout)
  end

  defp handle_bad_nodes(bad_nodes, message, timeout) when length(bad_nodes) != 0 do
    # TODO: check if IO makes this function too slow
    IO.inspect(bad_nodes, label: "Handling these bad nodes")
    IO.inspect(message, label: "Handling calling this message")
    # find bad nodes still alive, union of Node.list() and bad_nodes
    bad_nodes = Node.list() -- (Node.list() -- bad_nodes)
    # might be "stuck" if nodes are cont. using long time to reply
    # is fine, but might be handled (finite steps)
    # though not needed for this project
    {replies, bad_nodes} = multi_call(message, timeout)

    replies ++ handle_bad_nodes(bad_nodes, message)
  end

  # end state for
  defp handle_bad_nodes([], _message, _timeout) do
    # IO.puts "Done with bad nodes"
    []
  end

  defp set_button(state, button_type, floor, value) do
    Driver.set_order_button_light(Driver, button_type, floor, value)

    {_, state} = Map.get_and_update(state, button_type,
    fn cmd_list ->
      {cmd_list, cmd_list |> List.replace_at(floor, value)}
    end)

    state
  end

end
