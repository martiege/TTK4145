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

  def send(msg, port) do
    # first line probably wrong
    # {:ok, addr} = :gen_udp.open(30000, [{:ip, {255, 255, 255, 255}}])
    {:ok, sendSock} = :gen_udp.open(0, [{:broadcast, true}, {:reuseaddr, true}])
    :gen_udp.send(sendSock, {255, 255, 255, 255}, port, msg)
    # broadcastIP = #.#.#.255. First three bytes are from the local IP, or just use 255.255.255.255
    # addr = new InternetAddress(broadcastIP, port)
    # sendSock = new Socket(udp) # UDP, aka SOCK_DGRAM
    # sendSock.setOption(broadcast, true)
    # sendSock.sendTo(message, addr)
  end

  def reciever() do
    byte[1024] buffer
    InternetAddress fromWho
    recvSock = new Socket(udp)
    recvSock.bind(addr) # same addr as sender
    loop
      buffer.clear

      # fromWho will be modified by ref here. Or it's a return value. Depends
      recvSock.receiveFrom(buffer, ref fromWho)
      if (fromWho.IP != localIP) # check we are not receiving from ourselves
        # do stuff with buffer
      end
  end

end
