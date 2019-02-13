defmodule SimpleElevatorTest do
  use ExUnit.Case
  doctest SimpleElevator

  test "greets the world" do
    assert SimpleElevator.hello() == :world
  end
end
