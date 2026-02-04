#!/usr/bin/env bash
# Start both FastAPI backend and Next.js frontend for development
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Starting Review Tool...${NC}"
echo ""

# Activate venv if it exists
if [ -d "$PROJECT_ROOT/.venv" ]; then
  source "$PROJECT_ROOT/.venv/bin/activate"
fi

# Start FastAPI backend
echo -e "${BLUE}[Backend]${NC} Starting FastAPI on http://localhost:8000"
cd "$SCRIPT_DIR"
python -m uvicorn api.main:app --reload --port 8000 &
BACKEND_PID=$!

# Start Next.js frontend
echo -e "${BLUE}[Frontend]${NC} Starting Next.js on http://localhost:3000"
cd "$SCRIPT_DIR"
pnpm dev &
FRONTEND_PID=$!

echo ""
echo -e "${GREEN}Review Tool running:${NC}"
echo "  Frontend: http://localhost:3000"
echo "  Backend:  http://localhost:8000"
echo ""
echo "Press Ctrl+C to stop both servers"

# Cleanup on exit
cleanup() {
  echo ""
  echo "Shutting down..."
  kill $BACKEND_PID 2>/dev/null
  kill $FRONTEND_PID 2>/dev/null
  wait $BACKEND_PID 2>/dev/null
  wait $FRONTEND_PID 2>/dev/null
  echo "Done."
}
trap cleanup EXIT INT TERM

# Wait for both processes
wait
