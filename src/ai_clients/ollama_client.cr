require "http/client"
require "json"


class OllamaClient
  property model : String
  property temperature : Float64
  property max_tokens : Int32

  def initialize(@model = "llama2", @temperature = 0.7, @max_tokens = 4096)
  end

  # This generates a chat completion. This name was kept in order to maintain compatibility with the OpenAI client
  def chat(messages : Array(NamedTuple(role: String, content: String)), model : String = @model, temperature : Float64 = @temperature, max_tokens : Int32 = @max_tokens)
    body = {
      model: model,
      messages: messages,
      stream: false
    }.to_json

    response = HTTP::Client.post("http://localhost:11434/api/chat",
                                  headers: HTTP::Headers{"Content-Type" => "application/json"},
                                  body: body)
    JSON.parse(response.body)
  end

  def create_model(model_name : String, training_data : String, model_type : String)
    body = {
      model_name: model_name,
      training_data: training_data,
      model_type: model_type,
      learning_rate: learning_rate,
      epochs: epochs
    }.to_json

    response = HTTP::Client.post("http://localhost:11434/api/models",
                                  headers: HTTP::Headers{"Content-Type" => "application/json"},
                                  body: body)
    JSON.parse(response.body)
  end

  def generate_embeddings(texts : Array(String), model : String = @model)
    body = {
      texts: texts,
      model: model
    }.to_json

    response = HTTP::Client.post("http://localhost:11434/api/embeddings",
                                  headers: HTTP::Headers{"Content-Type" => "application/json"},
                                  body: body)
    JSON.parse(response.body)
  end
end