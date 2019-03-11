defmodule ElevatorFinder do
  @moduledoc """
  Documentation for ElevatorFinder.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ElevatorFinder.hello()
      :world

  """

  @finderPort 50000
  #@elevName "" Ctesibius, Vitruvius
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
    node_atom = String.to_atom(node_name <> "@" <> ElevatorFinder.get_ip_string())
    Node.start(node_atom, :longnames, 15000)
    Node.set_cookie(node_atom, @elevCookie)

    {:ok, socket} = :gen_udp.open(@finderPort, [:binary, broadcast: true, reuseaddr: true])
    Process.send_after(self(), :broadcast, @broadcastWait)

    {:ok, {socket, node_name}}
  end

  def handle_info(:broadcast, {socket, node_name}) do
    #IO.puts("\nBroadcasting!")

    node_id = node_name <> "@" <> get_ip_string()
    :gen_udp.send(socket, @broadcastIP, @finderPort, node_id)
    Process.send_after(self(), :broadcast, @broadcastWait)

    {:noreply, {socket, node_name}}
  end

  def handle_info({:udp, _port1, _other_ip, _port2, msg}, {socket, node_name}) do

    node_atom = String.to_atom(msg)
    pre_connect_length = length(Node.list())
    Node.connect(node_atom)
    post_connect_length = length(Node.list())

    if (post_connect_length - pre_connect_length) != 0 do
      IO.puts "Found new node: #{msg}"
      # sync
      handle_share_state()
    end

    {:noreply, {socket, node_name}}
  end

  def handle_info(_what, {socket, node_name}) do
    {:noreply, {socket, node_name}}
  end

  def terminate(_reason, {socket, _node_name}) do
    :gen_udp.close(socket)
  end

  def handle_share_state do
    GenServer.call(SimpleElevator, :share_state)
  end

  def get_ip_tuple() do
    {:ok, [ip | _]} = :inet.getif()
    ip_tuple = elem(ip, 0) # uncertain about the element nr., this seems to work
    ip_tuple
  end

  def get_ip_string() do
    ip_tuple = get_ip_tuple()
    ip_string = ip_tuple_to_string(ip_tuple)
    #@elevName <> "@" <> ip_string
    ip_string
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
