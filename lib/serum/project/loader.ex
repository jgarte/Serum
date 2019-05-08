defmodule Serum.Project.Loader do
  @moduledoc """
  A module for loading Serum project definition files.
  """

  require Serum.Util
  alias Serum.GlobalBindings
  alias Serum.Plugin
  alias Serum.Project
  alias Serum.Project.ElixirValidator
  alias Serum.Result

  @doc """
  Detects and loads Serum project definition file from the source directory.

  This function first looks for `serum.exs`. If it does not exist, it checks if
  `serum.json` exists. If none of them exists, an error is returned.
  """
  @spec load(binary(), binary()) :: Result.t(Project.t())
  def load(src, dest) do
    with {:ok, %Project{} = proj} <- do_load(src),
         {:ok, plugins} <- Plugin.load_plugins(proj.plugins) do
      Plugin.show_info(plugins)

      GlobalBindings.put(:site, %{
        name: proj.site_name,
        description: proj.site_description,
        author: proj.author,
        author_email: proj.author_email,
        server_root: proj.server_root,
        base_url: proj.base_url
      })

      {:ok, %Project{proj | src: src, dest: dest}}
    else
      {:error, _} = error -> error
    end
  end

  @spec do_load(binary()) :: Result.t(Project.t())
  defp do_load(src) do
    exs_path = Path.join(src, "serum.exs")

    if File.exists?(exs_path) do
      load_exs(exs_path)
    else
      {:error, {:enoent, exs_path, 0}}
    end
  end

  @spec load_exs(binary()) :: Result.t(Project.t())
  defp load_exs(exs_path) do
    with {:ok, data} <- File.read(exs_path),
         {map, _} <- Code.eval_string(data, [], file: exs_path),
         :ok <- ElixirValidator.validate(map) do
      {:ok, Project.new(map)}
    else
      # From File.read/1:
      {:error, reason} when is_atom(reason) ->
        {:error, {reason, exs_path, 0}}

      # From ElixirValidator.validate/2:
      {:invalid, message} when is_binary(message) ->
        {:error, {message, exs_path, 0}}

      {:invalid, messages} when is_list(messages) ->
        sub_errors =
          Enum.map(messages, fn message ->
            {:error, {message, exs_path, 0}}
          end)

        {:error, {:project_validator, sub_errors}}
    end
  rescue
    e in [CompileError, SyntaxError, TokenMissingError] ->
      {:error, {e.description, e.file, e.line}}

    e ->
      err_name =
        e.__struct__
        |> to_string()
        |> String.replace_prefix("Elixir.", "")

      err_msg = "#{err_name} while evaluating: #{Exception.message(e)}"

      {:error, {err_msg, exs_path, 0}}
  end
end
