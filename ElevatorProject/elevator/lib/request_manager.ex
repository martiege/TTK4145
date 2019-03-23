defmodule RequestManager do

  use GenServer

  @get_state_timeout 100

  def start_link() do
    GenServer.start_link(__MODULE__, {})
  end

  def init({}) do
    {:ok, {}}
  end

  def main() do
    {replies, bad_nodes} = multi_call(:get_state)

    replies = replies ++ handle_bad_nodes(bad_nodes, :get_state)



  end

  def handle_call(:get_request_id, _from, request_id) do
    {:reply, request_id, request_id}
  end

  defp multi_call(args) do
    GenServer.multi_call([Node.self(), Node.list()], ElevatorState, args, @get_state_timeout)
  end

  defp handle_bad_nodes(bad_nodes, message) do
    handle_bad_nodes(bad_nodes, message, @get_state_timeout)
  end

  defp handle_bad_nodes(bad_nodes, message, timeout) when length(bad_nodes) != 0 do
    # TODO: check if IO makes this function too slow
    IO.inspect(bad_nodes, label: "Handling these bad nodes")
    IO.inspect(message, label: "Handling calling this message")
    # find bad nodes still alive, union of Node.list() and bad_nodes
    bad_nodes = Node.list() -- (Node.list() -- bad_nodes)
    # might be "stuck" if nodes are cont. using long time to reply
    # is fine, but might be handled (finite steps)
    # though not needed for this project
    {replies, bad_nodes} = multi_call(message)

    replies ++ handle_bad_nodes(bad_nodes, message)
  end

  # end state for
  defp handle_bad_nodes([], _message, _timeout) do
    # IO.puts "Done with bad nodes"
    []
  end

end
