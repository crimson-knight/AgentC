
# The primary client for interacting directly with models that are available on the local computer.
# 
# This class allows the app to switch out specific fune-tuning aspects that improve the models accuracy for specific tasks. This includes:
#   - adding custom `grammars` for customizing response formats
#   - adding or switching out LoRA's
#   - managing the model's context window (token length)
#
# Logs are always disabled with --log-disable when running from within this app
class LlamaCpp

  property model_name : String = "llama-2-13b-chat.Q8_0.gguf"
  property grammar_root_path : Path = Path["/Users/#{`whoami`.strip}/.agentc/grammars"]
  property lora_root_path : Path = Path["/Users/#{`whoami`.strip}/.agentc/loras"]
  property model_root_path : Path = Path["/Users/#{`whoami`.strip}/.agentc/models"]

  # Adjust up to punish repetitions more harshly, lower for more monotonous responses. Default: 1.1
  property repeat_pentalty : Float32 = 1.1 # --repeat-penalty

  # Adjust up to get more unique responses, adjust down to get more "probable" responses. Default: 40
  property top_k_sampling : Int32 = 40 # --top-k

  # Number of threads. Should be set to the number of physical cores, not logical cores. The M1 Max has a 10 core CPU and 32 core GPU. Let's try it with 32 to start
  property threads : Int32 = 32 # --threads

  # This is just the name of the grammer file, relative to the grammar_root_path. If it's blank, it's not included in the execute command
  property grammer_file : String = "" # --grammer-file

  # Defaults are too small in the model binary (512) so setting this to 2048, which is what Llama models were trained using.
  property context_size : Int32 = 2048 # --ctx-size

  # Adjust up or down to play with creativity
  property temperature : Float32 = 0.9 # --temperature

  # Include this to make parsing system responses easier. It acts like an opening HTML tag, but there's no closing component
  property in_suffix : String = "<Assistant: " # --in-suffix

  # This is just a good idea, it helps keep the original prompt in the context window. This should keep the model more focused on the original topic.
  property keep : String = "--keep"

  # Setting this changes how many tokens are trying to be predicted at a time. Setting this to -1 will generate tokens infinitely, but causes the context window to reset frequently.
  # Setting this to -2 stops generating as soon as the context window fills up
  property n_predict : Int32 = 256


  def chat(messages : Array(NamedTuple(role: String, content: String)), model : String = model_name, temperature : Float32 = @temperature, max_tokens : Int32 = @context_size, grammar_file = "", repeat_penalty = @repeat_pentalty, top_k_sampling = @top_k_sampling, n_predict = @n_predict)
    if grammar_file.blank?
      grammar_file_command = ""
    else
      grammar_file_command = "--grammar-file \"#{@grammar_root_path.join(grammar_file)}\""
    end

    if @in_suffix.blank?
      in_suffix_command = ""
    else
      in_suffix_command = "--in-suffix \"#{@in_suffix}\""
    end

    prompt_text = ""

    # Change this into a prompting format that more clearly uses the User/Assistant format. Need to look it up in the docs though!
    messages.each { |message| prompt_text += message["role"] + ": " + message["content"] + "\n" }

    puts "in the chat, grammer file command: #{grammar_file_command}"
    response_json = Hash(String, Hash(String, String)).new
    content = Hash(String,String).new
    current_bot_process_output = ""

    query_count = 0
    successfully_completed_chat_completion = false
    while query_count < 5
      break if successfully_completed_chat_completion

      spawn do
        puts "spawning a fiber for the process..."
        begin
          current_process = Process.new("llamacpp -m \"#{model_root_path.join(model_name)}\" #{grammar_file_command} --n-predict #{n_predict} --threads #{@threads} --ctx-size #{max_tokens} --temp #{temperature} --top-k #{top_k_sampling} --repeat-penalty #{repeat_penalty} --log-disable --prompt \"#{prompt_text}\"", shell: true, input: Process::Redirect::Close, output: Process::Redirect::Pipe, error: Process::Redirect::Close)
          current_bot_process_output = current_process.output.gets_to_end
          current_process.wait

          puts current_bot_process_output.inspect
          
          successfully_completed_chat_completion = true
          content["content"] = current_bot_process_output.split("<Assistant: ").last
        rescue e
          puts "error was rescued while trying to query the llm"
          puts e
          query_count += 1
        end
      end

      puts "A fiber has spawned... now waiting for a response before timing out"

      # Multi-threaded keyword here, this acts like a blocking mechanism to allow for reflecting on the previously spawned fiber
      select
      when timeout(1.minute)
        if content["content"].empty?
          content["content"] = %({ "error": "5 attempts were made to generate a chat completion and timed out every time. Try changing your prompt." })
        end
        
        query_count += 1
      end
    end

    response_json["message"] = content
    return JSON.parse(response_json.to_json)
  end
end


