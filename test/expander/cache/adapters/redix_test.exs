defmodule Expander.Cache.Adapter.RedixTest do
  use ExUnit.Case, async: true

  alias Expander.Url

  Application.put_env(
    :expander,
    Expander.Cache.Adapter.RedixTest.RedisCache,
    conn: [
      host: System.get_env("REDIX_TEST_HOST") || "localhost",
      port: String.to_integer(System.get_env("REDIX_TEST_PORT") || "6379")
    ]
  )

  defmodule RedisCache do
    use Expander.Expand, otp_app: :expander, adapter: Expander.Cache.Adapter.Redix
  end


  setup_all do
    {:ok, pid} = RedisCache.start_adapter()
    state = :sys.get_state(pid)
    %Expander.Cache.Store{state: conn} =  state

    # Make sure to flush redis before we start.
    Redix.command!(conn, ["FLUSHDB"])

    {:ok, state: state, conn: conn}
  end

  test "get/2", %{state: state, conn: conn}   do
    assert Expander.Cache.Adapter.Redix.get(state, "key") == {:ok, state, :error}

    Redix.command(conn, ["SET", "key", "value"])

    assert Expander.Cache.Adapter.Redix.get(state, "key") == {:ok, state, {:ok, "value"}}
  end

  test "set/2", %{state: state, conn: conn}   do
    assert {:ok, state} == Expander.Cache.Adapter.Redix.set(state, "key1", "value1")
    assert Redix.command(conn, ["GET", "key1"]) == {:ok, "value1"}
  end

  test "expand interface", %{conn: conn} do
    #
    # Manually create url and set in in Redis Directly, then expand should fetch this URL from redis and return it
    #
    url = Url.new(short_url: "http://stpz.co/haddafios", long_url: "https://itunes.apple.com/us/app/haddaf-hdaf/id872585884")
    Redix.command(conn, ["SET", Url.cache_key(url), Poison.encode!(url)])

    assert {:ok, url, %{expanded: true, source: :cache}} == RedisCache.expand(url)
  end
end
