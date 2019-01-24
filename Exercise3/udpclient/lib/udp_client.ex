defmodule UDPClient do
  @moduledoc """
  Documentation for UDPClient.
  """

  @doc """
  Hello world.

  ## Examples

      iex> UDPClient.hello()
      :world

  """
  
  def start() do
    IO.puts "Opening"
    {:ok, socket} = :gen_udp.open(0, [{:broadcast, true}])

    handle(socket)
  end

  def read_ip() do
    IO.puts "Getting the IP..."
    {:ok, socket} = :gen_udp.open(30000)

    read(socket)
  end

  def read(socket) do
    IO.puts "Reading socket"
    :gen_udp.recv(socket, 1024)

    read(socket)
  end

  def nice({:ok, {adr, _port, _packet}}) do
    IO.puts "#{adr}"
  end

  def nice({_error, reason}) do
    IO.puts "ERROR #{reason}"
  end

  def handle(server) do
    {:ok, {adr, _port, _packet}} = :gen_udp.recv(server, 1024)
    {ip0, ip1, ip2, ip3} = adr
    IO.puts "#{ip0} #{ip1} #{ip2} #{ip3}\n"

    handle(server)
  end

  def send_data(data) do
    server = Socket.UDP.open!
    Socket.Datagram.send!(server, data, {{255, 255, 255, 255}, 20})
  end


end
