defmodule Thing do

  def start_link(count \\ 0) do
    {:ok, primary_pid} = primary_start_link(count)
    {:ok, backup_pid} = backup_start_link(count)

    {:ok, primary_pid, backup_pid}
  end

  def primary_start_link(count \\ 0) do
    {:ok, primary} = Task.start_link(fn -> primary_loop(count) end)
    Process.register(primary, :primary)
    {:ok, primary}
  end

  def backup_start_link(count \\ 0) do
    {:ok, backup} = Task.start_link(fn -> backup_loop(count) end)
    Process.register(backup, :backup)
    {:ok, backup}
    # start listening for messages from primary.
    # if time out error, set self up as primary and spawn new backup
  end

  def primary_loop(count) do

    receive do
      #{:get_value, from} -> send(from, count)
      :kill_primary ->  Process.unregister(:primary) #Process.exit(Process.whereis(:primary), :kill)
        # simulate death
        # Process.exit(Process.whereis(:primary) , :normal)
    after
      1000 -> # masterhacker, waiting for 1 sec
        if Process.whereis(:primary) != nil do
          send(Process.whereis(:backup), {:count, count}) #:gen_udp.send(primary_socket, {0, 0, 0, 0}, @backup_port, count)

          count = count + 1
          IO.puts("Current count: #{count}")

          primary_loop(count)
        end
    end

  end

  def backup_loop(current) do

    receive do
      {:count, count} ->
        current = count
        backup_loop(current)

    after
      2000 -> reassign_processes(current) # do a bunch of stuff
    end
  end

  def reassign_processes(current_backup_count) do
    IO.puts("Reassigning")
    try do
      Process.unregister(:primary)
      {:ok, :unregistered}
    catch
      _, _ -> {:ok, :already_unregistered} # catch all, all is good
    end

    try do
      Process.unregister(:backup)
      {:ok, :unregistered}
    catch
      _, _ -> {:ok, :already_unregistered} # catch all, all is good
    end

    start_link(current_backup_count)
  end

end

defmodule ThingUDP do
  @primary_port 50000
  @backup_port  55000

  def start_link(count \\ 0) do
    primary_start_link(count)
    backup_start_link(count)

    :ok
  end

  def primary_start_link(count \\ 0) do
    {:ok, primary_socket} = :gen_udp.open(@primary_port)

    {:ok, primary} = Task.start_link(fn -> primary_loop(count, primary_socket) end)
    Process.register(primary, :primary)
  end

  def backup_start_link(count \\ 0) do
    {:ok, backup_socket}  = :gen_udp.open(@backup_port)

    {:ok, backup} = Task.start_link(fn -> backup_loop(count, backup_socket) end)
    Process.register(backup, :backup)

    # start listening for messages from primary.
    # if time out error, set self up as primary and spawn new backup
  end

  def primary_loop(count, primary_socket) do

    receive do
      #{:get_value, from} -> send(from, count)
      :kill_primary ->
        Process.exit(Process.whereis(:primary), :kill)
        #Process.unregister(:primary)
        :gen_udp.close(primary_socket)
        # simulate death
        # Process.exit(Process.whereis(:primary) , :normal)
    after
      1000 ->
        if Process.whereis(:primary) != nil do
          send(Process.whereis(:backup), {:count, count}) #:gen_udp.send(primary_socket, {0, 0, 0, 0}, @backup_port, count)

          count = count + 1
          IO.puts("Current count: #{count}")

          primary_loop(count, primary_socket)
        end
    end

  end

  def backup_loop(current, backup_socket) do

    receive do
      {:count, count} -> current = count
    after
      2000 -> reassign_processes(current, backup_socket) # do a bunch of stuff
    end

    backup_loop(current, backup_socket)
  end

  def reassign_processes(current_backup_count, current_backup_socket) do
    IO.puts("Reassigning")
    try do
      Process.unregister(:primary)
      {:ok, :unregistered}
    catch
      _, _ -> {:ok, :already_unregistered} # catch all, all is good
    end

    try do
      Process.unregister(:backup)
      {:ok, :unregistered}
    catch
      _, _ -> {:ok, :already_unregistered} # catch all, all is good
    end

    :gen_udp.close(current_backup_socket)

    start_link(current_backup_count)
  end

end
