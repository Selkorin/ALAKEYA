#!/usr/bin/env python3
"""
Fallback search without browser-use API key
Uses HTTP requests + beautifulsoup4 for basic search results extraction
"""

import asyncio
import urllib.parse
import re
import json
from typing import Dict, Any, List
from urllib.request import urlopen, Request
from urllib.error import URLError
import logging

logger = logging.getLogger(__name__)

try:
    from bs4 import BeautifulSoup
    BS4_AVAILABLE = True
except ImportError:
    BS4_AVAILABLE = False


async def search_without_api(
    query: str,
    max_results: int = 5,
    extraction_goal: str = "summary"
) -> Dict[str, Any]:
    """
    Fallback search without browser-use API

    Args:
        query: Search query
        max_results: Maximum number of results
        extraction_goal: What to extract from results

    Returns:
        Search results with extracted data
    """

    logger.info(f"Fallback search without API: {query}")

    try:
        # Use multiple search engines for better results
        search_engines = [
            ("DuckDuckGo", f"https://duckduckgo.com/html/?q={urllib.parse.quote(query)}"),
            ("Bing", f"https://www.bing.com/search?q={urllib.parse.quote(query)}"),
        ]

        all_results = []

        for engine_name, search_url in search_engines:
            try:
                logger.info(f"Trying {engine_name}")

                # Make request
                req = Request(
                    search_url,
                    headers={
                        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
                        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                        "Accept-Language": "en-US,en;q=0.9",
                    }
                )

                with urlopen(req, timeout=15) as response:
                    html = response.read().decode('utf-8', errors='replace')

                # Parse HTML if bs4 available
                if BS4_AVAILABLE:
                    soup = BeautifulSoup(html, 'html.parser')

                    # DuckDuckGo HTML results
                    if "duckduckgo" in search_url:
                        results = parse_duckduckgo_html(soup, max_results)
                    # Bing results
                    elif "bing.com" in search_url:
                        results = parse_bing_html(soup, max_results)
                    else:
                        results = []

                    all_results.extend(results)

                    if len(all_results) >= max_results:
                        break
                else:
                    # Fallback to regex parsing
                    results = parse_with_regex(html, max_results)
                    all_results.extend(results)

            except Exception as e:
                logger.warning(f"{engine_name} search failed: {e}")
                continue

        # Remove duplicates and limit results
        unique_results = []
        seen_urls = set()
        for result in all_results:
            if result['url'] not in seen_urls:
                seen_urls.add(result['url'])
                unique_results.append(result)
                if len(unique_results) >= max_results:
                    break

        logger.info(f"Fallback search found {len(unique_results)} results")

        return {
            "query": query,
            "results_count": len(unique_results),
            "results": unique_results[:max_results],
            "extraction_goal": extraction_goal,
            "method": "fallback_http_search",
            "note": "Results from basic HTTP search without browser-use API"
        }

    except Exception as e:
        logger.error(f"Fallback search failed: {e}")
        return {
            "query": query,
            "results_count": 0,
            "results": [],
            "error": str(e),
            "method": "failed"
        }


def parse_duckduckgo_html(soup, max_results: int) -> List[Dict[str, Any]]:
    """Parse DuckDuckGo HTML search results"""
    results = []

    try:
        # DuckDuckGo HTML uses specific classes
        result_divs = soup.find_all('div', class_='result')

        for div in result_divs[:max_results]:
            try:
                link = div.find('a', class_='result__a')
                if link:
                    title = link.get_text(strip=True)
                    url = link.get('href', '')

                    if url and not url.startswith('#'):
                        # Get snippet
                        snippet_elem = div.find('a', class_='result__snippet')
                        snippet = snippet_elem.get_text(strip=True) if snippet_elem else ''

                        results.append({
                            'rank': len(results) + 1,
                            'title': title[:200],
                            'url': url[:500],
                            'snippet': snippet[:300]
                        })
            except Exception as e:
                logger.debug(f"Failed to parse result: {e}")
                continue

    except Exception as e:
        logger.error(f"DuckDuckGo parsing failed: {e}")

    return results


def parse_bing_html(soup, max_results: int) -> List[Dict[str, Any]]:
    """Parse Bing HTML search results"""
    results = []

    try:
        # Bing uses specific classes
        result_divs = soup.find_all('li', class_='b_algo')

        for div in result_divs[:max_results]:
            try:
                link = div.find('a')
                if link:
                    title = link.get_text(strip=True)
                    url = link.get('href', '')

                    if url and not url.startswith('#') and not url.startswith('/'):
                        # Get snippet
                        snippet_div = div.find('div', class_='b_caption')
                        snippet = snippet_div.get_text(strip=True) if snippet_div else ''

                        results.append({
                            'rank': len(results) + 1,
                            'title': title[:200],
                            'url': url[:500],
                            'snippet': snippet[:300]
                        })
            except Exception as e:
                logger.debug(f"Failed to parse result: {e}")
                continue

    except Exception as e:
        logger.error(f"Bing parsing failed: {e}")

    return results


def parse_with_regex(html: str, max_results: int) -> List[Dict[str, Any]]:
    """Fallback regex-based parsing when bs4 unavailable"""
    results = []

    try:
        # Simple regex to find URLs and titles in HTML
        url_pattern = r'href=[\'"]?([^\'" >]+)[\'"]?'
        title_pattern = r'<a[^>]*>([^<]+)</a>'

        urls = re.findall(url_pattern, html)[:max_results * 2]
        titles = re.findall(title_pattern, html)[:max_results * 2]

        for i in range(min(len(urls), max_results)):
            url = urls[i] if i < len(urls) else ""
            title = titles[i] if i < len(titles) else f"Result {i+1}"

            if url and not url.startswith('#') and len(url) > 10:
                results.append({
                    'rank': i + 1,
                    'title': title[:200],
                    'url': url[:500],
                    'snippet': 'Basic parsing'
                })

    except Exception as e:
        logger.error(f"Regex parsing failed: {e}")

    return results


# Test function
if __name__ == "__main__":
    async def test():
        result = await search_without_api("Python programming", 3, "summary")
        print(json.dumps(result, indent=2, ensure_ascii=False))

    asyncio.run(test())
