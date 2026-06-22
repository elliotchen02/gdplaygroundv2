#!/usr/bin/env bash
# Clone and install inkscape-mcp for project-local Cursor MCP (macOS).
# Run: ./hack/setup-inkscape-mcp.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

INKSCAPE_MCP_DIR="hack/inkscape-mcp"
INKSCAPE_MCP_REPO="https://github.com/sandraschi/inkscape-mcp.git"
DETECTOR="$INKSCAPE_MCP_DIR/src/inkscape_mcp/inkscape_detector.py"

if ! command -v uv >/dev/null 2>&1; then
	echo "error: uv is required (https://docs.astral.sh/uv/)" >&2
	exit 1
fi

if [[ ! -d "$INKSCAPE_MCP_DIR" ]]; then
	echo "Cloning inkscape-mcp into $INKSCAPE_MCP_DIR ..."
	git clone --depth 1 "$INKSCAPE_MCP_REPO" "$INKSCAPE_MCP_DIR"
fi

# Upstream macOS fixes (winreg import + Inkscape path detection).
python3 - "$DETECTOR" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

if "import winreg" in text and "try:\n    import winreg" not in text:
	text = text.replace(
		"import subprocess\nimport winreg\nfrom pathlib import Path",
		"import subprocess\nfrom pathlib import Path\n\ntry:\n    import winreg\nexcept ImportError:\n    winreg = None  # type: ignore[assignment,misc]",
	)

gimp_macos = '''    def _detect_macos(self) -> str | None:
        """
        Detect GIMP on macOS.

        Returns:
            Optional[str]: Path to GIMP executable
        """
        common_paths = [
            "/Applications/GIMP 3.0.app/Contents/MacOS/gimp",
            "/Applications/GIMP-2.10.app/Contents/MacOS/gimp",
            "/Applications/GIMP.app/Contents/MacOS/gimp",
            "/usr/local/bin/gimp",
            "/opt/homebrew/bin/gimp",
        ]

        for path in common_paths:
            if self._validate_executable(path):
                return path

        # Try PATH environment
        path_executable = self._check_path_environment(["gimp"])
        if path_executable:
            return path_executable

        return None'''

inkscape_macos = '''    def _detect_macos(self) -> str | None:
        """
        Detect Inkscape on macOS.

        Returns:
            Optional[str]: Path to Inkscape executable
        """
        common_paths = [
            "/Applications/Inkscape.app/Contents/MacOS/inkscape",
            "/Applications/Inkscape/Inkscape.app/Contents/MacOS/inkscape",
            "/usr/local/bin/inkscape",
            "/opt/homebrew/bin/inkscape",
        ]

        for path in common_paths:
            if self._validate_executable(path):
                return path

        path_executable = self._check_path_environment(["inkscape"])
        if path_executable:
            return path_executable

        return None'''

if gimp_macos in text:
	text = text.replace(gimp_macos, inkscape_macos)

text = text.replace(
	'if "gimp" not in path_str:\n                return False',
	'if "inkscape" not in path_str and "gimp" not in path_str:\n                return False',
)

path.write_text(text)
PY

export PKG_CONFIG_PATH="/opt/homebrew/opt/libffi/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export CPPFLAGS="-I/opt/homebrew/opt/libffi/include"
export LDFLAGS="-L/opt/homebrew/opt/libffi/lib"

echo "Installing inkscape-mcp dependencies ..."
(cd "$INKSCAPE_MCP_DIR" && uv sync)

echo "Inkscape MCP ready in $INKSCAPE_MCP_DIR/"
echo "Configure Cursor via .cursor/mcp.json (project-local)."
