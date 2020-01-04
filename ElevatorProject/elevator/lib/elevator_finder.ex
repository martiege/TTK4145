defmodule ElevatorFinder do
  @moduledoc """
  The ElevatorFinder module implements 
	broadcasting and receiving UDP messages 
	to connect the elevator nodes currently 
	alive. 
	
  The module will also set up this node as
	a distributing node, given a node name. 
	
  The module does not receive any messages 
	other than selfcalls or broadcasts from
	other ElevatorFinder modules on other 
	nodes. 

  The module will send a call to the
	ElevatorState periodically to share it's
	state with the other currently connected 
	nodes. 
	
  Once the module has found another node, 
	it will send a cast to the ElevatorState
	to ask the new node if it has a backup 
	for this node. If the backup has any 
	orders not found on this node, they will
	be added to this node's orders. 
	
  ## Starting the module: 
  
	iex> ElevatorFinder.start_link(node_name)
	
  
  """

  @finderPort 50000
  @elevCookie :elev
  @broadcastWait 1000
  @shareStateWait 100
  @broadcastIP {255, 255, 255, 255}

  use GenServer

  def start_link(node_name) do
    GenServer.start_link(__MODULE__, node_name)
  end

  # wrapper for supervisor
  def init([node_name]) do
      init(node_name)
  end

  def init(node_name) do
    IO.inspect(__MODULE__, label: "Initializing starting")

    node_atom = String.to_atom(node_name <> "@" <> ElevatorFinder.get_ip_string())
    Node.start(node_atom, :longnames, 15000)
    Node.set_cookie(node_atom, @elevCookie)

    {:ok, socket} = :gen_udp.open(@finderPort, [:binary, broadcast: true, reuseaddr: true])
    Process.send_after(self(), :broadcast, @broadcastWait)

    IO.inspect(__MODULE__, label: "Initializing finished")
    {:ok, {socket, node_name}}
  end

  def handle_info(:broadcast, {socket, node_name}) do
    node_id = node_name <> "@" <> ElevatorFinder.get_ip_string()

    :gen_udp.send(socket, @broadcastIP, @finderPort, node_id)

    GenServer.call(ElevatorState, :share_state)

    Process.send_after(self(), :broadcast, @broadcastWait)

    {:noreply, {socket, node_name}}
  end

  def handle_info({:udp, _port1, _other_ip, _port2, msg}, {socket, node_name}) do
    node_atom = String.to_atom(msg)
	
    pre_connect_length = length(Node.list())
    Node.connect(node_atom)
    post_connect_length = length(Node.list())

    # on new node-network found
    if (post_connect_length - pre_connect_length) > 0 do
      IO.puts "Found new node: #{msg}"
      # sync
      GenServer.cast(ElevatorState, :get_backup)
    end

    {:noreply, {socket, node_name}}
  end

  def handle_info(_what, {socket, node_name}) do
    {:noreply, {socket, node_name}}
  end

  def terminate(_reason, {socket, node_name}) do
    :gen_udp.close(socket)
  end

  def get_ip_tuple() do
    {:ok, [ip | _]} = :inet.getif()
    elem(ip, 0) 
  end

  def get_ip_string() do
    ip_tuple = get_ip_tuple()
    ip_tuple_to_string(ip_tuple)
  end


  defp ip_tuple_to_string(ip_tuple) do
    ip_list = Tuple.to_list(ip_tuple)
    [_first_dot | without_dot] = :lists.flatmap(
      fn(element) ->
        [".", to_string(element)] #String.pad_leading(to_string(element), 3, "0")]
      end, ip_list)
    List.to_string(without_dot)
  end

  defp ip_string_to_tuple(ip_string) do
    String.split(ip_string, ".")
  end

end
