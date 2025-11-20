"""Python bindings for libcurl using Cython."""

__version__ = "0.1.0"

# Import the compiled Cython module
from .cylibcurl import Curl, CurlResponse

__all__ = ["Curl", "CurlResponse"]
