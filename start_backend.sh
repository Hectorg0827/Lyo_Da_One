#!/bin/bash
cd /Users/hectorgarcia/Desktop/LyoBackendJune
source venv/bin/activate
# Install missing pgvector if needed (I already did it, but good for safety)
pip install pgvector > /dev/null 2>&1
echo "🚀 Starting Lyo 2.0 Backend on http://localhost:8000"
uvicorn lyo_app.main:app --reload --port 8000
