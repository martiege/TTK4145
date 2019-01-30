defmodule UDPClient do
  @moduledoc """
  Documentation for UDPClient.
  """

  @doc """
  Hello world.

  ## Examples

      iex> UDPClient.hello()
      :world

  {10, 100, 23, 242}
  {10, 100, 23, 187}

  """

  def send(msg, port, address) do
    # first line probably wrong
    # {:ok, addr} = :gen_udp.open(30000, [{:ip, {255, 255, 255, 255}}])
    {:ok, sendSock} = :gen_udp.open(0, [{:broadcast, true}, {:reuseaddr, true}])
    :gen_udp.send(sendSock, address, port, msg)
    # broadcastIP = #.#.#.255. First three bytes are from the local IP, or just use 255.255.255.255
    # addr = new InternetAddress(broadcastIP, port)
    # sendSock = new Socket(udp) # UDP, aka SOCK_DGRAM
    # sendSock.setOption(broadcast, true)
    # sendSock.sendTo(message, addr)
  end

  def reciever(port) do
    {:ok, recvSock} = :gen_udp.open(port, [:binary, {:reuseaddr, true}, {:active, false}])
    # bind to addr?
    reciever(recvSock, 0)


    #byte[1024] buffer
    #InternetAddress fromWho
    #recvSock = new Socket(udp)
    #recvSock.bind(addr) # same addr as sender
    #loop
      #buffer.clear

      # fromWho will be modified by ref here. Or it's a return value. Depends
      #recvSock.receiveFrom(buffer, ref fromWho)
      #if (fromWho.IP != localIP) # check we are not receiving from ourselves
        # do stuff with buffer
      #endd
  end

  def reciever(recvSock, _int) do
    {:ok, {address, port, packet}} = :gen_udp.recv(recvSock, 0)
    reciever(address, port, packet)
    reciever(recvSock, 0)
  end

  def reciever(address, _port, packet) when address != {10, 100, 23, 187} do
    IO.puts "This packet was sent: #{packet}"
  end

end
