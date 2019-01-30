defmodule TCPClient do
    def init() do
        {:ok, socket} = :gen_tcp.connect({10, 100, 23, 242}, 34933, [])
        :gen_tcp.send(socket, "Connect to: 10.100.23.187\0")
        socket
    end

    def send(msg, socket) do
        :gen_tcp.send(socket, msg)
    end

    def reciever(socket) do
        {:ok, packet} = :gen_tcp.recv(socket, 0)
        IO.puts "Recieved: #{packet}"
    end
end