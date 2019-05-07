defmodule Serum.Project.ElixirValidatorTest do
  @moduledoc """
  Tests for `Serum.Project.ElixirValidator`

  The purpose of this module is to check whether the input (an Elixir term
  generated by evaluating `serum.exs`) is a valid Serum project definition.

  An Elixir term `t` is a valid Serum project definition if all of the
  conditions below is true:

  - `t` is a map.
  - `t` contains all the required keys.
  - `t` does not contain any undefined key, which is neither of the required
    keys nor the optional keys.
  - Any value associated with a key in `t` does not violate the constraints
    specific to that key.
  """

  use ExUnit.Case, async: true
  import Serum.Project.ElixirValidator

  @base_map %{
    site_name: "Test Site",
    site_description: "This is a test site.",
    author: "John Doe",
    author_email: "john.doe@example.com",
    base_url: "/"
  }

  describe "validate/1" do
    test "good, contains required keys only" do
      assert :ok = validate(@base_map)
    end

    test "good, also contains optional keys" do
      map =
        Map.merge(@base_map, %{
          server_root: "https://example.com/test",
          date_format: "{WDfull}, {D} {Mshort} {YYYY}",
          list_title_all: "All posts",
          list_title_tag: "Posts about ~s",
          pagination: true,
          posts_per_page: 10,
          preview_length: 200,
          plugins: [Serum.TestPlugin1, Serum.TestPlugin2],
          theme: Serum.TestTheme
        })

      assert :ok = validate(map)
    end

    test "not a map" do
      assert {:invalid, _} = validate(:foo)
    end

    test "missing one required key" do
      map = Map.delete(@base_map, :base_url)
      {:invalid, msg} = validate(map)

      assert String.starts_with?(msg, "missing required property:")
    end

    test "missing multiple required keys" do
      map = Map.drop(@base_map, [:base_url, :site_description])
      {:invalid, msg} = validate(map)

      assert String.starts_with?(msg, "missing required properties:")
    end

    test "one extra key" do
      map = Map.put(@base_map, :foo, :bar)
      {:invalid, msg} = validate(map)

      assert String.starts_with?(msg, "unknown property:")
    end

    test "multiple extra keys" do
      map =
        @base_map
        |> Map.put(:foo, :bar)
        |> Map.put(:lorem, "ipsum")

      {:invalid, msg} = validate(map)

      assert String.starts_with?(msg, "unknown properties:")
    end

    test "constraint check 1" do
      map = Map.put(@base_map, :base_url, "hello")
      {:invalid, l} = validate(map)

      assert length(l) == 1
    end

    test "constraint check 2" do
      map =
        Map.merge(@base_map, %{
          base_url: "hello",
          server_root: "htttps://foo.bar/baz",
          date_format: 3,
          posts_per_page: 0,
          preview_length: -1,
          theme: "Serum.TestTheme"
        })

      {:invalid, l} = validate(map)

      assert length(l) == 6
    end
  end
end
