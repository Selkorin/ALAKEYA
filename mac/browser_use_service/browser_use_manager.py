"""Browser-use manager - main logic for browser automation"""
import asyncio
import base64
import re
from typing import Dict, Any, Optional, List
from playwright.async_api import async_playwright
import logging
import sys
import os

# Add current directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from browser_use import Agent
    BROWSER_USE_AVAILABLE = True
except ImportError:
    BROWSER_USE_AVAILABLE = False
    Agent = None

try:
    from fallback_search import search_without_api
    FALLBACK_SEARCH_AVAILABLE = True
except ImportError:
    FALLBACK_SEARCH_AVAILABLE = False

from session_manager import SessionManager, BrowserSession

logger = logging.getLogger(__name__)


class BrowserUseManager:
    """Manages browser-use agent operations"""

    def __init__(self, session_manager: SessionManager):
        self.session_manager = session_manager

        if not BROWSER_USE_AVAILABLE:
            logger.warning("browser-use library not available - limited functionality")

    async def _get_session(self, session_id: Optional[str]) -> BrowserSession:
        """Get existing session or create temporary one"""
        if session_id:
            return await self.session_manager.get_session(session_id)
        else:
            # Create temporary session
            temp_id = await self.session_manager.create_session({"headless": True})
            return await self.session_manager.get_session(temp_id)

    async def automate_task(
        self,
        task: str,
        session_id: Optional[str] = None,
        options: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Execute multi-step browser automation task

        Args:
            task: Natural language task description
            session_id: Optional session ID for persistence
            options: Automation options (max_steps, screenshot_every_step, etc.)

        Returns:
            Result with success status, data, screenshots, steps taken
        """
        if not BROWSER_USE_AVAILABLE:
            raise RuntimeError("browser-use library not installed")

        options = options or {}
        max_steps = options.get("max_steps", 50)
        screenshot_every_step = options.get("screenshot_every_step", False)
        timeout = options.get("wait_for_timeout", 120000) / 1000  # Convert to seconds

        logger.info(f"Automating task: {task}")

        try:
            session = await self._get_session(session_id)

            # Run automation with timeout
            result = await asyncio.wait_for(
                self._run_agent_task(session, task, max_steps),
                timeout=timeout
            )

            # Capture final screenshot if requested
            screenshot_data = None
            if screenshot_every_step and session._context:
                page = await session.get_page()
                screenshot_data = await self._capture_page_screenshot(page)

            logger.info(f"Automation completed successfully")

            return {
                "success": True,
                "task": task,
                "result": str(result)[:10000],  # Limit result length
                "screenshot": screenshot_data,
                "steps_taken": getattr(result, "steps", max_steps)
            }

        except asyncio.TimeoutError:
            logger.error(f"Automation timed out after {timeout}s")
            return {
                "success": False,
                "task": task,
                "error": f"Automation timed out after {timeout} seconds",
                "result": "Task took too long and was cancelled"
            }
        except Exception as e:
            logger.error(f"Automation failed: {e}")
            return {
                "success": False,
                "task": task,
                "error": str(e),
                "result": f"Failed due to: {str(e)[:500]}"
            }

    async def extract_data(
        self,
        url: str,
        goal: str = "extract",
        session_id: Optional[str] = None,
        options: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Extract structured data from URL with full JavaScript rendering

        Args:
            url: URL to extract from
            goal: Extraction goal (contacts, products, article, etc.)
            session_id: Optional session ID
            options: Extraction options

        Returns:
            Extracted data with title, text, contacts, screenshots, etc.
        """
        options = options or {}
        include_screenshots = options.get("include_screenshots", False)
        wait_for_dynamic = options.get("wait_for_dynamic_content", True)
        timeout = 30  # 30 seconds timeout

        logger.info(f"Extracting from {url} with goal: {goal}")

        try:
            session = await self._get_session(session_id)
            page = await session.get_page()

            # Navigate to URL with timeout
            await asyncio.wait_for(
                page.goto(url, wait_until="networkidle"),
                timeout=15.0
            )

            # Wait for dynamic content if requested
            if wait_for_dynamic:
                await page.wait_for_timeout(2000)

            # Extract page content
            title = await asyncio.wait_for(page.title(), timeout=5.0)
            content = await asyncio.wait_for(
                page.inner_text("body"),
                timeout=10.0
            )

            # Screenshot if requested
            screenshot = None
            if include_screenshots:
                screenshot = await self._capture_page_screenshot(page)

            # Use browser-use for intelligent extraction if available and goal is specific
            extracted_data = {}
            if BROWSER_USE_AVAILABLE and goal != "extract":
                try:
                    extraction_task = f"""
                    Extract {goal} from the current page at {url}.
                    Focus on: {goal}
                    Provide structured, actionable data.
                    """

                    result = await asyncio.wait_for(
                        self._run_agent_task(session, extraction_task, max_steps=15),
                        timeout=20.0
                    )
                    extracted_data = {"intelligent_extraction": str(result)[:5000]}
                except asyncio.TimeoutError:
                    logger.warning(f"Intelligent extraction timed out, using basic content")
                    extracted_data = {"basic_content": content[:10000]}
                except Exception as e:
                    logger.warning(f"Intelligent extraction failed: {e}")
                    extracted_data = {"basic_content": content[:10000]}
            else:
                extracted_data = {"basic_content": content[:10000]}

            logger.info(f"Extraction completed for {url}")

            return {
                "url": url,
                "goal": goal,
                "title": title[:300],
                "content": content[:20000],
                "screenshot": screenshot,
                "extracted_data": extracted_data
            }

        except asyncio.TimeoutError:
            logger.error(f"Extraction timed out for {url}")
            return {
                "url": url,
                "goal": goal,
                "error": f"Extraction timed out after {timeout}s",
                "title": "",
                "content": "",
                "extracted_data": {}
            }
        except Exception as e:
            logger.error(f"Extraction failed for {url}: {e}")
            return {
                "url": url,
                "goal": goal,
                "error": str(e),
                "title": "",
                "content": "",
                "extracted_data": {}
            }

    async def capture_screenshot(
        self,
        url: str,
        session_id: Optional[str] = None,
        options: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Capture screenshot with full JavaScript rendering

        Args:
            url: URL to screenshot
            session_id: Optional session ID
            options: Screenshot options (full_page, wait_for_render, etc.)

        Returns:
            Screenshot data (base64 encoded)
        """
        options = options or {}
        full_page = options.get("full_page", False)
        wait_for_render = options.get("wait_for_render", 2000)

        logger.info(f"Capturing screenshot of {url}")

        try:
            session = await self._get_session(session_id)
            page = await session.get_page()

            # Navigate to URL
            await page.goto(url, wait_until="networkidle")

            # Wait for rendering
            await page.wait_for_timeout(wait_for_render)

            # Capture screenshot
            screenshot = await self._capture_page_screenshot(page, full_page=full_page)

            logger.info(f"Screenshot captured for {url}")

            return {
                "url": url,
                "screenshot": screenshot,
                "full_page": full_page
            }

        except Exception as e:
            logger.error(f"Screenshot failed for {url}: {e}")
            raise

    async def intelligent_search(
        self,
        query: str,
        max_results: int = 5,
        extraction_goal: str = "summary",
        options: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        AI-powered search with automatic result extraction

        Args:
            query: Search query
            max_results: Maximum number of results to extract
            extraction_goal: What to extract from results
            options: Search options

        Returns:
            Search results with extracted data
        """
        options = options or {}
        include_screenshots = options.get("include_screenshots", False)

        logger.info(f"Intelligent search: {query}")

        try:
            browser_use_error = None
            # Try browser-use agent first (if API key available)
            if BROWSER_USE_AVAILABLE:
                try:
                    session = await self._get_session(None)

                    search_task = f"""
                    Perform a comprehensive search for "{query}" and extract the top {max_results} most relevant results.

                    Steps:
                    1. Navigate to a search engine (Google, DuckDuckGo, or Bing)
                    2. Search for "{query}"
                    3. Analyze the search results page
                    4. Extract the top {max_results} most relevant results including:
                       - Title
                       - URL
                       - Description/snippet
                       - Relevance score

                    5. For each top result, visit the page and extract: {extraction_goal}

                    Return a structured summary with:
                    - Total results found
                    - Top results with URLs and descriptions
                    - Extracted data from each relevant page
                    - Overall summary of findings
                    """

                    max_steps = min(max_results * 10 + 20, 100)

                    result = await asyncio.wait_for(
                        self._run_agent_task(session, search_task, max_steps),
                        timeout=60.0  # 1 minute timeout
                    )

                    # Process and structure the result
                    return {
                        "query": query,
                        "results_count": max_results,
                        "extraction_goal": extraction_goal,
                        "results": self._parse_search_results(result, max_results),
                        "summary": str(result)[:5000],
                        "method": "browser_use_agent"
                    }

                except Exception as e:
                    browser_use_error = str(e)
                    logger.warning(f"Browser-use agent search failed, using fallback when available: {e}")

            # If browser-use not available or failed, use fallback
            if FALLBACK_SEARCH_AVAILABLE:
                logger.info("Using fallback search without browser-use API")
                result = await search_without_api(query, max_results, extraction_goal)
                if browser_use_error:
                    result["browser_use_error"] = browser_use_error[:500]
                return result
            else:
                if browser_use_error:
                    raise RuntimeError(browser_use_error)
                raise RuntimeError("Neither browser-use nor fallback search available")

        except Exception as e:
            logger.error(f"Search failed: {e}")
            # Return graceful error instead of crashing
            return {
                "query": query,
                "error": str(e),
                "results_count": 0,
                "results": [],
                "method": "failed"
            }

    async def _run_agent_task(self, session, task: str, max_steps: int) -> Any:
        """Run browser-use agent task with proper error handling"""
        if not BROWSER_USE_AVAILABLE:
            raise RuntimeError("browser-use library not installed")

        try:
            agent = Agent(
                task=task,
                browser_use_kwargs={
                    "browser": session._browser,
                    "context": session._context
                }
            )

            result = await agent.run(max_steps=max_steps)
            return result
        except Exception as e:
            error_msg = str(e)
            # Check if error is about missing API key
            if "API_KEY" in error_msg or "api key" in error_msg.lower():
                logger.warning(f"Browser-use API key not configured: {e}")
                raise RuntimeError("BROWSER_USE_API_KEY is not set. Configure OPENAI_API_KEY or ANTHROPIC_API_KEY in .env file")
            else:
                raise

    async def _fallback_search(self, page, query: str, max_results: int, extraction_goal: str) -> Dict[str, Any]:
        """Fallback search using direct SERP parsing"""
        try:
            # Navigate to DuckDuckGo (privacy-focused, no JS required for basic results)
            search_url = f"https://duckduckgo.com/html/?q={query}"
            await page.goto(search_url, wait_until="networkidle", timeout=30000)
            await page.wait_for_timeout(2000)

            # Extract basic search results
            results = []
            result_elements = await page.query_selector_all(".result")

            for i, element in enumerate(result_elements[:max_results]):
                try:
                    title_elem = await element.query_selector("a.result__a")
                    if title_elem:
                        title = await title_elem.inner_text()
                        href = await title_elem.get_attribute("href")

                        if href and not href.startswith("#") and len(href) > 10:
                            results.append({
                                "rank": i + 1,
                                "title": title.strip()[:200],
                                "url": href[:500],
                                "snippet": "Basic SERP result"
                            })
                except Exception as e:
                    logger.debug(f"Failed to extract result {i}: {e}")
                    continue

            return {
                "query": query,
                "results_count": len(results),
                "results": results,
                "extraction_goal": extraction_goal,
                "method": "fallback_serp_parsing",
                "note": "Limited due to browser-use agent timeout, using basic SERP extraction"
            }
        except Exception as e:
            logger.error(f"Fallback search also failed: {e}")
            return {
                "query": query,
                "results_count": 0,
                "results": [],
                "error": str(e),
                "method": "failed"
            }

    def _parse_search_results(self, result: Any, max_results: int) -> list:
        """Parse search results from browser-use agent output"""
        # Try to extract structured data from agent result
        results = []

        try:
            result_str = str(result)

            # Simple parsing - look for URLs in the result
            import re
            url_pattern = r'https?://[^\s<>"{}|\\^`\[\]]+'
            urls = re.findall(url_pattern, result_str)[:max_results]

            for i, url in enumerate(urls):
                results.append({
                    "rank": i + 1,
                    "title": f"Result {i + 1}",
                    "url": url,
                    "snippet": result_str[:200]
                })

        except Exception as e:
            logger.debug(f"Failed to parse search results: {e}")

        return results

    async def _capture_page_screenshot(self, page, full_page: bool = False) -> str:
        """Capture screenshot and return as base64"""
        try:
            screenshot_bytes = await page.screenshot(
                full_page=full_page,
                type="png"
            )
            return base64.b64encode(screenshot_bytes).decode("utf-8")
        except Exception as e:
            logger.error(f"Screenshot capture failed: {e}")
            return ""
