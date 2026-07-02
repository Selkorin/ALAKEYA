#!/usr/bin/env python3
"""
browser-use Service for Alakeya
FastAPI server for intelligent browser automation with browser-use library
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import os
from dotenv import load_dotenv

from models import (
    AutomateRequest, ExtractRequest, ScreenshotRequest, SearchRequest,
    SessionCreateRequest, SuccessResponse, ErrorResponse, HealthResponse
)
from session_manager import SessionManager

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

load_dotenv()

# Global managers
session_manager = None
browser_use_manager = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    global session_manager, browser_use_manager

    # Startup
    logger.info("🚀 Starting browser-use service...")

    try:
        # Initialize session manager
        session_timeout = int(os.getenv("SESSION_TIMEOUT", "3600"))
        max_sessions = int(os.getenv("MAX_SESSIONS", "10"))
        session_manager = SessionManager(session_timeout, max_sessions)
        await session_manager.start_cleanup_task()

        # Initialize browser-use manager (imported here to handle import errors gracefully)
        try:
            from browser_use_manager import BrowserUseManager
            browser_use_manager = BrowserUseManager(session_manager)
            logger.info("✅ browser-use manager initialized")
        except ImportError as e:
            logger.warning(f"browser-use not available: {e}")
            logger.warning("Service will run in limited mode")
            browser_use_manager = None

        logger.info("✅ browser-use service ready")

    except Exception as e:
        logger.error(f"Failed to start service: {e}")
        raise

    yield

    # Shutdown
    logger.info("🛑 Shutting down browser-use service...")
    if session_manager:
        await session_manager.shutdown()
    logger.info("✅ Shutdown complete")


app = FastAPI(
    title="browser-use Service for Alakeya",
    description="Intelligent browser automation with full JavaScript rendering",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    browser_use_available = browser_use_manager is not None

    try:
        import browser_use
        version = getattr(browser_use, "__version__", "unknown")
    except ImportError:
        version = None

    return HealthResponse(
        status="healthy",
        browser_use_available=browser_use_available,
        version=version
    )


@app.post("/automate", response_model=SuccessResponse)
async def automate_task(request: AutomateRequest):
    """Multi-step browser automation with AI agent"""
    if not browser_use_manager:
        raise HTTPException(status_code=503, detail="browser-use not available")

    try:
        result = await browser_use_manager.automate_task(
            task=request.task,
            session_id=request.session_id,
            options=request.options or {}
        )
        return SuccessResponse(ok=True, data=result)
    except Exception as e:
        logger.error(f"Automation error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/extract", response_model=SuccessResponse)
async def extract_data(request: ExtractRequest):
    """Extract data from URL with full JavaScript rendering"""
    if not browser_use_manager:
        raise HTTPException(status_code=503, detail="browser-use not available")

    try:
        result = await browser_use_manager.extract_data(
            url=request.url,
            goal=request.extraction_goal,
            session_id=request.session_id,
            options=request.options or {}
        )
        return SuccessResponse(ok=True, data=result)
    except Exception as e:
        logger.error(f"Extraction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/screenshot", response_model=SuccessResponse)
async def capture_screenshot(request: ScreenshotRequest):
    """Capture screenshot with full JavaScript rendering"""
    if not browser_use_manager:
        raise HTTPException(status_code=503, detail="browser-use not available")

    try:
        result = await browser_use_manager.capture_screenshot(
            url=request.url,
            session_id=request.session_id,
            options=request.options or {}
        )
        return SuccessResponse(ok=True, data=result)
    except Exception as e:
        logger.error(f"Screenshot error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/search", response_model=SuccessResponse)
async def intelligent_search(request: SearchRequest):
    """AI-powered search with automatic result extraction"""
    if not browser_use_manager:
        raise HTTPException(status_code=503, detail="browser-use not available")

    try:
        result = await browser_use_manager.intelligent_search(
            query=request.query,
            max_results=request.max_results,
            extraction_goal=request.extraction_goal,
            options=request.options or {}
        )
        return SuccessResponse(ok=True, data=result)
    except Exception as e:
        logger.error(f"Search error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/session/create", response_model=SuccessResponse)
async def create_session(request: SessionCreateRequest):
    """Create new browser session for persistence"""
    try:
        session_id = await session_manager.create_session(request.options)
        session = await session_manager.get_session(session_id)

        return SuccessResponse(ok=True, data={
            "session_id": session_id,
            "created_at": session.created_at.isoformat(),
            "message": "Session created successfully"
        })
    except Exception as e:
        logger.error(f"Session creation error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/session/{session_id}", response_model=SuccessResponse)
async def close_session(session_id: str):
    """Close browser session"""
    try:
        await session_manager.close_session(session_id)
        return SuccessResponse(ok=True, data={"message": f"Session {session_id} closed"})
    except Exception as e:
        logger.error(f"Session close error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/sessions", response_model=SuccessResponse)
async def list_sessions():
    """List all active sessions"""
    try:
        sessions = []
        for sid, session in session_manager.sessions.items():
            sessions.append({
                "session_id": sid,
                "created_at": session.created_at.isoformat(),
                "last_activity": session.last_activity.isoformat(),
                "is_active": not session.is_expired()
            })

        return SuccessResponse(ok=True, data={
            "count": len(sessions),
            "sessions": sessions
        })
    except Exception as e:
        logger.error(f"Session list error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("BROWSER_USE_HOST", "127.0.0.1")
    port = int(os.getenv("BROWSER_USE_PORT", "8001"))

    logger.info(f"Starting browser-use service on {host}:{port}")
    uvicorn.run(app, host=host, port=port, log_level="info")
