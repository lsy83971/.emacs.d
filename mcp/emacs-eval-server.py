#!/usr/bin/env python3
"""MCP server: execute Elisp in a running Emacs via emacsclient."""

import os
import subprocess
from fastmcp import FastMCP

DEFAULT_SOCKET = os.environ.get("EMACS_SOCKET_NAME", "")

mcp = FastMCP("emacs-eval")


def _run_emacsclient(code: str, socket: str = DEFAULT_SOCKET) -> str:
    try:
        cmd = ["emacsclient"]
        if socket:
            cmd += ["-s", socket]
        cmd += ["--eval", code]
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            err = result.stderr.strip() or result.stdout.strip()
            return f"ERROR: {err}"
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return "ERROR: emacsclient timed out (30s)"
    except FileNotFoundError:
        return "ERROR: emacsclient not found in PATH"


@mcp.tool()
def eval_elisp(code: str, socket: str = DEFAULT_SOCKET) -> str:
    """Execute Elisp code in the running Emacs instance and return the result.

    Args:
        code: Elisp expression(s) to evaluate.
        socket: Emacs server socket name (e.g. "ser", "claude0"). Empty for default.
    """
    return _run_emacsclient(code, socket)


@mcp.tool()
def emacs_buffer_content(
    buffer_name: str, socket: str = DEFAULT_SOCKET, start: int = 1, end: int = -1
) -> str:
    """Get the content of an Emacs buffer.

    Args:
        buffer_name: Name of the buffer (e.g. "init.el" or "*scratch*").
        socket: Emacs server socket name. Empty for default.
        start: Start position (1-based, default 1).
        end: End position (-1 means end of buffer).
    """
    end_expr = "(point-max)" if end == -1 else str(end)
    code = f"""
    (with-current-buffer "{buffer_name}"
      (buffer-substring-no-properties {start} {end_expr}))
    """
    return _run_emacsclient(code, socket)


@mcp.tool()
def emacs_list_buffers(socket: str = DEFAULT_SOCKET) -> str:
    """List all live Emacs buffers with their file paths (if any).

    Args:
        socket: Emacs server socket name. Empty for default.
    """
    code = """
    (mapconcat
     (lambda (b)
       (format "%s\\t%s"
               (buffer-name b)
               (or (buffer-file-name b) "")))
     (buffer-list) "\\n")
    """
    return _run_emacsclient(code, socket)


@mcp.tool()
def claude_list_instances(socket: str = DEFAULT_SOCKET) -> str:
    """List all running Claude Code instances with their character_id.

    Returns an alist of (buffer-name . character_id) pairs.
    Use this to discover other Claude instances you can communicate with.

    Args:
        socket: Emacs server socket name. Empty for default.
    """
    return _run_emacsclient("(claude-code-ipc-list)", socket)


@mcp.tool()
def claude_send_message(target: str, message: str, socket: str = DEFAULT_SOCKET) -> str:
    """Send a message to another Claude Code instance.

    The message will be typed into the target instance's terminal and Enter
    will be pressed automatically.

    Args:
        target: Target identifier — can be a character_id (e.g. "管理者"),
                exact buffer name, or a fuzzy keyword.
        message: The message text to send.
        socket: Emacs server socket name. Empty for default.
    """
    # Escape quotes in target and message for elisp
    t = target.replace("\\", "\\\\").replace('"', '\\"')
    m = message.replace("\\", "\\\\").replace('"', '\\"')
    code = f'(claude-code-ipc-send "{t}" "{m}")'
    return _run_emacsclient(code, socket)


@mcp.tool()
def claude_get_my_character_id(buffer_name: str = "", socket: str = DEFAULT_SOCKET) -> str:
    """Get the character_id (instance name / role) of a Claude instance.

    If buffer_name is provided, get that instance's character_id.
    Otherwise returns all instances with their character_ids.
    Use claude_list_instances to discover available instances.

    Args:
        buffer_name: Exact buffer name. Empty to list all.
        socket: Emacs server socket name. Empty for default.
    """
    if buffer_name:
        b = buffer_name.replace("\\", "\\\\").replace('"', '\\"')
        code = f'(claude-code--get-character-id (get-buffer "{b}"))'
    else:
        code = "(claude-code-ipc-list)"
    return _run_emacsclient(code, socket)


if __name__ == "__main__":
    mcp.run(transport="stdio")
