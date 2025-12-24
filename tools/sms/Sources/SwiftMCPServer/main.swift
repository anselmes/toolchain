/*
 * Swift MCP Server for Zephyr Integration
 *
 * Copyright (c) schubert@anselm.es
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import ArgumentParser
import Foundation
import Logging
import SwiftZephyrTools

@main
struct SwiftMCPServer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-mcp-server",
        abstract: "Swift Model Context Protocol server for Zephyr RTOS development"
    )

    @Option(help: "Workspace root directory")
    var workspaceRoot: String = ProcessInfo.processInfo.environment["WORKSPACE_ROOT"] ?? "/Users/sanselme/workspace"

    @Option(help: "Swift Zephyr module path")
    var swiftZephyrModule: String = ProcessInfo.processInfo.environment["SWIFT_ZEPHYR_MODULE"] ?? ""

    @Flag(help: "Enable verbose logging")
    var verbose = false

    func run() async throws {
        // Setup logging
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = verbose ? .debug : .info
            return handler
        }

        let logger = Logger(label: "swift-mcp-server")
        logger.info("Starting Swift MCP Server for Zephyr")
        logger.info("Workspace root: \(workspaceRoot)")
        logger.info("Swift Zephyr module: \(swiftZephyrModule)")

        // Initialize tools
        let swiftTools = SwiftZephyrTools(
            workspaceRoot: workspaceRoot,
            swiftZephyrModule: swiftZephyrModule,
            logger: logger
        )

        // Create MCP server
        var server = MCPServer(name: "swift-zephyr-tools", version: "1.0.0")

        // Register tools
        registerSwiftTools(server: &server, tools: swiftTools)

        // Start server
        try await server.run()
    }

    private func registerSwiftTools(server: inout MCPServer, tools: SwiftZephyrTools) {
        // Swift Package Management
        server.addTool(MCPTool(
            name: "swift_package_build",
            description: "Build Swift package for Zephyr"
        ) { parameters in
            await tools.buildPackage(
                configuration: parameters["configuration"] as? String ?? "debug",
                target: parameters["target"] as? String,
                embedded: parameters["embedded"] as? Bool ?? true
            )
        })

        server.addTool(MCPTool(
            name: "swift_package_test",
            description: "Run Swift package tests"
        ) { parameters in
            await tools.runTests(
                target: parameters["target"] as? String,
                filter: parameters["filter"] as? String
            )
        })

        server.addTool(MCPTool(
            name: "swift_package_update",
            description: "Update Swift package dependencies"
        ) { _ in
            await tools.updateDependencies()
        })

        // Zephyr Integration
        server.addTool(MCPTool(
            name: "swift_zephyr_generate",
            description: "Generate Swift bindings for Zephyr"
        ) { parameters in
            await tools.generateZephyrBindings(
                module: parameters["module"] as? String ?? "",
                outputDir: parameters["output_dir"] as? String
            )
        })

        server.addTool(MCPTool(
            name: "swift_zephyr_validate",
            description: "Validate Swift code for Zephyr compatibility"
        ) { parameters in
            await tools.validateZephyrCompatibility(
                sourceFile: parameters["source_file"] as? String ?? "",
                embeddedMode: parameters["embedded_mode"] as? Bool ?? true
            )
        })

        // Code Analysis
        server.addTool(MCPTool(
            name: "swift_analyze_memory",
            description: "Analyze memory usage of Swift code for embedded systems"
        ) { parameters in
            await tools.analyzeMemoryUsage(
                sourceFile: parameters["source_file"] as? String ?? "",
                optimizationLevel: parameters["optimization_level"] as? String ?? "O"
            )
        })

        server.addTool(MCPTool(
            name: "swift_check_concurrency",
            description: "Check Swift concurrency compliance"
        ) { parameters in
            await tools.checkConcurrency(
                sourceFile: parameters["source_file"] as? String ?? "",
                strictMode: parameters["strict_mode"] as? Bool ?? true
            )
        })

        // Development Tools
        server.addTool(MCPTool(
            name: "swift_format_code",
            description: "Format Swift code according to project standards"
        ) { parameters in
            await tools.formatCode(
                sourceFile: parameters["source_file"] as? String ?? "",
                inPlace: parameters["in_place"] as? Bool ?? false
            )
        })

        server.addTool(MCPTool(
            name: "swift_lint_code",
            description: "Lint Swift code for style and best practices"
        ) { parameters in
            await tools.lintCode(
                sourceFile: parameters["source_file"] as? String ?? "",
                embeddedRules: parameters["embedded_rules"] as? Bool ?? true
            )
        })

        // Documentation
        server.addTool(MCPTool(
            name: "swift_generate_docs",
            description: "Generate documentation for Swift code"
        ) { parameters in
            await tools.generateDocumentation(
                target: parameters["target"] as? String,
                outputFormat: parameters["output_format"] as? String ?? "docc"
            )
        })

        // Code Generation
        server.addTool(MCPTool(
            name: "swift_generate_file",
            description: "Generate Swift file with proper structure and 2-space indentation"
        ) { parameters in
            await tools.generateSwiftFile(
                fileName: parameters["file_name"] as? String ?? "NewFile.swift",
                imports: parameters["imports"] as? [String] ?? ["Foundation"],
                types: parameters["types"] as? [String] ?? [],
                protocols: parameters["protocols"] as? [String] ?? []
            )
        })
    }
}
