#!/bin/bash
# Start browser-use service

cd "$(dirname "$0")"

# Check if virtual environment exists
if [ ! -d "../.venv/browser_use" ]; then
    echo "❌ browser-use virtual environment not found"
    echo "Run setup first:"
    echo "  cd /Users/werni/Selkorin/mac"
    echo "  bash scripts/setup_browser_use.sh"
    exit 1
fi

# Activate virtual environment
source "../.venv/browser_use/bin/activate"

# Check if browser-use is installed
python3 -c "import browser_use" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ browser-use not installed"
    echo "Run setup first:"
    echo "  cd /Users/werni/Selkorin/mac"
    echo "  bash scripts/setup_browser_use.sh"
    exit 1
fi

# Start server
echo "🚀 Starting browser-use service..."
python3 server.py
