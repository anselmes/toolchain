#!/usr/bin/env python3
"""
Zephyr RTOS Model Context Protocol Server

This MCP server provides tools for Zephyr RTOS development including:
- Build management with west
- Device tree operations
- Board configuration
- Kconfig management
- Hardware abstraction layer tools

Copyright (c) schubert@anselm.es

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
"""

import asyncio
import json
import logging
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence

# MCP server imports
try:
    from mcp.server import Server
    from mcp.server.models import InitializationOptions
    from mcp.server.stdio import stdio_server
    from mcp.types import (
        CallToolRequest,
        CallToolResult,
        ListToolsRequest,
        ListToolsResult,
        Tool,
        TextContent,
        ImageContent,
        EmbeddedResource,
    )
except ImportError:
    print("Error: MCP library not found. Install with: pip install mcp", file=sys.stderr)
    sys.exit(1)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("zephyr-mcp-server")

# Environment variables
WORKSPACE_ROOT = os.getenv("WORKSPACE_ROOT", "/Users/sanselme/workspace")
ZEPHYR_BASE = os.getenv("ZEPHYR_BASE", f"{WORKSPACE_ROOT}/zephyr-sandbox/zephyr")
ZEPHYR_TOOLCHAIN_VARIANT = os.getenv("ZEPHYR_TOOLCHAIN_VARIANT", "llvm")
ZEPHYR_SANDBOX = f"{WORKSPACE_ROOT}/zephyr-sandbox"

# Initialize MCP server
server = Server("zephyr-tools")

