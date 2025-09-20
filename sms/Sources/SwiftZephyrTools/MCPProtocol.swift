/*
 * Simple MCP Implementation
 *
 * Copyright (c) schubert@anselm.es
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import Foundation

// Simple MCP Protocol Implementation for Swift tools
public struct MCPServer {
    public let name: String
    public let version: String
    private var tools: [MCPTool] = []

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }

    public mutating func addTool(_ tool: MCPTool) {
        tools.append(tool)
    }

    public func run() async throws {
        print("Swift MCP Server '\(name)' v\(version) starting...")
        print("Available tools: \(tools.map { $0.name }.joined(separator: ", "))")

        // Simple stdin/stdout based MCP protocol
        while let line = readLine() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            if line == "list_tools" {
                listTools()
            } else if line.hasPrefix("call_tool ") {
                let toolName = String(line.dropFirst("call_tool ".count))
                await callTool(name: toolName)
            } else if line == "quit" || line == "exit" {
                break
            } else {
                print("Unknown command: \(line)")
                print("Available commands: list_tools, call_tool <name>, quit")
            }
        }
    }

    private func listTools() {
        print("Available tools:")
        for tool in tools {
            print("- \(tool.name): \(tool.description)")
        }
    }

    private func callTool(name: String) async {
        guard let tool = tools.first(where: { $0.name == name }) else {
            print("Tool '\(name)' not found")
            return
        }

        print("Calling tool: \(tool.name)")
        let result = await tool.handler([:])
        print("Result: \(result.output)")
        if let error = result.error {
            print("Error: \(error)")
        }
    }
}

public struct MCPTool {
    public let name: String
    public let description: String
    public let handler: @Sendable ([String: Any]) async -> MCPResult

    public init(name: String, description: String, handler: @Sendable @escaping ([String: Any]) async -> MCPResult) {
        self.name = name
        self.description = description
        self.handler = handler
    }
}
