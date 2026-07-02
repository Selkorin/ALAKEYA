#!/usr/bin/env python3
"""
Test script for browser-use service
Run with: python3 test_server.py
"""

import asyncio
import requests
import json
import sys

BASE_URL = "http://127.0.0.1:8001"


def test_health():
    """Test health check endpoint"""
    print("🔍 Testing health check...")
    try:
        response = requests.get(f"{BASE_URL}/health")
        response.raise_for_status()
        data = response.json()

        print(f"✅ Health check: {data}")
        assert data["status"] == "healthy"
        print("✅ Health check passed\n")
        return True
    except Exception as e:
        print(f"❌ Health check failed: {e}\n")
        return False


def test_extract():
    """Test data extraction endpoint"""
    print("🔍 Testing data extraction...")

    try:
        response = requests.post(
            f"{BASE_URL}/extract",
            json={
                "url": "https://example.com",
                "extraction_goal": "contacts",
                "options": {
                    "include_screenshots": False,
                    "wait_for_dynamic_content": True
                }
            },
            timeout=30
        )

        response.raise_for_status()
        data = response.json()

        print(f"✅ Extraction response keys: {data.get('data', {}).keys()}")
        assert data["ok"] == True
        assert "url" in data.get("data", {})

        print("✅ Data extraction test passed\n")
        return True
    except Exception as e:
        print(f"❌ Data extraction test failed: {e}\n")
        return False


def test_screenshot():
    """Test screenshot endpoint"""
    print("🔍 Testing screenshot capture...")

    try:
        response = requests.post(
            f"{BASE_URL}/screenshot",
            json={
                "url": "https://example.com",
                "options": {
                    "full_page": False,
                    "wait_for_render": 1000
                }
            },
            timeout=30
        )

        response.raise_for_status()
        data = response.json()

        print(f"✅ Screenshot response keys: {data.get('data', {}).keys()}")
        assert data["ok"] == True
        assert "screenshot" in data.get("data", {})

        print("✅ Screenshot test passed\n")
        return True
    except Exception as e:
        print(f"❌ Screenshot test failed: {e}\n")
        return False


def test_session():
    """Test session management"""
    print("🔍 Testing session management...")

    try:
        # Create session
        create_response = requests.post(
            f"{BASE_URL}/session/create",
            json={"options": {"headless": True}},
            timeout=10
        )

        create_response.raise_for_status()
        create_data = create_response.json()

        print(f"✅ Session created: {create_data}")

        assert create_data["ok"] == True
        session_id = create_data["data"]["session_id"]
        print(f"✅ Session ID: {session_id}")

        # List sessions
        list_response = requests.get(f"{BASE_URL}/sessions", timeout=10)
        list_response.raise_for_status()
        list_data = list_response.json()

        print(f"✅ Active sessions: {list_data['data']['count']}")

        # Close session
        close_response = requests.delete(f"{BASE_URL}/session/{session_id}", timeout=10)
        close_response.raise_for_status()
        close_data = close_response.json()

        print(f"✅ Session closed: {close_data}")

        print("✅ Session management test passed\n")
        return True
    except Exception as e:
        print(f"❌ Session management test failed: {e}\n")
        return False


def test_search():
    """Test intelligent search"""
    print("🔍 Testing intelligent search...")

    try:
        response = requests.post(
            f"{BASE_URL}/search",
            json={
                "query": "Python programming",
                "max_results": 3,
                "extraction_goal": "summary",
                "options": {
                    "include_screenshots": False
                }
            },
            timeout=60
        )

        response.raise_for_status()
        data = response.json()

        print(f"✅ Search results: {data.get('data', {}).get('results_count', 0)} results")
        assert data["ok"] == True

        print("✅ Intelligent search test passed\n")
        return True
    except Exception as e:
        print(f"❌ Intelligent search test failed: {e}\n")
        return False


def main():
    """Run all tests"""
    print("🧪 browser-use Service Tests")
    print("=" * 50)
    print()

    tests = [
        ("Health Check", test_health),
        ("Data Extraction", test_extract),
        ("Screenshot", test_screenshot),
        ("Session Management", test_session),
        ("Intelligent Search", test_search),
    ]

    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print(f"❌ {name} test crashed: {e}\n")
            results.append((name, False))

    # Summary
    print("=" * 50)
    print("📊 Test Summary:")
    passed = sum(1 for _, result in results if result)
    total = len(results)

    for name, result in results:
        status = "✅" if result else "❌"
        print(f"{status} {name}")

    print()
    print(f"Result: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 All tests passed!")
        sys.exit(0)
    else:
        print("⚠️ Some tests failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
