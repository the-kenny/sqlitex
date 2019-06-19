defmodule Sqlitex.ServerTest do
  use ExUnit.Case
  doctest Sqlitex.Server

  alias Sqlitex.Server

  test "out-of-order messages from two processes" do
    {:ok, server} = Server.start_link(':memory:')

    :ok = Server.exec(server, "create table foo (x int)")

    proc_a = fn ->
      :ok = Server.exec(server, "begin")
      :ok = Server.exec(server, "insert into foo (x) values(42)")

      # Wait for msg from b before continuing
      receive do
        _ -> nil
      end

      :ok = Server.exec(server, "rollback")
    end

    task_a = Task.async(proc_a)

    proc_b = fn ->
      {:ok, rows_before} = Server.query(server, "select * from foo")
      Process.send(task_a.pid, nil, [])
      {:ok, rows_after} = Server.query(server, "select * from foo")

      {:ok, rows_before, rows_after}
    end

    task_b = Task.async(proc_b)

    :ok = Task.await(task_a)
    {:ok, rows_before, rows_after} = Task.await(task_b)

    assert rows_before == []
    assert rows_after == []
  end
end
