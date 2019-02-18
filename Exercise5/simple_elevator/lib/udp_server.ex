defmodule UDPServer do
  #use GenServer

  def start_link(port, opts) do

  end

  def init(port, opts) do
    {:ok, socket} = :gen_udp.open(port, opts)

    # look for other elevators on system?
    {:ok, socket}
  end



  def start_link(port) do
    GenServer.start_link(__MODULE__, port)
  end

  def init(port) do
    :gen_udp.open(port, [:binary, active: true])
  end

  def handle_info({:udp, _socket, _address, _port, data}, socket) do
    handle_packet(data, socket)
  end


  defp handle_packet("quit\n", socket) do
    IO.puts("Received: quit")
    :gen_udp.close(socket)

    {:stop, :normal, nil}
  end

  defp handle_packet(data, socket) do
    IO.puts("Received: #{String.trim data}")
    {:noreply, socket}
  end

end

#{:ok, _pid} = Supervisor.start_link([{UDP, 2052}], strategy: :one_for_one)
