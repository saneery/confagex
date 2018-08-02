defmodule Confagex.TCPClient do
  use GenServer
  require Logger
  require Poison

  def start_link(host, port, opts, timeout \\ 5000) do
    GenServer.start_link(__MODULE__, {host, port, opts, timeout}, name: __MODULE__)
  end

  def init({host, port, opts, timeout}) do
    app_name = Application.get_env(:confagex, :app_name)
    state = %{host: host, port: port, opts: opts, timeout: timeout, sock: nil}

    case :gen_tcp.connect(host, port, [active: false] ++ opts, timeout) do
      {:ok, sock} ->
        Logger.info("Confagex connected to server")

        case resolve_configs(sock, app_name) do
          {:error, reason} ->
            Logger.error("Confagex cannot resolve configs. #{inspect(reason)}")

          :ok ->
            Logger.info("Confagex resolved configs")
        end

        if Application.get_env(:confagex, :subscribe, false) do
          :gen_tcp.send(sock, "subscribe:#{app_name}")
          Logger.info("Subscribed")
          send(__MODULE__, {:subscribe, app_name})
        end

        {:ok, %{state | sock: sock}}

      {:error, reason} ->
        Logger.error("Confagex cannot connect to server")
        {:stop, reason}
    end
  end

  def handle_info({:subscribe, app}, %{sock: sock} = state) do
    :gen_tcp.recv(sock, 0)
    |> apply_config(app)
    |> case do
      :ok -> Logger.info("Confagex updated configs")
      {:error, reason} -> Logger.warn("Confagex could not update configs: #{reason}")
    end

    send(self(), {:subscribe, app})
    {:noreply, state}
  end

  def resolve_configs(sock, app) do
    sock
    |> send_command("get_config:#{app}")
    |> recv_data()
    |> apply_config(app)
  end

  defp send_command(sock, command) do
    case :gen_tcp.send(sock, command) do
      :ok -> {:ok, sock}
      {:error, _} = e -> e
    end
  end

  defp recv_data({:error, _} = e), do: e

  defp recv_data({:ok, sock}) do
    case :gen_tcp.recv(sock, 0) do
      {:ok, _data} = d -> d
      {:error, _} = e -> e
    end
  end

  defp apply_config({:error, _} = e, _), do: e
  defp apply_config({:ok, 'not_found'}, _), do: {:error, "configs not found"}

  defp apply_config({:ok, data}, app) do
    case Poison.decode(data) do
      {:error, _} = e ->
        e

      {:ok, %{"error" => reason}} ->
        {:error, reason}

      {:ok, configs} ->
        configs
        |> map_to_keyword()
        |> Enum.each(fn {key, val} ->
          Application.put_env(String.to_atom(app), key, val)
        end)
    end
  end

  defp map_to_keyword(data) do
    Enum.reduce(data, Keyword.new(), fn {key, val}, keyword ->
      case is_map(val) do
        true ->
          new_val = map_to_keyword(val)
          atom_key = String.to_atom(key)
          Keyword.put(keyword, atom_key, new_val)

        false ->
          atom_key = String.to_atom(key)
          Keyword.put(keyword, atom_key, val)
      end
    end)
  end
end
