#!/bin/bash
# Setup script for browser-use integration

set -e

echo "🚀 Setting up browser-use integration..."

cd "$(dirname "$0")/.."

# Check Python 3.11+
PYTHON_CMD=""
for cmd in python3.12 python3.13 python3.11 python3; do
    if command -v $cmd &> /dev/null; then
        PYTHON_VERSION=$($cmd --version 2>&1 | awk '{print $2}')
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

        if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 11 ]; then
            PYTHON_CMD=$cmd
            echo "✅ Python $PYTHON_VERSION found: $cmd"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "❌ Python 3.11+ not found (required for browser-use)"
    echo "Found: $(python3 --version 2>&1)"
    echo "Install Python 3.11+: brew install python@3.12"
    exit 1
fi

# Create virtual environment
if [ -d ".venv/browser_use" ]; then
    echo "ℹ️  Virtual environment already exists at .venv/browser_use"
else
    echo "📦 Creating virtual environment with $PYTHON_CMD..."
    $PYTHON_CMD -m venv .venv/browser_use
    echo "✅ Virtual environment created"
fi

# Activate virtual environment
source .venv/browser_use/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📦 Installing dependencies..."
pip install browser-use playwright fastapi uvicorn pydantic python-dotenv

echo "✅ Dependencies installed"

# Install Playwright browsers
echo "🌐 Installing Playwright browsers..."
playwright install chromium

echo "✅ Playwright Chromium installed"

# Install system dependencies for Playwright (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "ℹ️  macOS detected - system dependencies usually not required"
else
    echo "📦 Installing system dependencies..."
    playwright install-deps chromium
fi

# Verify installation
echo "🔍 Verifying installation..."

$PYTHON_CMD -c "
import browser_use
import playwright
import fastapi
print('✅ All packages imported successfully')
print(f'   browser-use: {getattr(browser_use, \"__version__\", \"unknown\")}')
print(f'   playwright: {getattr(playwright, \"__version__\", \"unknown\")}')
print(f'   fastapi: {getattr(fastapi, \"__version__\", \"unknown\")}')
"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ browser-use setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Configure environment:"
    echo "   cd browser_use_service"
    echo "   cp .env.example .env"
    echo "   # Edit .env with your API keys"
    echo ""
    echo "2. Start server:"
    echo "   cd browser_use_service"
    echo "   bash start_server.sh"
    echo ""
    echo "Server will run on http://127.0.0.1:8001"
else
    echo "❌ Verification failed"
    exit 1
fi
