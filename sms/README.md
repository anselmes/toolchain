# Swift MCP Server (SMS)

A Swift-based Model Context Protocol server for Zephyr RTOS development tooling.

## Overview

This Swift MCP server provides tools for:
- Swift package management and building
- Zephyr integration and compatibility validation
- Code analysis (memory usage, concurrency checking)
- Development tools (formatting, linting)
- Documentation generation

## Location

The server has been moved to the toolchain module for better organization:
```
modules/toolchain/sms/           # Swift MCP Server
├── Package.swift               # Swift package configuration
├── Sources/
│   ├── SwiftMCPServer/        # Main executable
│   │   └── main.swift
│   └── SwiftZephyrTools/      # Tools implementation
│       ├── SwiftZephyrTools.swift
│       └── MCPProtocol.swift
└── Tests/
    └── SwiftZephyrToolsTests/ # Unit tests
```

## Building

```bash
cd modules/toolchain/sms
swift build --configuration release
```

## Usage

The server is configured in the workspace `mcp.json` and can be invoked as:

```bash
swift run --package-path modules/toolchain/sms swift-mcp-server
```

## Available Tools

### Swift Package Management
- `swift_package_build` - Build Swift packages for Zephyr
- `swift_package_test` - Run Swift package tests
- `swift_package_update` - Update dependencies

### Zephyr Integration
- `swift_zephyr_generate` - Generate Swift bindings for Zephyr
- `swift_zephyr_validate` - Validate Swift code for Zephyr compatibility

### Code Analysis
- `swift_analyze_memory` - Analyze memory usage for embedded systems
- `swift_check_concurrency` - Check Swift concurrency compliance

### Development Tools
- `swift_format_code` - Format Swift code
- `swift_lint_code` - Lint Swift code
- `swift_generate_docs` - Generate documentation

## Environment Variables

- `WORKSPACE_ROOT` - Root of the workspace
- `SWIFT_ZEPHYR_MODULE` - Path to Swift Zephyr module
- `SWIFT_EMBEDDED` - Enable Embedded Swift features

## Dependencies

- Swift 6.0+
- swift-argument-parser
- swift-log
- Logging framework
