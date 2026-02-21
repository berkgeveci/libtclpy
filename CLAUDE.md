# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

libtclpy is a bidirectional Tcl-Python interoperability library (Tcl extension written in C). It allows calling between Tcl and Python interpreters in both directions. Targets Tcl >= 8.5 and Python 3.6+. Licensed under 3-clause BSD.

## Build Commands

### CMake (preferred)
```bash
mkdir -p build && cd build
cmake ..
make
```

### GNU Make (legacy)
```bash
make
# Or with custom tclConfig.sh path:
make TCLCONFIG=/path/to/tclConfig.sh
# Disable Tcl stubs (needed if Python is parent interpreter):
make TCL_STUBS=0
```

### Run Tests
```bash
# From build/ directory (CMake):
ctest
# Or:
make test

# From repo root (Make):
make test
```

Tests use the `tcltest` framework. The single test file is `tests/tclpy.test`.

### Dependencies
- CMake 3.15+ (or GNU Make + GCC)
- Python 3.6+ development headers (`python3-dev`)
- Tcl 8.5+ development headers (`tcl-dev`)

## Architecture

The entire implementation is a single C file: **`generic/tclpy.c`** (~600 lines).

### Three Sections of tclpy.c

1. **Tcl-side commands (top half)**: Implements three Tcl commands registered under the `py` ensemble:
   - `py eval <code>` — execute Python code (returns nothing)
   - `py call <func> [args...]` — call a Python function (returns converted result)
   - `py import <module>` — import a Python module into globals

2. **Python-side module (middle)**: Implements the `tclpy` Python module with one method:
   - `tclpy.eval(tcl_code)` — execute Tcl code from Python, returns result string

3. **Initialization (bottom)**: `Tclpy_Init()` (Tcl entry) and `init_python_tclpy()` (Python entry) handle interpreter setup and parent tracking (enum `ParentInterp` prevents double-init).

### Key Function: `pyObjToTcl()`
Converts Python objects to Tcl objects. Conversion priority: None→empty string, True/False→1/0, bytes→byte array, str→UTF-8 string, numbers→string, sequences→Tcl lists, mappings→Tcl dicts, fallback→`str()`.

### Key Function: `pyTraceAsStr()`
Formats Python exceptions with full tracebacks using Python's `traceback` module. Returns a C string (caller must free). Appends separator: `"----- tcl -> python interface -----"`.

## Build Output

- `libtclpy0.4.so` — the shared library (loadable from Tcl via `package require tclpy` or from Python via `import tclpy`)
- `pkgIndex.tcl` — generated from `pkgIndex.tcl.in`, tells Tcl how to load the package

## Gotchas

- Unicode chars in `py eval` are decoded by the Tcl parser and passed as literal bytes to Python — be careful with non-ASCII in eval strings.
- Escape sequences (e.g. `\x00`) in `py eval` may be interpreted by Tcl — use `{}` quoting.
- The library uses `dlopen`/`LoadLibrary` to load the Python shared library at runtime (`PY_LIBFILE` compile-time define).
- Tcl stubs are enabled by default; disable them (`TCL_STUBS=0` or `-DUSE_TCL_STUBS=OFF`) if loading from a Python parent interpreter.
