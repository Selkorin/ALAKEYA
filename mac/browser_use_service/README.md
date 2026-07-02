# browser-use Service for Alakeya

Intelligent browser automation service with full JavaScript rendering powered by browser-use and Playwright.

## Features

- **JavaScript Rendering** - Full support for SPA/React/AJAX sites
- **Multi-step Automation** - Complex scenarios: login, forms, navigation
- **Intelligent Search** - AI-powered search with automatic result extraction
- **Session Management** - Persistent sessions for multi-step workflows
- **Data Extraction** - Structured data extraction from any website
- **Screenshots** - Full page screenshots with JS rendering
- **API** - RESTful API for easy integration

## Installation

```bash
cd /Users/werni/Selkorin/mac
bash scripts/setup_browser_use.sh
```

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
cd browser_use_service
cp .env.example .env
# Edit .env with your API keys
```

Required:
- `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` for browser-use AI agent

Optional:
- `CAPTCHA_API_KEY` for CAPTCHA solving

## Usage

### Start Server

```bash
cd browser_use_service
bash start_server.sh
```

Server runs on `http://127.0.0.1:8001`

### API Endpoints

#### Health Check
```bash
curl http://127.0.0.1:8001/health
```

#### Extract Data
```bash
curl -X POST http://127.0.0.1:8001/extract \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "extraction_goal": "contacts",
    "options": {
      "include_screenshots": true,
      "wait_for_dynamic_content": true
    }
  }'
```

#### Automate Task
```bash
curl -X POST http://127.0.0.1:8001/automate \
  -H "Content-Type: application/json" \
  -d '{
    "task": "Navigate to amazon.com and search for MacBook Pro",
    "options": {
      "max_steps": 50,
      "screenshot_every_step": true
    }
  }'
```

#### Screenshot
```bash
curl -X POST http://127.0.0.1:8001/screenshot \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "options": {
      "full_page": true,
      "wait_for_render": 2000
    }
  }'
```

#### Intelligent Search
```bash
curl -X POST http://127.0.0.1:8001/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "MacBook Pro M3 reviews",
    "max_results": 5,
    "extraction_goal": "reviews_summary"
  }'
```

#### Session Management

Create session:
```bash
curl -X POST http://127.0.0.1:8001/session/create \
  -H "Content-Type: application/json" \
  -d '{"options": {"headless": true}}'
```

Close session:
```bash
curl -X DELETE http://127.0.0.1:8001/session/{session_id}
```

List sessions:
```bash
curl http://127.0.0.1:8001/sessions
```

## Architecture

```
Alakeya (Swift)
    ↓ HTTP JSON
browser-use Service (Python)
    ↓
browser-use + Playwright
```

## Dependencies

- Python 3.8+
- browser-use
- playwright
- fastapi
- uvicorn

## Troubleshooting

### Service not starting
- Check virtual environment: `ls ../.venv/browser_use`
- Check dependencies: `source ../.venv/browser_use/bin/activate && pip list`
- Check browser-use: `python3 -c "import browser_use"`

### Import errors
- Reinstall dependencies: `bash scripts/setup_browser_use.sh`
- Check Playwright browsers: `playwright install chromium`

### Port already in use
- Change port in `.env`: `BROWSER_USE_PORT=8002`

## Development

### Run tests
```bash
python3 test_server.py
```

### View logs
Server logs to stdout with INFO level by default.

## License

Part of Alakeya project.
