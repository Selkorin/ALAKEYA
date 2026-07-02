#!/usr/bin/env python3
import argparse
import concurrent.futures
import html.parser
import json
import re
import ssl
import urllib.parse
import urllib.request
import sys
import os
import time


USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
)
ACCEPT_LANGUAGE = "ru-RU,ru;q=0.9,en-US;q=0.7,en;q=0.6"
POLITE_FETCH_DELAY_SECONDS = float(os.environ.get("ALAKEYA_POLITE_FETCH_DELAY", "1.6"))
ALLOW_GOOGLE_SEARCH = os.environ.get("ALAKEYA_ALLOW_GOOGLE_SEARCH", "").lower() in {"1", "true", "yes"}


class PageParser(html.parser.HTMLParser):
    def __init__(self, base_url: str, max_links: int):
        super().__init__(convert_charrefs=True)
        self.base_url = base_url
        self.max_links = max_links
        self.title = ""
        self.meta = {}
        self.links = []
        self.headings = []
        self.text_parts = []
        self.json_ld = []
        self._tag_stack = []
        self._capture_title = False
        self._capture_script = False
        self._script_type = ""
        self._script_buffer = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self._tag_stack.append(tag)
        if tag == "title":
            self._capture_title = True
        elif tag == "meta":
            key = attrs.get("name") or attrs.get("property") or attrs.get("itemprop")
            content = attrs.get("content")
            if key and content:
                self.meta[key[:80]] = clean_text(content)[:1000]
        elif tag == "a":
            href = attrs.get("href")
            if href and len(self.links) < self.max_links:
                url = urllib.parse.urljoin(self.base_url, href)
                self.links.append({"url": url, "text": ""})
        elif tag in {"h1", "h2", "h3"}:
            self.headings.append({"level": tag, "text": ""})
        elif tag == "script":
            self._script_type = attrs.get("type", "")
            self._capture_script = self._script_type.lower() == "application/ld+json"
            self._script_buffer = []

    def handle_endtag(self, tag):
        if tag == "title":
            self._capture_title = False
        if tag == "script" and self._capture_script:
            raw = "".join(self._script_buffer).strip()
            if raw:
                try:
                    self.json_ld.append(json.loads(raw))
                except Exception:
                    self.json_ld.append(raw[:4000])
            self._capture_script = False
            self._script_buffer = []
        if self._tag_stack:
            self._tag_stack.pop()

    def handle_data(self, data):
        text = clean_text(data or "")
        if not text:
            return
        if self._capture_title:
            self.title = (self.title + " " + text).strip()
        if self._capture_script:
            self._script_buffer.append(data)
            return
        if self._tag_stack and self._tag_stack[-1] == "a" and self.links:
            current = self.links[-1]
            current["text"] = (current.get("text", "") + " " + text).strip()[:240]
        if self._tag_stack and self._tag_stack[-1] in {"h1", "h2", "h3"} and self.headings:
            self.headings[-1]["text"] = (self.headings[-1]["text"] + " " + text).strip()[:300]
        if self._tag_stack and self._tag_stack[-1] not in {"script", "style", "noscript"}:
            self.text_parts.append(text)


class LinkParser(html.parser.HTMLParser):
    def __init__(self, base_url: str):
        super().__init__(convert_charrefs=True)
        self.base_url = base_url
        self.links = []
        self._current = None

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        attrs = dict(attrs)
        href = attrs.get("href")
        if not href:
            return
        self._current = {"url": urllib.parse.urljoin(self.base_url, href), "title": ""}
        self.links.append(self._current)

    def handle_endtag(self, tag):
        if tag == "a":
            self._current = None

    def handle_data(self, data):
        if not self._current:
            return
        text = clean_text(data or "")
        if text:
            self._current["title"] = (self._current["title"] + " " + text).strip()[:300]


