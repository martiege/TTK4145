defmodule Counter do
  use Agent

  @primary_port 50000
  @backup_port  55000

  def start_link(count) do
    {:ok, primary_socket} = :gen_udp.open(@primary_port)
    {:ok, backup_socket}  = :gen_udp.open(@backup_port)

    Agent.start_link(fn -> {count, primary_socket} end, name: :primary)
    Agent.start_link(fn -> {count, backup_socket} end,  name: :backup)
  end

  def increment() do
    {count, primary_socket} = get_primary_state() #Agent.get(:primary, & &1)
    Agent.update(:primary, fn _ -> {(count + 1), primary_socket} end)
    IO.puts("Counting: #{count + 1}")
    :gen_udp.send(primary_socket, {0, 0, 0, 0}, @backup_port, count + 1)
  end

  def get_primary_state() do
    Agent.get(:primary, & &1)
  end

  def get_backup_state() do
    Agent.get(:backup, & &1)
  end

end

defmodule Counting do
  @primary_port 50000
  @backup_port  55000

  def start_link do
    {:ok, primary_socket} = :gen_udp.open(@primary_port)
    {:ok, backup_socket}  = :gen_udp.open(@backup_port)

    {:ok, primary} = Task.start_link(fn ->
      counter_function({0, primary_socket, :primary})
    end)
    Process.register(primary, :primary)

    {:ok, backup} = Task.start_link(fn ->
      counter_function({0, backup_socket, :backup})
    end)
    Process.register(backup, :backup)

    # return value
    {:ok, :primary, :backup}
  end

  def counter_function({count, socket, state}) when state === :primary do
    receive do
      {:get, caller} ->
        send(caller, count)
        counter_function({count, socket})
      :iterate ->
        IO.puts("Iteration: #{count + 1}")
        counter_function({count + 1, socket})
    end
  end

  def counter_function({counter, socket, state}) when state === :backup do
    receive do

    end
  end

end

defmodule C do
  @primary_port 50000
  @backup_port  55000


  def primary_start_link do
    {:ok, primary_socket} = :gen_udp.open(@primary_port)

    #{:ok, primary} = Task.start_link(fn ->
      #counter_function({0, primary_socket, :primary})
    #end)

    #Process.register(primary, :primary)

    # start iterating

    {:ok, primary} = Task.start_link(fn -> primary_loop(0, primary_socket) end)
    Process.register(primary, :primary)
  end

  def primary_loop(count, primary_socket) do
    count = count + 1
    #IO.puts("Iteration: #{count}")
    #Process.sleep(1000)
    start_time = Time.utc_now()
    primary_wait_loop(start_time, Time.diff(start_time, Time.utc_now(), :millisecond), count)

    :gen_udp.send(primary_socket, {0, 0, 0, 0}, @backup_port, count)
    # send to the backup through udp

    primary_loop(count, primary_socket)
  end

  def primary_wait_loop(start_time, diff_time_ms, count) when diff_time_ms <= 1000 do
    receive do
      :print_iteration ->
        IO.puts("Current iteration: #{count}")
        primary_wait_loop(start_time, Time.diff(Time.utc_now(), start_time, :millisecond), count)
    end

    primary_wait_loop(start_time, Time.diff(Time.utc_now(), start_time, :millisecond), count)
  end

  #def primary_wait_loop(_, _, _) do
  #  :ok
  #end

  def backup_start_link do
    {:ok, backup_socket}  = :gen_udp.open(@backup_port)

    #{:ok, backup} = Task.start_link(fn ->
      #counter_function({0, backup_socket, :backup})
    #end)

    #Process.register(backup, :backup)

    # start listening for messages from primary.
    # if time out error, set self up as primary and spawn new backup
  end

  def backup_loop

end


defmodule SimpleSupervisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      %{:id       => :primary,
        :start    => {Simple, :start_link, [0, :primary]},
        :restart  => :transient,
        :shutdown => :brutal_kill,
        :type     => :worker},

      %{:id       => :backup,
        :start    => {Simple, :start_link, [0, :backup]},
        :restart  => :transient,
        :shutdown => :brutal_kill,
        :type     => :worker}
    ]


    Supervisor.init(children, strategy: :one_for_one)
  end

  def loop do

    if Process.alive?( Process.whereis(:primary) )  do
      # send message
      Simple.increment(:primary)
      Simple.set(:backup, Simple.get(:primary))

    else
      # restart processes

    end

  end

end


defmodule SimpleCounter do
  use GenServer

  def start_link(count, process) do
    GenServer.start_link(__MODULE__, count, name: process)
  end

  def increment(pid) do
    GenServer.cast(pid, :increment)
  end

  def kill_counter(pid) do
    send(pid, :kill_me)
  end

  def get(pid) do
    GenServer.call(pid, :get)
  end

  def set(pid, value) do
    GenServer.cast(pid, {:set, value})
  end

  # server
  def init(count) do
    {:ok, count}
  end

  def handle_cast(:increment, count) do
    {:noreply, count + 1}
  end

  def handle_cast({:set, value}, _count) do
    {:noreply, value}
  end

  def handle_call(:get, _from, count) do
    {:reply, count, count}
  end

  def handle_info(:kill_me, count) do
    {:stop, :normal, count}
  end

  def terminate(_, count) do
    IO.inspect("Dead... Count: #{count}")
  end


end
