defmodule Mix.Tasks.UpdateSlackApiTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Mix.Tasks.UpdateSlackApi

  @openapi_spec_url "https://api.slack.com/specs/openapi/v2/slack_web.json"
  @output_dir "lib/slack/web/docs"

  setup do
    # Clean up any existing test files
    if File.exists?(@output_dir) do
      File.rm_rf!(@output_dir)
    end

    File.mkdir_p!(@output_dir)

    :ok
  end

  describe "fetch_openapi_spec/1" do
    test "fetches and parses OpenAPI specification from URL" do
      spec = UpdateSlackApi.fetch_openapi_spec(@openapi_spec_url)

      assert is_map(spec)
      assert Map.has_key?(spec, "paths")
      assert Map.has_key?(spec, "info")
      assert spec["info"]["title"] == "Slack Web API"
    end
  end

  describe "extract_methods/1" do
    test "extracts method paths from OpenAPI spec" do
      mock_spec = %{
        "paths" => %{
          "/admin.apps.approve" => %{
            "post" => %{
              "operationId" => "admin_apps_approve",
              "summary" => "Approve an app for installation on a workspace."
            }
          },
          "/chat.postMessage" => %{
            "post" => %{
              "operationId" => "chat_postMessage",
              "summary" => "Sends a message to a channel."
            }
          }
        }
      }

      methods = UpdateSlackApi.extract_methods(mock_spec)

      assert length(methods) == 2
      assert Enum.any?(methods, fn {name, _} -> name == "admin.apps.approve" end)
      assert Enum.any?(methods, fn {name, _} -> name == "chat.postMessage" end)
    end
  end

  describe "convert_method_to_json/2" do
    test "converts OpenAPI method definition to target JSON format" do
      method_name = "chat.postMessage"

      method_spec = %{
        "post" => %{
          "operationId" => "chat_postMessage",
          "summary" => "Sends a message to a channel.",
          "parameters" => [
            %{
              "name" => "channel",
              "in" => "formData",
              "required" => true,
              "type" => "string",
              "description" => "Channel, private group, or IM channel to send message to."
            },
            %{
              "name" => "text",
              "in" => "formData",
              "required" => false,
              "type" => "string",
              "description" =>
                "How this field works and whether it is required depends on other fields you use in your API call.",
              "example" => "Hello world"
            }
          ],
          "responses" => %{
            "default" => %{
              "description" => "Typical error response",
              "schema" => %{
                "properties" => %{
                  "error" => %{
                    "enum" => ["channel_not_found", "not_in_channel", "msg_too_long"]
                  }
                }
              }
            }
          }
        }
      }

      result = UpdateSlackApi.convert_method_to_json(method_name, method_spec)

      assert result["desc"] == "Sends a message to a channel."
      assert Map.has_key?(result, "args")
      assert Map.has_key?(result, "errors")

      # Check args conversion
      assert result["args"]["channel"]["required"] == true

      assert result["args"]["channel"]["desc"] ==
               "Channel, private group, or IM channel to send message to."

      assert result["args"]["text"]["required"] == true
      assert result["args"]["text"]["example"] == "Hello world"
    end
  end

  describe "write_method_files/1" do
    test "writes converted methods to JSON files in correct directory" do
      methods = [
        {"chat.postMessage",
         %{
           "desc" => "Sends a message to a channel.",
           "args" => %{
             "channel" => %{
               "required" => true,
               "desc" => "Channel to send message to."
             }
           },
           "errors" => %{}
         }},
        {"admin.apps.approve",
         %{
           "desc" => "Approve an app.",
           "args" => %{},
           "errors" => %{}
         }}
      ]

      UpdateSlackApi.write_method_files(methods)

      # Check files were created
      assert File.exists?("#{@output_dir}/chat.postMessage.json")
      assert File.exists?("#{@output_dir}/admin.apps.approve.json")

      # Check file contents
      {:ok, content} = File.read("#{@output_dir}/chat.postMessage.json")
      parsed = Jason.decode!(content)
      assert parsed["desc"] == "Sends a message to a channel."
      assert parsed["args"]["channel"]["required"] == true
    end
  end

  describe "run/1" do
    @tag :slow
    test "runs the full update task" do
      output =
        capture_io(fn ->
          UpdateSlackApi.run([])
        end)

      # Should have created some files
      assert File.exists?(@output_dir)
      files = File.ls!(@output_dir)
      assert length(files) > 0

      # Check that at least some common methods exist
      assert Enum.any?(files, &String.contains?(&1, "chat"))
      assert Enum.any?(files, &String.ends_with?(&1, ".json"))
    end
  end
end
