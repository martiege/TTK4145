defmodule PhoenixCounterTest do
  use ExUnit.Case
  doctest PhoenixCounter

  test "greets the world" do
    assert PhoenixCounter.hello() == :world
  end
end
