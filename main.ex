defmodule Counter do
  def tick(value) do
    Process.sleep(1500)
    value |> increment()
  end

  def increment(value, increment \\ 1) do
    value + increment
  end
end

defmodule Controller do
  def start do
    {:ok, pid} = Task.start_link(fn -> init() end)
    send(pid, :start)
    pid
  end

  def stop(pid) do
    send(pid, :kill)
  end

  def resume(pid) do
    send(pid, :resume)
  end

  def init() do
    receive do
      :start ->
        {:ok, store_pid} = Store.start()
        clock_pid = spawn_clock()
        clock_pid |> send({:tick, 0, store_pid})
        control(clock_pid, store_pid)
    end
  end
  
  def spawn_clock do
    spawn(Controller, :clock, [])
  end

  def control(clock_pid, store_pid) do
    receive do
      :resume ->
        new_pid = spawn_clock()
        resume_clock(new_pid, store_pid)

      :kill ->
        Process.exit(clock_pid, :ok)
        control(clock_pid, store_pid)
    end
  end

  def resume_clock(pid, store_pid) do
    store_pid |> send({:get, self()})

    receive do
      value ->
        pid |> send({:tick, value, store_pid})
    end

    control(pid, store_pid)
  end

  def clock do
    receive do
      {:tick, value, store_pid} ->
        new_value = value |> Counter.tick()
        send(self(), {:tick, new_value, store_pid})
        send(store_pid, {:set, value})
        clock()
    end
  end
end

defmodule Store do
  def start do
    Task.start_link(fn -> loop(%{}) end)
  end

  def loop(map) do
    receive do
      {:set, value} ->
        loop(Map.put(map, :count, value))

      {:get, caller} ->
        send(caller, Map.get(map, :count))
        loop(map)
    end
  end
end
