"""Basic tests for cylibcurl."""

import pytest

from libcurl import CurlResponse, Curl



def test_curl_response_class():
    """Test CurlResponse class functionality."""
    
    # Test basic response
    response = CurlResponse(status_code=200, data=b"Hello World")
    assert response.status_code == 200
    assert response.data == b"Hello World"
    assert response.text == "Hello World"
    assert response.headers == {}
    
    # Test with headers
    response = CurlResponse(
        status_code=404, 
        data=b"Not Found", 
        headers={"Content-Type": "text/plain"}
    )
    assert response.status_code == 404
    assert response.headers["Content-Type"] == "text/plain"


def test_curl_response_json():
    """Test JSON parsing in CurlResponse."""
    
    # Test valid JSON
    json_data = '{"key": "value", "number": 42}'
    response = CurlResponse(status_code=200, data=json_data.encode('utf-8'))
    parsed = response.json()
    assert parsed["key"] == "value"
    assert parsed["number"] == 42
    
    # Test invalid JSON
    response = CurlResponse(status_code=200, data=b"invalid json")
    with pytest.raises(Exception):
        response.json()


def test_curl_instance():
    """Test Curl instance creation."""
    
    # This test will only work after the Cython module is compiled
    curl_instance = Curl()
    assert curl_instance is not None


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
