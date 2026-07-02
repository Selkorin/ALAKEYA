"""Session management for browser-use service"""
import asyncio
import uuid
from datetime import datetime, timedelta
from typing import Dict, Optional
from playwright.async_api import async_playwright, Browser, BrowserContext
import logging

logger = logging.getLogger(__name__)


class BrowserSession:
    """Represents a single browser session with persistence"""

    def __init__(self, session_id: str, options: dict = None):
        self.session_id = session_id
        self.created_at = datetime.now()
        self.last_activity = datetime.now()
        self.options = options or {}
        self._browser: Optional[Browser] = None
        self._context: Optional[BrowserContext] = None
        self._playwright = None

    async def initialize(self):
        """Initialize browser context"""
        try:
            self._playwright = await async_playwright().start()
            self._browser = await self._playwright.chromium.launch(
                headless=self.options.get("headless", True)
            )
            self._context = await self._browser.new_context(
                viewport=self.options.get("viewport", {"width": 1920, "height": 1080}),
                user_agent=self.options.get("user_agent")
            )
            logger.info(f"Session {self.session_id} initialized")
        except Exception as e:
            logger.error(f"Failed to initialize session {self.session_id}: {e}")
            raise

    async def get_context(self) -> BrowserContext:
        """Get or create browser context"""
        if not self._context:
            await self.initialize()
        self.last_activity = datetime.now()
        return self._context

    async def get_page(self):
        """Get or create a new page"""
        context = await self.get_context()
        if not context.pages:
            return await context.new_page()
        return context.pages[-1]

    async def cleanup(self):
        """Cleanup browser resources"""
        try:
            if self._context:
                await self._context.close()
            if self._browser:
                await self._browser.close()
            if self._playwright:
                await self._playwright.stop()
            logger.info(f"Session {self.session_id} cleaned up")
        except Exception as e:
            logger.error(f"Error cleaning up session {self.session_id}: {e}")

    def is_expired(self, timeout_seconds: int = 3600) -> bool:
        """Check if session is expired"""
        expiry_time = self.last_activity + timedelta(seconds=timeout_seconds)
        return datetime.now() > expiry_time


class SessionManager:
    """Manages multiple browser sessions"""

    def __init__(self, session_timeout: int = 3600, max_sessions: int = 10):
        self.sessions: Dict[str, BrowserSession] = {}
        self.session_timeout = session_timeout
        self.max_sessions = max_sessions
        self._cleanup_task: Optional[asyncio.Task] = None

    async def create_session(self, options: dict = None) -> str:
        """Create new browser session"""
        if len(self.sessions) >= self.max_sessions:
            await self.cleanup_expired_sessions()
            if len(self.sessions) >= self.max_sessions:
                raise Exception(f"Maximum sessions limit reached: {self.max_sessions}")

        session_id = str(uuid.uuid4())
        session = BrowserSession(session_id, options)
        await session.initialize()
        self.sessions[session_id] = session

        logger.info(f"Created session {session_id}, active: {len(self.sessions)}")
        return session_id

    async def get_session(self, session_id: str) -> BrowserSession:
        """Get existing session"""
        if session_id not in self.sessions:
            raise ValueError(f"Session not found: {session_id}")

        session = self.sessions[session_id]
        if session.is_expired(self.session_timeout):
            await self.close_session(session_id)
            raise ValueError(f"Session expired: {session_id}")

        return session

    async def close_session(self, session_id: str):
        """Close and cleanup session"""
        if session_id in self.sessions:
            await self.sessions[session_id].cleanup()
            del self.sessions[session_id]
            logger.info(f"Closed session {session_id}, active: {len(self.sessions)}")

    async def cleanup_expired_sessions(self):
        """Cleanup all expired sessions"""
        expired = [
            sid for sid, session in self.sessions.items()
            if session.is_expired(self.session_timeout)
        ]

        for sid in expired:
            await self.close_session(sid)

        if expired:
            logger.info(f"Cleaned up {len(expired)} expired sessions")

    async def start_cleanup_task(self, interval: int = 300):
        """Start periodic cleanup task"""
        if self._cleanup_task is None or self._cleanup_task.done():

            async def cleanup_loop():
                while True:
                    try:
                        await asyncio.sleep(interval)
                        await self.cleanup_expired_sessions()
                    except asyncio.CancelledError:
                        break
                    except Exception as e:
                        logger.error(f"Cleanup task error: {e}")

            self._cleanup_task = asyncio.create_task(cleanup_loop())
            logger.info("Started session cleanup task")

    async def stop_cleanup_task(self):
        """Stop periodic cleanup task"""
        if self._cleanup_task and not self._cleanup_task.done():
            self._cleanup_task.cancel()
            try:
                await self._cleanup_task
            except asyncio.CancelledError:
                pass
            logger.info("Stopped session cleanup task")

    async def shutdown(self):
        """Cleanup all sessions"""
        await self.stop_cleanup_task()
        for session_id in list(self.sessions.keys()):
            await self.close_session(session_id)
        logger.info("Session manager shutdown complete")
