defmodule UDPClientTest do
  use ExUnit.Case
  doctest UDPClient

  test "greets the world" do
    assert UDPClient.hello() == :world
  end
end
