# ai-stack-do

Production-ready self-hosted AI stack on a **single $40/month Digital Ocean droplet**.
Qdrant + Langfuse + LiteLLM + Redis 8 + Ollama + Nginx + Prometheus + Grafana + Restic backups.

Companion repo for: [Stack de IA self-hosted en un droplet de $40](https://numoru.com/contribuciones/stack-ia-self-hosted-digital-ocean).

## Quick start

```bash
git clone https://github.com/numoru-ia/ai-stack-do.git
cd ai-stack-do
cp .env.example .env
# edit .env with your values
make up
```

Point your DNS (`api.*`, `langfuse.*`, `grafana.*`, `qdrant.*`) to the droplet IP, then:

```bash
make certs        # provision Let's Encrypt certs
make seed-ollama  # download llama3.3:8b-instruct-q4_K_M
make health       # verify all services
```

## What's inside

| Service | Port | Purpose |
|---|---|---|
| Nginx | 80/443 | reverse proxy + TLS |
| LiteLLM Proxy | 4000 | unified gateway (Claude, GPT, Gemini, Ollama) with semantic cache + Langfuse traces |
| Qdrant | 6333 | vector database |
| Redis 8 (Stack) | 6379 | semantic cache + working memory |
| Ollama | 11434 | local model inference |
| Langfuse web + worker | 3000 | LLM observability |
| Postgres | 5432 | Langfuse + LiteLLM metadata |
| ClickHouse | 8123 | Langfuse analytics |
| Prometheus + Grafana | 9090 / 3001 | metrics |
| Restic | — | daily backups to DO Spaces |

## Memory budget

| Service | Limit | Working set (typical) |
|---|---|---|
| Ollama | 5 GB | 0-4.8 GB (loaded on demand) |
| Qdrant | 2 GB | ~0.6 GB @ 1M vectors |
| Redis | 1.2 GB | configurable |
| ClickHouse | 1 GB | ~0.4 GB |
| Langfuse + Postgres | 1.25 GB | |
| Nginx / Prometheus / Grafana | 400 MB | |
| **Total committed** | **11.3 GB** | ~6.5 GB typical |

Fits in `s-4vcpu-8gb` ($40/month) because Ollama is loaded on-demand.

## Architecture

```
                         ┌──────────────────────────────────────────────┐
                         │   Droplet s-4vcpu-8gb                        │
  Cliente (HTTPS) ──► Nginx ──► [ LiteLLM Proxy   :4000 ]               │
                         │         ├──► Anthropic / OpenAI / Gemini     │
                         │         └──► Ollama :11434 (Llama 3.3 8B)    │
                         │      [ Qdrant :6333 ]  [ Redis :6379 ]       │
                         │      [ Langfuse web+worker ] [ PG+CH ]       │
                         │      [ Prometheus ] [ Grafana ]              │
                         │      Restic daemon ──► DO Spaces (S3)        │
                         └──────────────────────────────────────────────┘
```

## Make targets

```
make up            # docker compose up -d
make down          # docker compose down
make logs          # tail logs of all services
make certs         # Let's Encrypt certs for configured domains
make seed-ollama   # pull llama3.3 and bge models
make backup        # trigger restic backup now
make restore       # restore from latest snapshot
make health        # curl each service healthcheck
make update        # pull new images and restart
```

## Cost

| Concepto | USD/mes |
|---|---|
| Droplet `s-4vcpu-8gb` | 40 |
| Spaces (50 GB + egress) | 5 |
| Domain + certs | 1 |
| **Base infra** | **46** |

LLM API calls (Anthropic, OpenAI) are pass-through and billed separately. LiteLLM's semantic cache typically reduces LLM spend 40-60%.

## DNS setup

```
A     api.tudominio.com       → droplet_ip
A     langfuse.tudominio.com  → droplet_ip
A     grafana.tudominio.com   → droplet_ip
A     qdrant.tudominio.com    → droplet_ip
```

## Terraform (optional)

`terraform/` includes a minimal module to provision the droplet + Spaces bucket + floating IP. Apply with your DO token to spin up a fresh environment.

## Compliance notes

- **AI Act:** Langfuse retention is configurable; set `LANGFUSE_LOG_LEVEL=info` and retention ≥ 6 months for systems qualifying as high-risk.
- **Data residency:** deploy the droplet in FRA1/AMS1 for EU data; SFO3/NYC3 for US; TOR1 for Canada.
- **GDPR / LFPDPPP:** the Postgres + ClickHouse volumes contain prompt logs; rotate `LF_ENCRYPTION_KEY` quarterly and enable column-level encryption in ClickHouse for PII.

## License

Apache 2.0
