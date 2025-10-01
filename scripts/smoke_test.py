import os
import json
import sys
import importlib
from pathlib import Path


def _probe_import(module_name: str) -> dict:
    try:
        importlib.import_module(module_name)
        return {"available": True}
    except Exception as e:
        return {"available": False, "error": str(e)}


def main():
    # Ensure src is on path for local imports
    src_path = str(Path(__file__).resolve().parent.parent / "src")
    if src_path not in sys.path:
        sys.path.insert(0, src_path)
    results = {
        "env": {
            "OPENAI_API_KEY_present": bool(os.getenv("OPENAI_API_KEY")),
            "OLLAMA_HOST": os.getenv("OLLAMA_HOST", ""),
            "DATABASE_URL_present": bool(os.getenv("DATABASE_URL")),
            "EMBED_MODEL": os.getenv("EMBED_MODEL", ""),
            "EMBED_DIM": os.getenv("EMBED_DIM", ""),
            "MCP_URL": os.getenv("MCP_URL", ""),
        },
        "python": {
            "version": sys.version,
        },
        "dependencies": {},
        "ok": True,
        "warnings": [],
    }

    # Probe availability of key third-party modules
    for mod in [
        "streamlit",
        "ollama",
        "numpy",
        "PyPDF2",
        "requests",
        "openai",
    ]:
        results["dependencies"][mod] = _probe_import(mod)

    # Probe app modules (without executing heavy code)
    for app_mod in [
        "ollama_client",
        "openai_client",
        "mcp_client",
        "pdf_processor",
        "database.enhanced_vector_db",
        "vector_db",
    ]:
        results["dependencies"][app_mod] = _probe_import(app_mod)

    if not os.getenv("OPENAI_API_KEY"):
        results["warnings"].append("OPENAI_API_KEY not set; OpenAI provider will require key via UI.")

    print(json.dumps(results))


if __name__ == "__main__":
    main()

