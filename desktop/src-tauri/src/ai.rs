//! Optional LLM completions (OpenAI-compatible, Anthropic, Ollama).

use crate::config::{load_settings, AiSettings};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiMessage {
    pub role: String,
    pub content: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AiChatRequest {
    pub messages: Vec<AiMessage>,
    pub system: Option<String>,
    #[serde(default = "default_max_tokens")]
    pub max_tokens: u32,
}

fn default_max_tokens() -> u32 {
    2048
}

#[derive(Debug, Clone, Serialize)]
pub struct AiChatResponse {
    pub content: String,
    pub provider: String,
    pub model: String,
}

fn resolve_ai(settings: &AiSettings) -> Result<(String, String, String, Option<String>), String> {
    if !settings.enabled {
        return Err(String::from("AI is disabled in Settings → AI Copilot."));
    }
    let provider = settings.provider.trim().to_lowercase();
    let model = settings
        .model
        .clone()
        .filter(|m| !m.trim().is_empty())
        .unwrap_or_else(|| match provider.as_str() {
            "anthropic" => "claude-3-5-sonnet-latest".into(),
            "ollama" => "llama3.2".into(),
            _ => "gpt-4o-mini".into(),
        });

    let (base, key) = match provider.as_str() {
        "ollama" => (
            settings
                .base_url
                .clone()
                .filter(|u| !u.trim().is_empty())
                .unwrap_or_else(|| "http://127.0.0.1:11434/v1".into()),
            settings.api_key.clone().or_else(|| Some("ollama".into())),
        ),
        "anthropic" => (
            settings
                .base_url
                .clone()
                .filter(|u| !u.trim().is_empty())
                .unwrap_or_else(|| "https://api.anthropic.com".into()),
            settings.api_key.clone(),
        ),
        _ => (
            settings
                .base_url
                .clone()
                .filter(|u| !u.trim().is_empty())
                .unwrap_or_else(|| "https://api.openai.com/v1".into()),
            settings.api_key.clone(),
        ),
    };

    let mut api_key = key.filter(|k| !k.trim().is_empty());
    if api_key.is_none() {
        api_key = match provider.as_str() {
            "anthropic" => std::env::var("ANTHROPIC_API_KEY").ok(),
            "ollama" => Some("ollama".into()),
            _ => std::env::var("OPENAI_API_KEY").ok(),
        };
    }
    let api_key = api_key.ok_or_else(|| {
        String::from(
            "AI API key missing — add it in Settings → AI Copilot (Ollama can use any placeholder).",
        )
    })?;

    Ok((provider, base.trim_end_matches('/').to_string(), model, Some(api_key)))
}

async fn chat_openai_compatible(
    base: &str,
    api_key: &str,
    model: &str,
    system: Option<&str>,
    messages: &[AiMessage],
    max_tokens: u32,
) -> Result<String, String> {
    let url = format!("{base}/chat/completions");
    let mut msgs: Vec<AiMessage> = Vec::new();
    if let Some(s) = system {
        msgs.push(AiMessage {
            role: "system".into(),
            content: s.to_string(),
        });
    }
    msgs.extend(messages.iter().cloned());

    #[derive(Serialize)]
    struct Body<'a> {
        model: &'a str,
        messages: &'a [AiMessage],
        max_tokens: u32,
        temperature: f32,
    }

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(120))
        .build()
        .map_err(|e| e.to_string())?;

    let resp = client
        .post(&url)
        .bearer_auth(api_key)
        .json(&Body {
            model,
            messages: &msgs,
            max_tokens,
            temperature: 0.3,
        })
        .send()
        .await
        .map_err(|e| format!("AI request failed: {e}"))?;

    let status = resp.status();
    let body = resp.text().await.map_err(|e| e.to_string())?;
    if !status.is_success() {
        let snippet: String = body.chars().take(400).collect();
        return Err(format!("AI HTTP {status}: {snippet}"));
    }

    let parsed: serde_json::Value =
        serde_json::from_str(&body).map_err(|e| format!("Invalid AI JSON: {e}"))?;
    parsed["choices"][0]["message"]["content"]
        .as_str()
        .map(str::to_string)
        .ok_or_else(|| format!("Unexpected AI response shape: {body}"))
}

async fn chat_anthropic(
    base: &str,
    api_key: &str,
    model: &str,
    system: Option<&str>,
    messages: &[AiMessage],
    max_tokens: u32,
) -> Result<String, String> {
    let url = format!("{base}/v1/messages");
    let user_messages: Vec<AiMessage> = messages
        .iter()
        .filter(|m| m.role != "system")
        .cloned()
        .collect();

    #[derive(Serialize)]
    struct Msg<'a> {
        role: &'a str,
        content: &'a str,
    }

    #[derive(Serialize)]
    struct Body<'a> {
        model: &'a str,
        max_tokens: u32,
        system: Option<&'a str>,
        messages: Vec<Msg<'a>>,
    }

    let msgs: Vec<Msg> = user_messages
        .iter()
        .map(|m| Msg {
            role: if m.role == "assistant" {
                "assistant"
            } else {
                "user"
            },
            content: &m.content,
        })
        .collect();

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(120))
        .build()
        .map_err(|e| e.to_string())?;

    let resp = client
        .post(&url)
        .header("x-api-key", api_key)
        .header("anthropic-version", "2023-06-01")
        .json(&Body {
            model,
            max_tokens,
            system,
            messages: msgs,
        })
        .send()
        .await
        .map_err(|e| format!("Anthropic request failed: {e}"))?;

    let status = resp.status();
    let body = resp.text().await.map_err(|e| e.to_string())?;
    if !status.is_success() {
        let snippet: String = body.chars().take(400).collect();
        return Err(format!("Anthropic HTTP {status}: {snippet}"));
    }

    let parsed: serde_json::Value =
        serde_json::from_str(&body).map_err(|e| format!("Invalid Anthropic JSON: {e}"))?;
    parsed["content"][0]["text"]
        .as_str()
        .map(str::to_string)
        .ok_or_else(|| format!("Unexpected Anthropic response: {body}"))
}

pub async fn ai_chat(req: AiChatRequest) -> Result<AiChatResponse, String> {
    let settings = load_settings();
    let (provider, base, model, api_key) = resolve_ai(&settings.ai)?;
    let api_key = api_key.unwrap_or_default();
    let system = req.system.as_deref();

    let content = if provider == "anthropic" {
        chat_anthropic(
            &base,
            &api_key,
            &model,
            system,
            &req.messages,
            req.max_tokens,
        )
        .await?
    } else {
        chat_openai_compatible(
            &base,
            &api_key,
            &model,
            system,
            &req.messages,
            req.max_tokens,
        )
        .await?
    };

    Ok(AiChatResponse {
        content,
        provider,
        model,
    })
}
