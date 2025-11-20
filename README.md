![whisper-cpp](docs/images/whisper-cpp.svg)

# doxybook2

Python bindings for [whisper.cpp](https://github.com/ggerganov/whisper.cpp) using Cython and scikit-build.

## Overview

This project provides Python bindings for the [whisper.cpp](https://github.com/ggerganov/whisper.cpp) library, enabling speech recognition capabilities in Python with native performance through Cython integration.

**Note:** This project is not just for Python developers! C++ developers can also use the pre-built whisper.cpp library included in this package instead of building whisper.cpp from source.

## Features

- Python bindings for whisper.cpp speech recognition
- Built with Cython for optimal performance
- CMake integration via scikit-build
- Built-in model downloader with CLI interface
- Test-driven development approach

## Installation

```bash
pip install doxybook2
```

For the latest development version:
```bash
pip install git+https://github.com/MohammadRaziei/whisper-cpp.git
```

## Quick Start

### Download Models

```bash
# List available models
doxybook2 models list

# Download a model
doxybook2 models download tiny

# Download to specific path
doxybook2 models download base /path/to/models
```

### Python Usage

```python
from doxybook2.models import download_model

# Download a model
download_model("tiny")
```

## Development

Run tests:
```bash
pytest -n auto
```

## License

MIT License
