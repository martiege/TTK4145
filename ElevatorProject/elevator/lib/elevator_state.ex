defmodule ElevatorState do
  use GenServer

  @type state() :: map()
  @type floor :: integer()

  @sync_timeout 100
  @door_timeout 2000

  def start_link(bottom_floor, top_floor) do
    GenServer.start_link(__MODULE__, [bottom_floor, top_floor], [name: __MODULE__])
  end

  def init([bottom_floor, top_floor]) do
    IO.inspect(__MODULE__, label: "Initializing starting")

    {state, backup} = ElevatorState.initialize_state(bottom_floor, top_floor)
    current_floor = ElevatorState.initialize_driver(state)
    state = Map.put(state, :floor, current_floor)

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
    Driver.set_motor_direction(Driver, :stop)
    Driver.set_stop_button_light(Driver, :off)
    Driver.set_door_open_light(Driver, :off)

    Enum.each(Map.keys(state[:config][:button_floor_range]), fn button_type ->
      Enum.each(state[:config][:button_floor_range][button_type], fn floor ->
        Driver.set_order_button_light(Driver, button_type, floor, :off)
      end)
    end)

    initialize_floor(Driver.get_floor_sensor_state(Driver))
  end

  def initialize_floor(:between_floors) do
    Driver.set_motor_direction(Driver, :down)
    initialize_floor(Driver.get_floor_sensor_state(Driver))
  end

  def initialize_floor(floor) do
    Driver.set_motor_direction(Driver, :stop)
    Driver.set_floor_indicator(Driver, floor)
    floor
  end

  # does not handle open door
  def handle_cast({:set_dir, dir}, {state, backup}) do
    state = Map.put(state, :dir, dir)
    Driver.set_motor_direction(Driver, dir)
    state = case dir do
      :stop ->
        Map.put(state, :behaviour, :idle)
      _ ->
        Map.put(state, :behaviour, :moving)
    end

    {:noreply, {state, backup}}
  end

  # :set_floor
  # useful for changing the floor of the state and the floor indicator of the driver
  def handle_cast({:set_floor, floor}, {state, backup}) do
    GenServer.cast(Driver, {:set_floor_indicator, floor})

    {:noreply, {state |> Map.replace!(:floor, floor), backup}}
  end

  def handle_cast(:get_backup, {state, backup}) do
    {replies, bad_nodes} = multi_call({:send_backup, Node.self()}, @sync_timeout)
    Task.start_link(fn ->
      handle_bad_nodes(bad_nodes, {:send_backup, Node.self()},
      @sync_timeout, :backup_returned, replies)
    end)

    {:noreply, {state, backup}}
  end

  # :send_request
  # useful for sending newly aquired requests from the local to the global elevators
  def handle_cast({:send_request, floor, button_type}, {state, backup}) do
    # TODO: simplify the multi_calls, use module defined function instead
    state = if button_type != :command do
      # tell everyone to change their state
      {replies, bad_nodes} = GenServer.multi_call(Node.list(), ElevatorState, {:get_request, floor, button_type}, @sync_timeout)
      if not (:nack in replies) and Enum.empty?(bad_nodes) do
        # tell everyone to light up the order button
        {replies, bad_nodes} = GenServer.multi_call(Node.list(), ElevatorState, {:set_order_button_light, button_type, floor}, @sync_timeout)
        if not (:nack in replies) and Enum.empty?(bad_nodes) do
          # only accept a request locally if it is received on the other nodes
          # NOTE: stricter than previous implementation
          Driver.set_order_button_light(Driver, button_type, floor, :on)
          {_, state} = Map.get_and_update(state, button_type,
            fn request_list ->
              {request_list, List.replace_at(request_list, floor, true)}
            end)
          state
        else
          # if not received at the other nodes for whatever reason:
          # sending a counter message to clear the resulting change from the
          # other nodes.
          {replies, bad_nodes} = GenServer.multi_call(Node.list(), ElevatorState,
            {:clear_request, floor, button_type}, @sync_timeout)
          Task.start_link(fn ->
            handle_bad_nodes(bad_nodes, {:clear_request, floor, button_type},
            @sync_timeout, :all_requests_cleared, replies)
          end)
          # _replies = replies ++ handle_bad_nodes(bad_nodes, {:clear_request, floor, button_type}, @sync_timeout)

          state
        end
      else
        state
      end
    else
      Driver.set_order_button_light(Driver, button_type, floor, :on)
      {_, state} = Map.get_and_update(state, button_type,
        fn request_list ->
          {request_list, List.replace_at(request_list, floor, true)}
        end)
      state
    end

    {:noreply, {state, backup}}
  end

  # door things
  # open door
  def handle_cast({:open_door, floor}, {state, backup}) do
    state = if (state[:behaviour] != :open_door) do
      IO.puts "Opening door"
      Driver.set_motor_direction(Driver, :stop)
      Driver.set_door_open_light(Driver, :on)

      state = state |>  Map.replace!(:door, :open) |>
                        Map.replace!(:behaviour, :open_door)

      state = case state[:dir] do
        :up   ->
          state |> set_button(:call_up, floor, false)
        :down ->
          state |> set_button(:call_down, floor, false)
        :stop ->
          state |>
            set_button(:call_up, floor, false) |>
            set_button(:call_down, floor, false)
      end |> set_button(:command, floor, false)

      # don't care if this is not completed, as it then would be handled
      # by that node locally
      {_, _} = multi_call({:clear_floor, floor}, @sync_timeout)

      # sends after approximatly door timeout milliseconds
      Process.send_after(self(), :close_door, @door_timeout)

      state
    else
      state
    end

    {:noreply, {state, backup}}
  end

  def handle_cast({:backup_returned, replies}, {state, backup}) do
    state = replies |> Enum.filter(fn {_node_name, x} -> x != nil end) |> Enum.reduce(state,
    fn {_node_name, backup_state}, acc ->
      new_commands = Enum.zip(backup_state[:command], acc[:command]) |>
        Enum.map(fn {e1, e2} ->
          e1 or e2
        end)
      Enum.with_index(new_commands) |> Enum.each(fn {val, index} ->
        if val do
          Driver.set_order_button_light(Driver, :command, index, :on)
        end
      end)
      Map.put(acc, :command, new_commands)
    end)

    {:noreply, {state, backup}}
  end

  def handle_cast({:all_requests_cleared, _replies}, {state, backup}) do
    {:noreply, {state, backup}}
  end

  # close door, only called by open door
  def handle_info(:close_door, {state, backup}) do
    IO.puts "Closing door"
    state = state |>
            Map.replace!(:door, :closed) |>
            Map.replace!(:behaviour, if state[:dir] == :stop do :idle else :moving end)

    Driver.set_door_open_light(Driver, :off)
    state = cond do
      state[:dir] == :up and state[:floor] == state[:config][:top_floor] or
      state[:dir] == :down and state[:floor] == state[:config][:bottom_floor] ->
        Driver.set_motor_direction(Driver, :stop)
        state |> Map.put(:dir, :stop) |> Map.put(:behaviour, :idle)
      true ->
        Driver.set_motor_direction(Driver, state[:dir]) # continue on path
        state
    end

    {:noreply, {state, backup}}
  end

  # :get_state
  # useful for getting the state of the local elevator
  def handle_call(:get_state, _from, {state, backup}) do
    {:reply, state, {state, backup}}
  end

  def handel_call(:get_backup, _from, {state, backup}) do
    {:reply, backup, {state, backup}}
  end

  def handle_call(:get_floor, _from, {state, backup}) do
    {:reply, state[:floor], {state, backup}}
  end

  def handle_call(:get_behaviour, _from, {state, backup}) do
    {:reply, state[:behaviour], {state, backup}}
  end

  def handle_call({:should_stop, floor}, _from, {state, backup}) do
    global_stop = case state[:dir] do
      :up   ->
        Enum.at(state[:call_up], floor)
      :down ->
        Enum.at(state[:call_down], floor)
      :stop ->
        Enum.at(state[:call_up], floor) or Enum.at(state[:call_down], floor)
      what  ->
        IO.inspect(what, label: "Something happened in should_stop")
        false
    end

    local_stop = Enum.at(state[:command], floor)
    {:reply, global_stop or local_stop, {state, backup}}
  end

  def handle_call({:sync_backup, backup_state, node_name}, _from, {state, backup}) do
    {:reply, :ack, {state, backup |> Map.put(node_name, backup_state)}}
  end

  def handle_call({:send_backup, node_name}, _from, {state, backup}) do
    {:reply, Map.get(backup, node_name, nil), {state, backup}}
  end

  def handle_call(:share_state, _from, {state, backup}) do
    {_replies, _bad_nodes} = multi_call({:sync_backup, state, Node.self()}, @sync_timeout)

    {:reply, :ack, {state, backup}}
  end

  def handle_call({:get_request, floor, button_type}, _from, {state, backup}) do
    # change the state at button_type and floor to true
    {_, state} = Map.get_and_update(state, button_type,
      fn request_list ->
        {request_list, List.replace_at(request_list, floor, true) }
      end)

    {:reply, :ack, {state, backup}}
  end

  def handle_call({:remove_request, floor, button_type}, _from, {state, backup}) do
    # change the state at button_type and floor to true
    {_, state} = Map.get_and_update(state, button_type,
      fn request_list ->
        {request_list, List.replace_at(request_list, floor, false) }
      end)
    {:reply, :ack, {state, backup}}
  end

  def handle_call({:set_order_button_light, button_type, floor}, _from, {state, backup}) do
    answer = if state[button_type] |> Enum.at(floor) do
      # GenServer.cast(Driver, {:set_order_button_light, button_type, floor, :on})
      Driver.set_order_button_light(Driver, button_type, floor, :on)
      :ack
    else
      :nack
    end

    {:reply, answer, {state, backup}}
  end

  def handle_call({:clear_request, floor, button_type}, _from, {state, backup}) do
    {_, state} = Map.get_and_update(state, button_type,
      fn request_list ->
        {request_list, List.replace_at(request_list, floor, false) }
      end)

    Driver.set_order_button_light(Driver, button_type, floor, :off)

    {:reply, :ack, {state, backup}}
  end

  def handle_call({:clear_floor, floor}, _from, {state, backup}) do
    state = state |>
            set_button(:call_up, floor, false) |>
            set_button(:call_down, floor, false)

    {:reply, :ack, {state, backup}}
  end

  # wrapper, simplify GenServer.multi_call
  defp multi_call(args, timeout) do
    GenServer.multi_call(Node.list(), ElevatorState, args, timeout)
  end

  # recursively call multi_call until all bad nodes are handled
  # should only be called in situations where it is possible to
  # terminate the recursion...
  def handle_bad_nodes(bad_nodes, message, timeout, answer_message, original_replies) do
    replies = ElevatorState.handle_bad_nodes(bad_nodes, message, timeout)

    GenServer.cast(ElevatorState, {answer_message, original_replies ++ replies})
  end

  def handle_bad_nodes(bad_nodes, message, timeout) when length(bad_nodes) != 0 do
    # find bad nodes still alive, union of Node.list() and bad_nodes
    bad_nodes = Node.list() -- (Node.list() -- bad_nodes)
    {replies, bad_nodes} = GenServer.multi_call(bad_nodes, ElevatorState, message, timeout)

    replies ++ ElevatorState.handle_bad_nodes(bad_nodes, message, timeout)
  end

  # end state for
  def handle_bad_nodes([], _message, _timeout) do
    # IO.puts "Done with bad nodes"
    []
  end

  defp set_button(state, button_type, floor, value) do
    case value do
      true ->
        Driver.set_order_button_light(Driver, button_type, floor, :on)
      false ->
        Driver.set_order_button_light(Driver, button_type, floor, :off)
      _ ->
        IO.inspect(value, label: "set button")
        Driver.set_order_button_light(Driver, button_type, floor, :off)
    end


    {_, state} = Map.get_and_update(state, button_type,
    fn cmd_list ->
      {cmd_list, cmd_list |> List.replace_at(floor, value)}
    end)

    state
  end

end
