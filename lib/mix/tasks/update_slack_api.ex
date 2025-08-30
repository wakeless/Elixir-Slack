defmodule Mix.Tasks.UpdateSlackApi do
  @moduledoc """
  Updates Slack API documentation files for generating API code.

  Fetches the OpenAPI specification from Slack's API and converts it
  to the JSON format used by the Elixir-Slack library.
  """

  use Mix.Task

  @openapi_spec_url "https://api.slack.com/specs/openapi/v2/slack_web.json"
  @output_dir "lib/slack/web/docs"

  def run(_) do
    # Ensure required applications are started
    Application.ensure_all_started(:hackney)
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:inets)

    IO.puts("Fetching OpenAPI specification from Slack...")

    @openapi_spec_url
    |> fetch_openapi_spec()
    |> extract_methods()
    |> convert_methods_to_json()
    |> write_method_files()

    IO.puts("Successfully updated Slack API documentation files!")
  end

  def fetch_openapi_spec(url) do
    options = [
      ssl: [verify: :verify_none],
      recv_timeout: 30_000
    ]

    case HTTPoison.get(url, [], options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode!(body)

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        raise "Failed to fetch OpenAPI spec: HTTP #{status_code}"

      {:error, %HTTPoison.Error{reason: reason}} ->
        raise "Failed to fetch OpenAPI spec: #{reason}"
    end
  end

  def extract_methods(openapi_spec) do
    paths = openapi_spec["paths"] || %{}

    paths
    |> Enum.flat_map(fn {path, methods} ->
      methods
      |> Enum.map(fn {_http_method, method_spec} ->
        method_name = path |> String.trim_leading("/")
        {method_name, method_spec}
      end)
    end)
    |> Enum.filter(fn {_name, spec} -> Map.has_key?(spec, "operationId") end)
  end

  def convert_method_to_json(_method_name, method_spec) do
    # Extract the actual method details (usually under "post" or other HTTP method)
    actual_method = method_spec["post"] || method_spec["get"] || method_spec

    %{
      "args" => convert_parameters(actual_method["parameters"] || []),
      "desc" => actual_method["summary"] || actual_method["description"] || "",
      "errors" => convert_errors(actual_method["responses"] || %{})
    }
  end

  def write_method_files(methods) do
    File.mkdir_p!(@output_dir)

    Enum.each(methods, fn {method_name, method_json} ->
      filename = "#{@output_dir}/#{method_name}.json"
      content = Jason.encode!(method_json, pretty: true)
      File.write!(filename, content)
    end)

    IO.puts("Wrote #{length(methods)} method files to #{@output_dir}")
  end

  defp convert_methods_to_json(methods) do
    Enum.map(methods, fn {method_name, method_spec} ->
      {method_name, convert_method_to_json(method_name, method_spec)}
    end)
  end

  defp convert_parameters(parameters) do
    parameters
    |> Enum.filter(fn param -> param["in"] == "formData" or param["in"] == "query" end)
    |> Enum.reduce(%{}, fn param, acc ->
      arg_spec = %{
        "required" => if(param["in"] == "formData", do: true, else: param["required"] || false),
        "desc" => param["description"] || ""
      }

      arg_spec =
        if param["type"] do
          Map.put(arg_spec, "type", param["type"])
        else
          arg_spec
        end

      arg_spec =
        if param["example"] do
          Map.put(arg_spec, "example", param["example"])
        else
          arg_spec
        end

      Map.put(acc, param["name"], arg_spec)
    end)
  end

  defp convert_errors(responses) do
    default_response = responses["default"]

    if default_response && default_response["schema"] do
      schema = default_response["schema"]
      properties = schema["properties"] || %{}
      error_prop = properties["error"] || %{}

      if error_prop["enum"] do
        error_prop["enum"]
        |> Enum.reduce(%{}, fn error_code, acc ->
          Map.put(acc, error_code, "Error: #{error_code}")
        end)
      else
        %{}
      end
    else
      %{}
    end
  end
end