def run_command(cmd: List[str], cwd: Optional[str] = None, capture_output: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command and return the result."""
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd or ZEPHYR_SANDBOX,
            capture_output=capture_output,
            text=True,
            check=False
        )
        return result
    except Exception as e:
        logger.error(f"Command failed: {' '.join(cmd)} - {e}")
        raise

@server.list_tools()
async def handle_list_tools() -> List[Tool]:
    """List available Zephyr development tools."""
    return [
        Tool(
            name="zephyr_build",
            description="Build a Zephyr application using west",
            inputSchema={
                "type": "object",
                "properties": {
                    "app_path": {
                        "type": "string",
                        "description": "Path to the application (relative to zephyr-sandbox)",
                        "default": "app"
                    },
                    "board": {
                        "type": "string",
                        "description": "Target board name",
                        "default": "qemu_x86"
                    },
                    "pristine": {
                        "type": "boolean",
                        "description": "Clean build (pristine)",
                        "default": False
                    },
                    "extra_args": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Extra arguments to pass to west build"
                    }
                },
                "required": []
            }
        ),
        Tool(
            name="zephyr_flash",
            description="Flash a Zephyr application to hardware",
            inputSchema={
                "type": "object",
                "properties": {
                    "app_path": {
                        "type": "string",
                        "description": "Path to the application",
                        "default": "app"
                    }
                },
                "required": []
            }
        ),
        Tool(
            name="zephyr_run",
            description="Run a Zephyr application (typically in emulator)",
            inputSchema={
                "type": "object",
                "properties": {
                    "app_path": {
                        "type": "string",
                        "description": "Path to the application",
                        "default": "app"
                    }
                },
                "required": []
            }
        ),
        Tool(
            name="zephyr_list_boards",
            description="List available Zephyr boards",
            inputSchema={
                "type": "object",
                "properties": {
                    "filter": {
                        "type": "string",
                        "description": "Filter boards by name pattern"
                    }
                },
                "required": []
            }
        ),
        Tool(
            name="zephyr_menuconfig",
            description="Open Zephyr menuconfig for configuration",
            inputSchema={
                "type": "object",
                "properties": {
                    "app_path": {
                        "type": "string",
                        "description": "Path to the application",
                        "default": "app"
                    }
                },
                "required": []
            }
        ),
        Tool(
            name="zephyr_devicetree",
            description="Show device tree information",
            inputSchema={
                "type": "object",
                "properties": {
                    "app_path": {
                        "type": "string",
                        "description": "Path to the application",
                        "default": "app"
                    }
                },
                "required": []
            }
        ),
        Tool(
            name="zephyr_clean",
            description="Clean Zephyr build artifacts",
            inputSchema={
                "type": "object",
                "properties": {
                    "app_path": {
                        "type": "string",
                        "description": "Path to the application",
                        "default": "app"
                    }
                },
                "required": []
            }
        ),
        Tool(
            name="zephyr_update",
            description="Update Zephyr and modules using west",
            inputSchema={
                "type": "object",
                "properties": {},
                "required": []
            }
        ),
        Tool(
            name="zephyr_debug",
            description="Start debugging session for Zephyr application",
            inputSchema={
                "type": "object",
                "properties": {
                    "app_path": {
                        "type": "string",
                        "description": "Path to the application",
                        "default": "app"
                    }
                },
                "required": []
            }
        ),
        Tool(
            name="zephyr_size_report",
            description="Generate memory usage report",
            inputSchema={
                "type": "object",
                "properties": {
                    "app_path": {
                        "type": "string",
                        "description": "Path to the application",
                        "default": "app"
                    },
                    "report_type": {
                        "type": "string",
                        "enum": ["ram", "rom", "footprint"],
                        "description": "Type of size report",
                        "default": "footprint"
                    }
                },
                "required": []
            }
        ),
        Tool(
            name="swift_generate_zephyr_file",
            description="Generate Swift file with proper structure for Zephyr",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_name": {
                        "type": "string",
                        "description": "Name of the Swift file to generate",
                        "default": "ZephyrModule.swift"
                    },
                    "module_name": {
                        "type": "string",
                        "description": "Name of the Swift module",
                        "default": "ZephyrModule"
                    },
                    "imports": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of imports for the Swift file",
                        "default": ["Foundation", "ZephyrSys"]
                    },
                    "embedded": {
                        "type": "boolean",
                        "description": "Enable embedded Swift features",
                        "default": True
                    },
                    "output_dir": {
                        "type": "string",
                        "description": "Output directory for generated file",
                        "default": "modules/lang/swift/Sources"
                    }
                },
                "required": ["file_name", "module_name"]
            }
        )
    ]

@server.call_tool()
async def handle_call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle tool calls for Zephyr operations."""

    if name == "zephyr_build":
        app_path = arguments.get("app_path", "app")
        board = arguments.get("board", "qemu_x86")
        pristine = arguments.get("pristine", False)
        extra_args = arguments.get("extra_args", [])

        cmd = ["west", "build", app_path]
        if pristine:
            cmd.append("-p")
        if board != "qemu_x86":
            cmd.extend(["-b", board])
        cmd.extend(extra_args)

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Build command: {' '.join(cmd)}\n"
                 f"Exit code: {result.returncode}\n"
                 f"Output:\n{result.stdout}\n"
                 f"Errors:\n{result.stderr}"
        )]

    elif name == "zephyr_flash":
        app_path = arguments.get("app_path", "app")
        cmd = ["west", "flash", "-d", f"build_{app_path}"]

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Flash command: {' '.join(cmd)}\n"
                 f"Exit code: {result.returncode}\n"
                 f"Output:\n{result.stdout}\n"
                 f"Errors:\n{result.stderr}"
        )]

    elif name == "zephyr_run":
        app_path = arguments.get("app_path", "app")
        cmd = ["west", "build", app_path, "-t", "run"]

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Run command: {' '.join(cmd)}\n"
                 f"Exit code: {result.returncode}\n"
                 f"Output:\n{result.stdout}\n"
                 f"Errors:\n{result.stderr}"
        )]

    elif name == "zephyr_list_boards":
        filter_pattern = arguments.get("filter", "")
        cmd = ["west", "boards"]
        if filter_pattern:
            cmd.extend(["|", "grep", filter_pattern])

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Available boards:\n{result.stdout}"
        )]

    elif name == "zephyr_menuconfig":
        app_path = arguments.get("app_path", "app")
        cmd = ["west", "build", app_path, "-t", "menuconfig"]

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Menuconfig command: {' '.join(cmd)}\n"
                 f"Exit code: {result.returncode}\n"
                 f"Output:\n{result.stdout}"
        )]

    elif name == "zephyr_devicetree":
        app_path = arguments.get("app_path", "app")
        cmd = ["west", "build", app_path, "-t", "devicetree"]

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Device tree info:\n{result.stdout}"
        )]

    elif name == "zephyr_clean":
        app_path = arguments.get("app_path", "app")
        cmd = ["west", "build", app_path, "-t", "clean"]

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Clean command: {' '.join(cmd)}\n"
                 f"Exit code: {result.returncode}\n"
                 f"Output:\n{result.stdout}"
        )]

    elif name == "zephyr_update":
        cmd = ["west", "update"]

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Update command: {' '.join(cmd)}\n"
                 f"Exit code: {result.returncode}\n"
                 f"Output:\n{result.stdout}\n"
                 f"Errors:\n{result.stderr}"
        )]

    elif name == "zephyr_debug":
        app_path = arguments.get("app_path", "app")
        cmd = ["west", "debug", "-d", f"build_{app_path}"]

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Debug session started for {app_path}\n"
                 f"Command: {' '.join(cmd)}\n"
                 f"Output:\n{result.stdout}"
        )]

    elif name == "zephyr_size_report":
        app_path = arguments.get("app_path", "app")
        report_type = arguments.get("report_type", "footprint")

        if report_type == "footprint":
            cmd = ["west", "build", app_path, "-t", "footprint"]
        else:
            cmd = ["west", "build", app_path, "-t", f"{report_type}_report"]

        result = run_command(cmd)
        return [TextContent(
            type="text",
            text=f"Size report ({report_type}):\n{result.stdout}"
        )]

    elif name == "swift_generate_zephyr_file":
        return await generate_swift_zephyr_file(arguments)

    else:
        return [TextContent(
            type="text",
            text=f"Unknown tool: {name}"
        )]