class SearchHTMLParser(html.parser.HTMLParser):
    def __init__(self, base_url: str):
        super().__init__(convert_charrefs=True)
        self.base_url = base_url
        self.results = []
        self._current = None
        self._tag_stack = []
        self._class_stack = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = set((attrs.get("class") or "").split())
        self._tag_stack.append(tag)
        self._class_stack.append(classes)

        if tag == "a":
            href = attrs.get("href") or ""
            class_text = " ".join(classes)
            clean_url = clean_search_href(urllib.parse.urljoin(self.base_url, href))
            if not clean_url:
                return
            is_result_link = (
                "result-link" in classes
                or "result__a" in classes
                or "b_algo" in class_text
                or "/l/?" in href
                or self._inside_class("b_algo")
            )
            if is_result_link:
                self._current = {"title": "", "url": clean_url, "snippet": ""}
                self.results.append(self._current)

    def handle_endtag(self, tag):
        if tag == "a" and self._current and self._current.get("title"):
            self._current = None
        if self._tag_stack:
            self._tag_stack.pop()
        if self._class_stack:
            self._class_stack.pop()

    def handle_data(self, data):
        text = clean_text(data or "")
        if not text:
            return
        if self._current is not None:
            if self._tag_stack and self._tag_stack[-1] == "a":
                self._current["title"] = (self._current.get("title", "") + " " + text).strip()[:260]
            elif self._looks_like_snippet(text):
                self._current["snippet"] = (self._current.get("snippet", "") + " " + text).strip()[:500]
            return

        if self.results and self._looks_like_snippet(text):
            last = self.results[-1]
            if not last.get("snippet"):
                last["snippet"] = text[:500]

    def _inside_class(self, class_name: str) -> bool:
        return any(class_name in classes for classes in self._class_stack)

    @staticmethod
    def _looks_like_snippet(text: str) -> bool:
        if len(text) < 35:
            return False
        blocked = {"cached", "similar", "translate", "images", "videos", "settings"}
        return text.lower() not in blocked


