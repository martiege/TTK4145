defmodule UDP do

end

defmodule UDP.Supervisor do
  use Supervisor


end

defmodule UDP.Server do
  @receiver_port    60000
  @receiver_options [:list, active: true]
  @receiver_timer   1000
  # specialized GenServer to handle incoming data
  # from any other elevator on the network

  use GenServer

  def start_link(port \\ @receiver_port, opts \\ @receiver_options) do
    GenServer.start_link(__MODULE__, {port, opts}, name: __MODULE__)
  end


  def init({port, opts}) do
    :gen_udp.open(port, opts)
  end


  def handle_info({:udp, socket, address, port, data}, receiver_socket) do
    IO.puts("Received packet: #{Enum.to_list(data)}")

    {:noreply, receiver_socket}
  end


  def handle_info(other, receiver_socket) do
    IO.puts("Huh? #{other}")

    {:noreply, receiver_socket}
  end

  # function to look for existing elevator network?
  # def udp_server_receiver_init(receiver_socket) do
  #   IO.puts("UDP receiver init")
  #   Process.sleep(1000)
  #
  #   udp_server_receiver(receiver_socket)
  # end
  #
  # def udp_server_receiver(receiver_socket) do
  #   #Process.sleep(1000)
  #   IO.puts("UDP receiver main")
  #
  #   {:ok, received} = :gen_udp.recv(receiver_socket, 0, @receiver_timer)
  #
  #
  #   udp_server_receiver(receiver_socket)
  # end
  #
  # def handle_receive({address, port, packet}) do
  #
  # end
  #
  # def handle_receive({})

end

# defmodule UDPServer.Transmitter do
#   # GenServer to handle outgoing data,
#   # or incoming messages from the rest of the system
#   # and appropriatly send these to the rest of the network
#
#   use GenServer
#
#
# end