async def generate_swift_zephyr_file(
    arguments: Dict[str, Any]
) -> List[TextContent]:
    """Generate Swift file with proper structure for Zephyr development."""
    file_name = arguments.get("file_name", "ZephyrModule.swift")
    module_name = arguments.get("module_name", "ZephyrModule")
    imports = arguments.get("imports", ["Foundation", "ZephyrSys"])
    embedded = arguments.get("embedded", True)
    output_dir = arguments.get("output_dir", "modules/lang/swift/Sources")

    # Ensure file has .swift extension
    if not file_name.endswith('.swift'):
        file_name += '.swift'

    # Create Swift file content with new structure and 2-space indentation
    content = generate_swift_file_content(module_name, imports, embedded)

    try:
        # Create output directory if it doesn't exist
        output_path = Path(WORKSPACE_ROOT) / output_dir
        output_path.mkdir(parents=True, exist_ok=True)

        # Write the file
        file_path = output_path / file_name
        file_path.write_text(content, encoding='utf-8')

        return [TextContent(
            type="text",
            text=f"Generated Swift file: {file_path}\n\n"
                 f"Content preview:\n{content[:500]}..."
        )]

    except Exception as e:
        return [TextContent(
            type="text",
            text=f"Error generating Swift file: {str(e)}"
        )]


def generate_swift_file_content(
    module_name: str, imports: List[str], embedded: bool
) -> str:
    """Generate Swift file content following the new structure guidelines."""

    # Start with copyright header
    content = f'''/*
* {module_name}
*
* Copyright (c) schubert@anselm.es
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*/

'''

    # Add imports section with proper ordering
    content += "// Imports\n"
    for imp in sorted(imports):
        content += f"import {imp}\n"

    content += "\n"

    # Add public protocols section
    content += "// Public protocols\n"
    content += f"public protocol {module_name}Protocol {{}}\n\n"

    # Add public enums
    content += "// Public enums\n"
    content += f"public enum {module_name}Error: Error {{\n"
    content += "  case invalidConfiguration\n"
    content += "  case initializationFailed\n"
    content += "}\n\n"

    # Add public types with 2-space indentation
    content += "// Public types\n"
    content += f"public struct {module_name} {{\n"
    content += "  // Public properties\n"
    content += "  public let configuration: Configuration\n"
    content += "  \n"
    content += "  // Internal properties\n"
    content += "  let context: Context\n"
    content += "  \n"
    content += "  // Private properties\n"
    content += "  private let backend: Backend? = nil\n"
    content += "}\n\n"

    # Add configuration struct
    content += "public struct Configuration {\n"
    content += "  public let name: String\n"
    if embedded:
        content += "  public let embeddedMode: Bool = true\n"
    content += "}\n\n"

    # Add MARK sections
    content += "// MARK: - Extension\n\n"
    content += f"extension {module_name}Error: Error {{}}\n"
    content += f"extension {module_name}: {module_name}Protocol {{}}\n\n"

    content += "// MARK: - Public\n\n"
    content += f"public extension {module_name} {{\n"
    content += "  init(name: String) {{\n"
    content += "    self.configuration = Configuration(name: name)\n"
    content += "    self.context = Context()\n"
    content += "  }}\n"
    content += "}\n\n"

    content += "// MARK: - Internal\n\n"
    content += f"extension {module_name} {{\n"
    content += "  struct Context {{\n"
    content += "    // Internal context implementation\n"
    content += "  }}\n"
    content += "}\n\n"

    content += "// MARK: - Private\n\n"
    content += f"private extension {module_name} {{\n"
    content += "  struct Backend {{\n"
    content += "    // Private backend implementation\n"
    content += "  }}\n"
    content += "}\n"

    return content


async def main():
    """Main entry point for the Zephyr MCP server."""
    # Server startup message
    logger.info("Starting Zephyr MCP Server")
    logger.info(f"Workspace root: {WORKSPACE_ROOT}")
    logger.info(f"Zephyr base: {ZEPHYR_BASE}")
    logger.info(f"Zephyr sandbox: {ZEPHYR_SANDBOX}")

    # Verify Zephyr installation
    try:
        result = run_command(["west", "--version"], capture_output=True)
        if result.returncode == 0:
            logger.info(f"West version: {result.stdout.strip()}")
        else:
            logger.warning("West not found or not working properly")
    except Exception as e:
        logger.error(f"Failed to check west installation: {e}")

    # Run the server
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="zephyr-tools",
                server_version="1.0.0",
                capabilities=server.get_capabilities(
                    notification_options=None,
                    experimental_capabilities=None,
                )
            )
        )

if __name__ == "__main__":
    asyncio.run(main())