def clean_text(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip()


def normalize_url(value: str) -> str:
    value = value.strip()
    if not re.match(r"^https?://", value, re.I):
        value = "https://" + value
    return value


def fetch(url: str, timeout: float) -> tuple[str, str]:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": ACCEPT_LANGUAGE,
            "DNT": "1",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            final_url = resp.geturl()
            charset = resp.headers.get_content_charset() or "utf-8"
            body = resp.read(2_500_000).decode(charset, errors="replace")
            return final_url, body
    except urllib.error.URLError as exc:
        if "CERTIFICATE_VERIFY_FAILED" not in str(exc):
            raise
        ctx = ssl._create_unverified_context()
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            final_url = resp.geturl()
            charset = resp.headers.get_content_charset() or "utf-8"
            body = resp.read(2_500_000).decode(charset, errors="replace")
            return final_url, body


def extract_contacts(text: str) -> dict:
    emails = sorted(set(re.findall(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+", text)))[:30]
    phone_candidates = re.findall(r"(?:\+?\d[\d\s().-]{7,}\d)", text)
    phones = []
    seen_phones = set()
    for candidate in phone_candidates:
        value = clean_text(candidate)
        digits = re.sub(r"\D", "", value)
        if not 10 <= len(digits) <= 15:
            continue
        if re.fullmatch(r"\d{4}[-/.]\d{2}[-/.]\d{2}", value):
            continue
        if value.isdigit() and not value.startswith(("7", "8")):
            continue
        if value not in seen_phones:
            seen_phones.add(value)
            phones.append(value)
    phones = sorted(phones)[:30]
    social_patterns = {
        "telegram": r"https?://(?:t\.me|telegram\.me)/[^\s\"'<>]+",
        "whatsapp": r"https?://(?:wa\.me|api\.whatsapp\.com)/[^\s\"'<>]+",
        "instagram": r"https?://(?:www\.)?instagram\.com/[^\s\"'<>]+",
        "vk": r"https?://(?:www\.)?vk\.com/[^\s\"'<>]+",
        "youtube": r"https?://(?:www\.)?youtube\.com/[^\s\"'<>]+",
    }
    socials = {
        name: sorted(set(re.findall(pattern, text, re.I)))[:20]
        for name, pattern in social_patterns.items()
    }
    return {"emails": emails, "phones": phones, "socials": socials}


def looks_like_bot_challenge(text: str) -> bool:
    value = (text or "").lower()
    patterns = [
        r"captcha|капч[аиу]",
        r"подтвердите[, ]+что",
        r"не робот",
        r"verify you are human",
        r"unusual traffic",
        r"access denied|доступ ограничен",
    ]
    return any(re.search(pattern, value, re.I) for pattern in patterns)


def page_quality(page: dict) -> dict:
    text = page.get("text") or ""
    contacts = page.get("contacts") or {}
    score = 20
    reasons = []
    if page.get("ok"):
        score += 10
    if page.get("json_ld"):
        score += 18
        reasons.append("json-ld")
    if contacts.get("phones") or contacts.get("emails"):
        score += 16
        reasons.append("contacts")
    if len(text) > 800:
        score += 10
        reasons.append("content")
    if looks_like_bot_challenge(" ".join([page.get("title", ""), page.get("description", ""), text])):
        score -= 50
        reasons.append("bot-challenge")
    if page.get("error"):
        score -= 20
        reasons.append("error")
    score = max(0, min(100, score))
    return {"score": score, "reasons": reasons, "usable": score >= 25 and "bot-challenge" not in reasons}


def browser_use_available() -> bool:
    try:
        __import__("browser_use")
        return True
    except Exception:
        return False


def emit_progress(message: str):
    print(f"PROGRESS:{message}", file=sys.stderr, flush=True)


def parse_page(url: str, goal: str, max_links: int, max_text_chars: int, timeout: float) -> dict:
    try:
        final_url, html = fetch(normalize_url(url), timeout)
        parser = PageParser(final_url, max_links)
        parser.feed(html)
        visible_text = clean_text(" ".join(parser.text_parts))
        description = parser.meta.get("description") or parser.meta.get("og:description") or ""
        link_blob = "\n".join(
            f"{link.get('url', '')} {link.get('text', '')}"
            for link in parser.links
        )
        contacts = extract_contacts("\n".join([parser.title, description, visible_text, link_blob]))
        challenge = looks_like_bot_challenge("\n".join([parser.title, description, visible_text]))
        page = {
            "ok": True,
            "url": final_url,
            "goal": goal,
            "title": parser.title[:300],
            "description": description,
            "meta": parser.meta,
            "headings": [h for h in parser.headings if h.get("text")][:60],
            "contacts": contacts,
            "links": dedupe_links([l for l in parser.links if l.get("url")])[:max_links],
            "json_ld": parser.json_ld[:12],
            "text": visible_text[:max_text_chars],
        }
        if challenge:
            page["ok"] = False
            page["error"] = "bot_challenge"
        page["quality"] = page_quality(page)
        return page
    except Exception as exc:
        return {
            "ok": False,
            "url": url,
            "goal": goal,
            "error": str(exc),
            "title": "",
            "description": "",
            "headings": [],
            "contacts": {"emails": [], "phones": [], "socials": {}},
            "links": [],
            "json_ld": [],
            "text": "",
            "quality": {"score": 0, "reasons": ["error"], "usable": False},
        }


def dedupe_links(links):
    seen = set()
    out = []
    for link in links:
        url = link.get("url", "")
        if not url or url in seen:
            continue
        seen.add(url)
        out.append(link)
    return out


def clean_search_href(href: str) -> str:
    if not href:
        return ""
    parsed = urllib.parse.urlparse(href)
    if parsed.netloc.endswith("duckduckgo.com") and parsed.path.startswith("/l/"):
        uddg = urllib.parse.parse_qs(parsed.query).get("uddg", [""])[0]
        if uddg:
            href = urllib.parse.unquote(uddg)
            parsed = urllib.parse.urlparse(href)
    if parsed.netloc.endswith("google.com") and parsed.path.startswith("/url"):
        target = (
            urllib.parse.parse_qs(parsed.query).get("q", [""])[0]
            or urllib.parse.parse_qs(parsed.query).get("url", [""])[0]
        )
        if target:
            href = urllib.parse.unquote(target)
            parsed = urllib.parse.urlparse(href)
    if parsed.netloc.endswith("bing.com") and parsed.path.startswith("/ck/"):
        return ""
    if parsed.scheme not in {"http", "https"}:
        return ""
    host = parsed.netloc.lower()
    blocked_hosts = (
        "duckduckgo.com",
        "bing.com",
        "google.com",
        "mojeek.com",
        "search.brave.com",
        "yep.com",
        "ecosia.org",
        "swisscows.com",
        "yandex.",
        "rambler.ru",
    )
    if any(blocked in host for blocked in blocked_hosts):
        return ""
    if re.search(r"\.(?:css|js|png|jpg|jpeg|gif|svg|ico|webp|woff2?)$", parsed.path, re.I):
        return ""
    return urllib.parse.urlunparse(parsed._replace(fragment=""))


def search_terms(query: str) -> list[str]:
    return [
        term.lower()
        for term in re.findall(r"[\wа-яА-ЯёЁ]{3,}", query, re.U)
        if term.lower() not in {"как", "что", "это", "для", "the", "and", "with"}
    ]


def result_score(result: dict, terms: list[str], engine_index: int) -> int:
    title = (result.get("title") or "").lower()
    snippet = (result.get("snippet") or "").lower()
    host = urllib.parse.urlparse(result.get("url") or "").netloc.lower()
    score = max(0, 40 - engine_index * 4)
    score += sum(12 for term in terms if term in title)
    score += sum(5 for term in terms if term in snippet)
    if host.startswith("www."):
        host = host[4:]
    host_labels = set(re.split(r"[\W_]+", host))
    authoritative_domain_terms = {
        "github", "gitlab", "wikipedia", "youtube", "linkedin",
        "twitter", "x", "vk", "telegram", "reddit",
    }
    for term in terms:
        if term in host_labels:
            score += 30 if term in authoritative_domain_terms else 18
        elif term in host:
            score += 8
    path_depth = len([part for part in urllib.parse.urlparse(result.get("url") or "").path.split("/") if part])
    if path_depth > 2:
        score -= min(18, (path_depth - 2) * 5)
    if host:
        score += 2
    return score


def result_relevant(result: dict, terms: list[str]) -> bool:
    if not terms:
        return True
    parsed = urllib.parse.urlparse(result.get("url") or "")
    haystack = " ".join([
        result.get("title") or "",
        result.get("snippet") or "",
        parsed.netloc,
        parsed.path,
    ]).lower()
    return any(term in haystack for term in terms)


def normalize_result_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    host = parsed.netloc.lower()
    path = parsed.path.rstrip("/") or "/"
    return urllib.parse.urlunparse(parsed._replace(netloc=host, path=path, query="", fragment=""))


def parse_search_results(engine: str, final_url: str, html: str, max_results: int) -> list[dict]:
    parser = SearchHTMLParser(final_url)
    parser.feed(html)
    results = []
    seen = set()

    # First pass: engine-aware parser with snippets.
    for item in parser.results:
        url = clean_search_href(item.get("url", ""))
        title = clean_text(item.get("title", ""))
        if not url or not title:
            continue
        key = normalize_result_url(url)
        if key in seen:
            continue
        seen.add(key)
        results.append({
            "title": title[:240],
            "url": url,
            "snippet": clean_text(item.get("snippet", ""))[:500],
            "source_engine": engine,
        })
        if len(results) >= max_results:
            return results

    # Second pass: generic links, useful when search markup changes.
    link_parser = LinkParser(final_url)
    link_parser.feed(html)
    for item in link_parser.links:
        url = clean_search_href(item.get("url", ""))
        title = clean_text(item.get("title", ""))
        if not url or not title:
            continue
        key = normalize_result_url(url)
        if key in seen:
            continue
        seen.add(key)
        results.append({
            "title": title[:240],
            "url": url,
            "snippet": "",
            "source_engine": engine,
        })
        if len(results) >= max_results:
            break
    return results


def strip_markdown(value: str) -> str:
    value = re.sub(r"!\[[^\]]*\]\([^)]+\)", " ", value or "")
    value = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", value)
    value = re.sub(r"[*_`#>]+", " ", value)
    return clean_text(value)


def parse_markdown_search_results(engine: str, markdown: str, max_results: int) -> list[dict]:
    heading_re = re.compile(r"^##\s+\[(.+?)\]\((.+?)\)\s*$", re.M)
    matches = list(heading_re.finditer(markdown or ""))
    results = []
    seen = set()
    for index, match in enumerate(matches):
        title = strip_markdown(match.group(1))
        url = clean_search_href(match.group(2))
        if not title or not url:
            continue
        key = normalize_result_url(url)
        if key in seen:
            continue
        next_start = matches[index + 1].start() if index + 1 < len(matches) else len(markdown)
        section = markdown[match.end():next_start]
        snippet = ""
        for line in section.splitlines():
            cleaned = strip_markdown(line)
            if len(cleaned) < 35:
                continue
            lower = cleaned.lower()
            if lower.startswith(("image ", "title:", "url source:", "markdown content:")):
                continue
            if re.fullmatch(r"[\w.-]+\.[a-zа-я]{2,}(?:\s+[\w./-]+)?", lower):
                continue
            snippet = cleaned[:500]
            break
        seen.add(key)
        results.append({
            "title": title[:240],
            "url": url,
            "snippet": snippet,
            "source_engine": engine,
        })
        if len(results) >= max_results:
            break
    return results


def search_with_jina_duckduckgo(query: str, max_results: int, timeout: float) -> list[dict]:
    encoded = urllib.parse.urlencode({"q": query})
    url = "https://r.jina.ai/http://https://duckduckgo.com/html/?" + encoded
    final_url, markdown = fetch(url, max(timeout, 12))
    return parse_markdown_search_results("jina_duckduckgo", markdown, max_results)


def search_web(query: str, max_results: int, timeout: float) -> dict:
    encoded = urllib.parse.urlencode({"q": query})
    google_encoded = urllib.parse.urlencode({"q": query, "num": min(max_results * 2, 20)})
    engines = [
        ("duckduckgo_lite", "https://lite.duckduckgo.com/lite/?" + encoded),
        ("duckduckgo_html", "https://duckduckgo.com/html/?" + encoded),
        ("bing", "https://www.bing.com/search?" + encoded),
        ("mojeek", "https://www.mojeek.com/search?" + encoded),
    ]
    if ALLOW_GOOGLE_SEARCH:
        engines.append(("google", "https://www.google.com/search?" + google_encoded))
    errors = []
    all_results = []
    seen = set()
    terms = search_terms(query)

    def fetch_engine(engine_index: int, engine: str, url: str):
        try:
            final_url, html = fetch(url, timeout)
            results = parse_search_results(engine, final_url, html, max_results * 2)
            return {"engine_index": engine_index, "engine": engine, "results": results, "error": ""}
        except Exception as exc:
            return {"engine_index": engine_index, "engine": engine, "results": [], "error": str(exc)}

    engine_counts = {}
    for engine_index, (engine, url) in enumerate(engines):
        payload = fetch_engine(engine_index, engine, url)
        engine = payload["engine"]
        results = payload["results"]
        engine_counts[engine] = len(results)
        if payload["error"]:
            errors.append(f"{engine}: {payload['error']}")
        elif not results:
            errors.append(f"{engine}: no usable results")
        else:
            for item in results:
                key = normalize_result_url(item["url"])
                if key in seen:
                    continue
                if not result_relevant(item, terms):
                    continue
                seen.add(key)
                item["score"] = result_score(item, terms, engine_index)
                all_results.append(item)
        time.sleep(POLITE_FETCH_DELAY_SECONDS)

    if len(all_results) < max_results:
        try:
            emit_progress("Проверяю резервный markdown-поиск DuckDuckGo…")
            fallback_results = search_with_jina_duckduckgo(
                query,
                max_results=max_results * 2,
                timeout=max(timeout, 12),
            )
            engine_counts["jina_duckduckgo"] = len(fallback_results)
            for item in fallback_results:
                key = normalize_result_url(item["url"])
                if key in seen:
                    continue
                if not result_relevant(item, terms):
                    continue
                seen.add(key)
                item["score"] = result_score(item, terms, len(engines))
                all_results.append(item)
        except Exception as exc:
            engine_counts["jina_duckduckgo"] = 0
            errors.append(f"jina_duckduckgo: {exc}")

    all_results.sort(key=lambda item: item.get("score", 0), reverse=True)
    results = all_results[:max_results]
    if results:
        return {
            "ok": True,
            "engine": "multi",
            "engines": [engine for engine, _ in engines],
            "query_terms": terms,
            "results": results,
            "engine_counts": engine_counts,
            "errors": errors,
        }
    return {"ok": False, "engine": "multi", "results": [], "errors": errors}


def flatten_socials(socials: dict) -> str:
    parts = []
    for key in sorted(socials.keys()):
        values = socials.get(key) or []
        if values:
            parts.append(f"{key}: " + ", ".join(values[:3]))
    return "; ".join(parts)


def first_heading(page: dict, level: str = "h1") -> str:
    for heading in page.get("headings", []):
        if heading.get("level") == level and heading.get("text"):
            return heading.get("text", "")
    return ""


def page_to_row(page: dict) -> list[str]:
    contacts = page.get("contacts") or {}
    quality = page.get("quality") or {}
    return [
        page.get("title", ""),
        page.get("url", ""),
        page.get("description", ""),
        first_heading(page),
        ", ".join(contacts.get("emails") or []),
        ", ".join(contacts.get("phones") or []),
        flatten_socials(contacts.get("socials") or {}),
        str(quality.get("score", "")),
        page.get("error", ""),
    ]


def result_to_row(result: dict) -> list[str]:
    return [
        result.get("title", ""),
        result.get("url", ""),
        result.get("snippet", ""),
        "",
        "",
        "",
        "",
        str(result.get("score", "")),
        "",
    ]


def extract_many(results, goal: str, max_links: int, max_text_chars: int, timeout: float):
    pages = []
    if not results:
        return pages
    for item in results:
        host = urllib.parse.urlparse(item.get("url", "")).netloc or item.get("url", "")
        title = clean_text(item.get("title", ""))[:70]
        emit_progress(f"Открываю источник: {host} — {title}")
        page = parse_page(item["url"], goal, max_links, max_text_chars, timeout)
        page["search_result"] = item
        pages.append(page)
        time.sleep(POLITE_FETCH_DELAY_SECONDS)
    order = {item["url"]: idx for idx, item in enumerate(results)}
    pages.sort(key=lambda page: order.get((page.get("search_result") or {}).get("url", ""), 9999))
    return pages


def compact_page(page: dict) -> dict:
    return {
        "ok": page.get("ok"),
        "url": page.get("url", ""),
        "goal": page.get("goal", ""),
        "title": page.get("title", ""),
        "description": page.get("description", ""),
        "headings": (page.get("headings") or [])[:50],
        "contacts": page.get("contacts") or {"emails": [], "phones": [], "socials": {}},
        "quality": page.get("quality") or {},
        "text": page.get("text", ""),
        "error": page.get("error", ""),
        "search_result": page.get("search_result") or {},
    }


def build_common(args) -> dict:
    return {
        "engine": "browser-use-compatible-fast-extractor",
        "browser_use_available": browser_use_available(),
        "mode": args.mode,
        "goal": args.goal,
        "notes": [
            "Read-only fast parser.",
            "Search layer returns export-ready headers/rows for export_csv.",
            "If Python package browser-use is installed, this runner can be extended to interactive Playwright tasks.",
        ],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url")
    ap.add_argument("--query")
    ap.add_argument("--mode", choices=["extract", "search", "search_extract"], default="")
    ap.add_argument("--goal", default="extract")
    ap.add_argument("--max-results", type=int, default=5)
    ap.add_argument("--max-links", type=int, default=80)
    ap.add_argument("--max-text-chars", type=int, default=12000)
    ap.add_argument("--timeout", type=float, default=12)
    args = ap.parse_args()

    if not args.mode:
        args.mode = "search_extract" if args.query else "extract"

    common = build_common(args)
    headers = ["title", "url", "description", "h1", "emails", "phones", "socials", "quality", "error"]

    if args.mode == "extract":
        if not args.url:
            raise ValueError("Не указан URL для extract.")
        page = parse_page(args.url, args.goal, args.max_links, args.max_text_chars, args.timeout)
        result = {
            **common,
            **page,
            "headers": headers,
            "rows": [page_to_row(page)],
        }
        print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
        return 0

    if not args.query:
        raise ValueError("Не указан query для search/search_extract.")

    emit_progress(f"Ищу в интернете: {args.query}")
    search = search_web(args.query, max(1, min(args.max_results, 20)), args.timeout)
    result = {
        **common,
        "query": args.query,
        "search": search,
        "headers": headers,
        "rows": [result_to_row(item) for item in search.get("results", [])],
    }

    if args.mode == "search_extract":
        emit_progress("Парсю найденные страницы и собираю факты…")
        pages = extract_many(
            search.get("results", [])[: max(1, min(args.max_results, 12))],
            args.goal,
            args.max_links,
            args.max_text_chars,
            args.timeout,
        )
        usable_pages = [page for page in pages if (page.get("quality") or {}).get("usable", page.get("ok"))]
        result["pages"] = [compact_page(page) for page in pages]
        result["source_quality"] = [page.get("quality") or {} for page in pages]
        result["rows"] = [page_to_row(page) for page in usable_pages]

    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False))
        raise SystemExit(2)
