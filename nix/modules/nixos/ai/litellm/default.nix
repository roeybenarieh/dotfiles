{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.litellm;
in
{
  options.${namespace}.litellm = with types; {
    enable = mkBoolOpt false "Enable LiteLLM proxy (OpenAI-compatible gateway for 100+ AI providers).";
    port = mkIntOpt 4000 "Port LiteLLM listens on.";
    environmentFile = mkOpt (nullOr path) null "Path to env file with API keys (GEMINI_API_KEY, GROQ_API_KEY, OPENROUTER_API_KEY, CEREBRAS_API_KEY, SAMBANOVA_API_KEY, HF_TOKEN).";
    masterKey = mkstrOpt "sk-litellm" "Master key required to authenticate all requests to the proxy.";
  };

  config = mkIf cfg.enable {
    # NOTE: if you want to check if some model is working, run:
    # curl -X POST http://127.0.0.1:4000/v1/messages -H "Authorization: Bearer sk-1234" -H "Content-Type: application/json" \
    # -d '{ "model": "gemini-3.6-flash", "max_tokens": 1000, "messages": [{"role": "user", "content": "What is the capital of France?"}] }'
    # the model can be both 'model' and 'model_name', 'model' is unique to the given provider

    services.litellm = {
      enable = true;
      port = cfg.port;
      host = "127.0.0.1";
      environmentFile = cfg.environmentFile;

      settings = {
        general_settings = {
          master_key = cfg.masterKey;
        };

        litellm_settings = {
          # Drop unsupported params so free providers don't reject Claude-specific fields
          drop_params = true;
          modify_params = true;
          set_verbose = false;
        };

        router_settings = {
          routing_strategy = "latency-based-routing";
          num_retries = 3;
          cooldown_time = 300; # Cooldown rate-limited / quota-exhausted models for 5 minutes

          model_group_alias = {
            # TUI alias names that correspond to the model groups visible in claude-code UI
            "Default" = "auto";
            "Sonnet" = "gemini-3.6-flash";
            "Sonnet (1M context)" = "claude-3-7-sonnet-20250219";
            "Opus" = "nemotron-ultra-550b";
            "Haiku" = "gemini-3.5-flash-lite";

            # Anthropic / Claude Code TUI models mapped to our top models
            "claude-3-7-sonnet-20250219" = "gemini-3.6-flash";
            "claude-3-7-sonnet" = "gemini-3.6-flash";
            "claude-3-5-sonnet-20241022" = "gemini-3.6-flash";
            "claude-3-5-sonnet" = "gemini-3.6-flash";
            "claude-sonnet-4-6" = "gemini-3.6-flash";
            "sonnet" = "gemini-3.6-flash";

            "claude-3-5-haiku-20241013" = "gemini-3.5-flash-lite";
            "claude-3-5-haiku" = "gemini-3.5-flash-lite";
            "claude-haiku-4-5-20251001" = "gemini-3.5-flash-lite";
            "haiku" = "gemini-3.5-flash-lite";

            "claude-3-opus-20240229" = "nemotron-ultra-550b";
            "claude-3-opus" = "nemotron-ultra-550b";
            "claude-opus-4-8" = "nemotron-ultra-550b";
            "opus" = "nemotron-ultra-550b";

            "claude-fable-5" = "DeepSeek-V4-Flash-0731";
            "fable" = "DeepSeek-V4-Flash-0731";

            "auto" = "gemini-3.6-flash";
            "claude-auto" = "gemini-3.6-flash";
          };

          fallbacks = [
            # Google Gemini tier-based failover (if quota finished / 429)
            {
              "gemini-3.6-flash" = [
                "gemini-3.5-flash-lite"
                "gemini-3.1-flash-lite"
                "llama-3.3-70b"
                "nemotron-ultra-550b"
              ];
            }
            {
              "gemini-3.5-flash-lite" = [
                "gemini-3.1-flash-lite"
                "llama-3.1-8b"
                "nemotron-super-120b"
              ];
            }
            {
              "gemini-3.1-flash-lite" = [
                "llama-3.1-8b"
                "nemotron-nano-30b"
              ];
            }
            # Groq tier-based failover
            {
              "llama-3.3-70b" = [
                "llama-3.1-8b"
                "gpt-oss-120b"
                "nemotron-ultra-550b"
              ];
            }
          ];
        };

        model_list = [
          # ── Google AI Studio (free tier) ─────────────────────────────────────
          # API key: GEMINI_API_KEY  (https://aistudio.google.com/apikey)
          # available models: https://aistudio.google.com/docs/models
          {
            model_name = "gemini-3.6-flash";
            litellm_params = {
              model = "gemini/gemini-3.6-flash";
              api_key = "os.environ/GEMINI_API_KEY";
              order = 1;
            };
          }
          {
            model_name = "gemini-3.5-flash-lite";
            litellm_params = {
              model = "gemini/gemini-3.5-flash-lite";
              api_key = "os.environ/GEMINI_API_KEY";
              order = 2;
            };
          }
          {
            model_name = "gemini-3.1-flash-lite";
            litellm_params = {
              model = "gemini/gemini-3.1-flash-lite";
              api_key = "os.environ/GEMINI_API_KEY";
              order = 3;
            };
          }

          # ── Groq (free tier) ─────────────────────────────────────────────────
          # API key: GROQ_API_KEY  (https://console.groq.com)
          {
            model_name = "llama-3.3-70b";
            litellm_params = {
              model = "groq/llama-3.3-70b-versatile";
              api_key = "os.environ/GROQ_API_KEY";
              order = 1;
            };
          }
          {
            model_name = "llama-3.1-8b";
            litellm_params = {
              model = "groq/llama-3.1-8b-instant";
              api_key = "os.environ/GROQ_API_KEY";
              order = 2;
            };
          }
          {
            model_name = "gpt-oss-120b";
            litellm_params = {
              model = "groq/openai/gpt-oss-120b";
              api_key = "os.environ/GROQ_API_KEY";
              order = 3;
            };
          }
          {
            model_name = "gpt-oss-20b";
            litellm_params = {
              model = "groq/openai/gpt-oss-20b";
              api_key = "os.environ/GROQ_API_KEY";
              order = 4;
            };
          }

          # ── OpenRouter free models (:free) ────────────────────────────────────
          # API key: OPENROUTER_API_KEY  (https://openrouter.ai/keys)
          # NOTE: this model is good but very slow
          {
            model_name = "nemotron-ultra-550b";
            litellm_params = {
              model = "openrouter/nvidia/nemotron-3-ultra-550b-a55b:free";
              api_key = "os.environ/OPENROUTER_API_KEY";
              order = 1;
            };
          }
          {
            model_name = "nemotron-super-120b";
            litellm_params = {
              model = "openrouter/nvidia/nemotron-3-super-120b-a12b:free";
              api_key = "os.environ/OPENROUTER_API_KEY";
              order = 2;
            };
          }
          {
            model_name = "nemotron-nano-30b";
            litellm_params = {
              model = "openrouter/nvidia/nemotron-3-nano-30b-a3b:free";
              api_key = "os.environ/OPENROUTER_API_KEY";
              order = 3;
            };
          }
          {
            model_name = "nemotron-nano-30b-reasoning";
            litellm_params = {
              model = "openrouter/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free";
              api_key = "os.environ/OPENROUTER_API_KEY";
              order = 3;
            };
          }

          # ── Hugging Face Inference API (free with HF_TOKEN) ───────────────────
          # Token: HF_TOKEN  (https://huggingface.co/settings/tokens)
          # available models(there are ALOT): https://huggingface.co/models
          {
            model_name = "DeepSeek-V4-Flash-0731";
            litellm_params = {
              model = "huggingface/deepseek-ai/DeepSeek-V4-Flash-0731";
              api_key = "os.environ/HF_TOKEN";
              thinking.type = "disabled";
              order = 1;
            };
            model_info = {
              supports_reasoning = false;
            };
          }
          {
            model_name = "nvidia-Nemotron-3.5-Lightning-30B";
            litellm_params = {
              model = "huggingface/nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4";
              api_key = "os.environ/HF_TOKEN";
              order = 2;
            };
          }
          {
            model_name = "Qwen3-Coder-Next";
            litellm_params = {
              model = "huggingface/Qwen/Qwen3-Coder-Next";
              api_key = "os.environ/HF_TOKEN";
              order = 3;
            };
          }
        ];
      };
    };
  };
}
