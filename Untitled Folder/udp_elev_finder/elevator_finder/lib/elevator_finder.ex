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
  @elevName "OurElevator"
  @broadcastWait 10000
  @broadcastIP {255, 255, 255, 255}

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    {:ok, socket} = :gen_udp.open(@finderPort, [:binary, broadcast: true, reuseaddr: true])
    Process.send_after(self(), :broadcast, @broadcastWait)
    {:ok, socket}
  end

  def handle_info(:broadcast, socket) do
    IO.puts("Broadcasting!")
    :gen_udp.send(socket, @broadcastIP, @finderPort, get_identifier())
    Process.send_after(self(), :broadcast, @broadcastWait)
    {:noreply, socket}
  end

  def handle_info({:udp, _port1, other_ip, _port2, msg}, socket) do
    #[name | ip] = String.split(msg, "|")

    {:ok, [ip_dip | _]} = :inet.getif
    t = elem(ip_dip, 0)
    if t == other_ip do
      IO.puts "It's the same!"
    else
      IO.puts "DIFFERENT WOO"
    end

    IO.puts msg

    #IO.puts "Name: #{name}"
    #IO.puts "IP: #{ip}"
    #IO.puts "Other: #{ip_tuple_to_string(other_ip)}"
    IO.puts "\n"
    {:noreply, socket}
  end

  def handle_info(_what, socket) do
    IO.puts "What?"
    {:noreply, socket}
  end

  def get_identifier do
    {:ok, [ip | _]} = :inet.getif
    ip_tuple = elem(ip, 1)
    #this_ip = Tuple.to_list(elem(ip, 1))
    #[_first_dot | without_dot] = :lists.flatmap(fn(element) -> [".", to_string(element)] end, this_ip)
    #ip_string = List.to_string(without_dot)
    ip_string = ip_tuple_to_string(ip_tuple)
    @elevName <> "|" <> ip_string
  end

  def ip_tuple_to_string(ip_tuple) do
    ip_list = Tuple.to_list(ip_tuple)
    [_first_dot | without_dot] = :lists.flatmap(fn(element) -> [".", to_string(element)] end, ip_list)
    List.to_string(without_dot)
  end

  def ip_string_to_tuple(ip_string) do
    String.split(ip_string, ".")
  end

end
