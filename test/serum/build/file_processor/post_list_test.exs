defmodule Serum.Build.FileProcessor.PostListTest do
  use Serum.Case, async: true
  alias Serum.Build.FileProcessor.PostList, as: ListGenerator
  alias Serum.V2.BuildContext
  alias Serum.V2.Tag

  setup_all do
    tags1 =
      ~w(tag1 tag2 tag3)
      |> Enum.map(&%Tag{name: &1, url: "/tags/#{&1}/"})
      |> Stream.cycle()

    tags2 = Stream.drop(tags1, 1)

    posts =
      [1..30, tags1, tags2]
      |> Enum.zip()
      |> Enum.map(fn {n, t1, t2} ->
        build(:post, title: "Test Post #{n}", tags: Enum.sort([t1, t2]))
      end)

    {:ok, [posts: posts]}
  end

  describe "generate_lists/2" do
    test "no pagination", ctx do
      context = make_context(%{blog: %{pagination: false}})
      {:ok, {lists, counts}} = ListGenerator.generate_lists(ctx.posts, context)

      # (num_of_tags + 1) * (index + page_1)
      assert length(lists) === (3 + 1) * 2
      assert length(counts) === 3

      Enum.each(counts, fn {_, n} -> assert n === 20 end)

      [all1, all2 | lists2] = lists

      Enum.each(lists2, fn list ->
        assert length(list.posts) === 20
        assert String.starts_with?(list.title, "Posts Tagged")
      end)

      Enum.each([all1, all2], fn list ->
        assert length(list.posts) === 30
        assert list.title === "All Posts"
      end)
    end

    test "chunk every 5 posts", ctx do
      context = make_context(%{blog: %{pagination: true, posts_per_page: 5}})
      {:ok, {lists, counts}} = ListGenerator.generate_lists(ctx.posts, context)

      # num_of_tags * (index + page_1_to_4) + 1 * (index + page_1_to_6)
      assert length(lists) === 3 * (1 + 4) + (1 + 6)
      assert length(counts) === 3

      Enum.each(counts, fn {_, n} -> assert n === 20 end)

      initial_state = %{
        nil => 0,
        "tag1" => 0,
        "tag2" => 0,
        "tag3" => 0
      }

      state =
        Enum.reduce(lists, initial_state, fn list, acc ->
          assert length(list.posts) === 5
          check_list(list)
          Map.update(acc, list.tag && list.tag.name, 0, fn x -> x + 1 end)
        end)

      assert state[nil] === 7
      assert state["tag1"] === 5
      assert state["tag2"] === 5
      assert state["tag3"] === 5
    end
  end

  @spec make_context(keyword()) :: BuildContext.t()
  defp make_context(project_overrides) do
    %BuildContext{
      project:
        :project
        |> build(base_url: "https://example.com/")
        |> deep_merge(project_overrides),
      source_dir: "/path/to/src/",
      dest_dir: "/path/to/dest/"
    }
  end

  @spec deep_merge(map(), map()) :: map()
  defp deep_merge(map1, map2) do
    Map.merge(map1, map2, fn
      _key, %{} = value1, %{} = value2 -> deep_merge(value1, value2)
      _key, _value1, value2 -> value2
    end)
  end

  defp check_list(list) do
    if is_nil(list.tag) do
      assert list.title === "All Posts"
    else
      assert String.starts_with?(list.title, "Posts Tagged")
    end
  end
end
