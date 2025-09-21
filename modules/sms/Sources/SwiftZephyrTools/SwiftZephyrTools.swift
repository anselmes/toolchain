/*
* Zephyr Swift Tools Implementation
*
* Copyright (c) schubert@anselm.es
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*/

import Foundation
import Logging

public struct SwiftZephyrTools: Sendable {
  private let workspaceRoot: String
  private let swiftZephyrModule: String
  private let logger: Logger

  public init(workspaceRoot: String, swiftZephyrModule: String, logger: Logger) {
    self.workspaceRoot = workspaceRoot
    self.swiftZephyrModule = swiftZephyrModule
    self.logger = logger
  }

  // MARK: - Swift Package Management

  public func buildPackage(configuration: String, target: String?, embedded: Bool) async -> MCPResult {
    logger.info("Building Swift package with configuration: \(configuration)")

    var command = ["swift", "build", "--configuration", configuration]

    if let target = target {
        command.append(contentsOf: ["--target", target])
    }

    if embedded {
        command.append(contentsOf: ["-Xswiftc", "-enable-experimental-feature", "-Xswiftc", "Embedded"])
    }

    let result = await runCommand(command, in: swiftZephyrModule)
    return MCPResult(
        success: result.exitCode == 0,
        output: result.output,
        error: result.error
    )
  }

  public func runTests(target: String?, filter: String?) async -> MCPResult {
    logger.info("Running Swift package tests")

    var command = ["swift", "test"]

    if let target = target {
        command.append(contentsOf: ["--target", target])
    }

    if let filter = filter {
        command.append(contentsOf: ["--filter", filter])
    }

    let result = await runCommand(command, in: swiftZephyrModule)
    return MCPResult(
        success: result.exitCode == 0,
        output: result.output,
        error: result.error
    )
  }

  public func updateDependencies() async -> MCPResult {
    logger.info("Updating Swift package dependencies")

    let result = await runCommand(["swift", "package", "update"], in: swiftZephyrModule)
    return MCPResult(
        success: result.exitCode == 0,
        output: result.output,
        error: result.error
    )
  }

  // MARK: - Zephyr Integration

  public func generateZephyrBindings(module: String, outputDir: String?) async -> MCPResult {
    logger.info("Generating Swift bindings for Zephyr module: \(module)")

    let outputDirectory = outputDir ?? "\(swiftZephyrModule)/Sources/ZephyrBindings"

    var command = ["swift", "run", "binding-generator"]
    command.append(contentsOf: ["--module", module])
    command.append(contentsOf: ["--output", outputDirectory])

    let result = await runCommand(command, in: swiftZephyrModule)
    return MCPResult(
        success: result.exitCode == 0,
        output: result.output,
        error: result.error
    )
  }

  public func validateZephyrCompatibility(sourceFile: String, embeddedMode: Bool) async -> MCPResult {
    logger.info("Validating Zephyr compatibility for: \(sourceFile)")

    var command = ["swift", "frontend", "-typecheck"]
    command.append(sourceFile)

    if embeddedMode {
        command.append(contentsOf: ["-enable-experimental-feature", "Embedded"])
    }

    let result = await runCommand(command, in: swiftZephyrModule)
    return MCPResult(
        success: result.exitCode == 0,
        output: "Validation \(result.exitCode == 0 ? "passed" : "failed")",
        error: result.error
    )
  }

  // MARK: - Code Analysis

  public func analyzeMemoryUsage(sourceFile: String, optimizationLevel: String) async -> MCPResult {
      logger.info("Analyzing memory usage for: \(sourceFile)")

      let command = [
          "swift", "frontend", "-emit-sil",
          "-O" + optimizationLevel,
          "-enable-experimental-feature", "Embedded",
          sourceFile
      ]

      let result = await runCommand(command, in: swiftZephyrModule)

      // Parse SIL output for memory analysis
      let memoryAnalysis = analyzeSILOutput(result.output)

      return MCPResult(
          success: result.exitCode == 0,
          output: memoryAnalysis,
          error: result.error
      )
  }

  public func checkConcurrency(sourceFile: String, strictMode: Bool) async -> MCPResult {
      logger.info("Checking concurrency compliance for: \(sourceFile)")

      var command = ["swift", "frontend", "-typecheck"]
      command.append(sourceFile)

      if strictMode {
          command.append(contentsOf: ["-strict-concurrency=complete"])
      }

      let result = await runCommand(command, in: swiftZephyrModule)
      return MCPResult(
          success: result.exitCode == 0,
          output: "Concurrency check \(result.exitCode == 0 ? "passed" : "failed")",
          error: result.error
      )
  }

  // MARK: - Development Tools

  public func formatCode(sourceFile: String, inPlace: Bool) async -> MCPResult {
    logger.info("Formatting Swift code: \(sourceFile)")

    var command = ["swift-format"]
    command.append(contentsOf: ["--configuration", "\(swiftZephyrModule)/.swift-format"])
    if inPlace {
      command.append("--in-place")
    }
    command.append(sourceFile)

    let result = await runCommand(command, in: swiftZephyrModule)
    return MCPResult(
      success: result.exitCode == 0,
      output: result.output,
      error: result.error
    )
  }

  public func generateSwiftFile(fileName: String, imports: [String], types: [String], protocols: [String]) async -> MCPResult {
    logger.info("Generating Swift file: \(fileName)")

    let content = generateSwiftFileStructure(fileName: fileName, imports: imports, types: types, protocols: protocols)

    do {
      let filePath = "\(swiftZephyrModule)/Sources/\(fileName)"
      let fileURL = URL(fileURLWithPath: filePath)
      try content.write(to: fileURL, atomically: true, encoding: .utf8)
      return MCPResult(
        success: true,
        output: "Generated Swift file: \(filePath)",
        error: nil
      )
    } catch {
      return MCPResult(
        success: false,
        output: "",
        error: "Failed to write file: \(error.localizedDescription)"
      )
    }
  }

  public func lintCode(sourceFile: String, embeddedRules: Bool) async -> MCPResult {
      logger.info("Linting Swift code: \(sourceFile)")

      var command = ["swiftlint", "lint"]
      if embeddedRules {
          command.append(contentsOf: ["--config", "\(swiftZephyrModule)/.swiftlint-embedded.yml"])
      }
      command.append(sourceFile)

      let result = await runCommand(command, in: swiftZephyrModule)
      return MCPResult(
          success: result.exitCode == 0,
          output: result.output,
          error: result.error
      )
  }

  // MARK: - Documentation

  public func generateDocumentation(target: String?, outputFormat: String) async -> MCPResult {
      logger.info("Generating documentation in format: \(outputFormat)")

      var command = ["swift", "package"]

      if outputFormat == "docc" {
          command.append("generate-documentation")
          if let target = target {
              command.append(contentsOf: ["--target", target])
          }
      } else {
          // HTML or other formats
          command.append("generate-documentation")
          command.append(contentsOf: ["--output-format", outputFormat])
      }

      let result = await runCommand(command, in: swiftZephyrModule)
      return MCPResult(
          success: result.exitCode == 0,
          output: result.output,
          error: result.error
      )
  }

  // MARK: - Helper Methods

  private func runCommand(_ command: [String], in directory: String) async -> CommandResult {
      return await withCheckedContinuation { continuation in
          let process = Process()
          process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
          process.arguments = command
          process.currentDirectoryURL = URL(fileURLWithPath: directory)

          let outputPipe = Pipe()
          let errorPipe = Pipe()
          process.standardOutput = outputPipe
          process.standardError = errorPipe

          do {
              try process.run()
              process.waitUntilExit()

              let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
              let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

              let output = String(data: outputData, encoding: .utf8) ?? ""
              let error = String(data: errorData, encoding: .utf8) ?? ""

              continuation.resume(returning: CommandResult(
                  exitCode: Int(process.terminationStatus),
                  output: output,
                  error: error
              ))
          } catch {
              continuation.resume(returning: CommandResult(
                  exitCode: -1,
                  output: "",
                  error: error.localizedDescription
              ))
          }
      }
  }

  private func analyzeSILOutput(_ silOutput: String) -> String {
      // Basic SIL analysis for memory usage patterns
      let lines = silOutput.components(separatedBy: .newlines)
      var allocations = 0
      var deallocations = 0
      var retainCount = 0
      var releaseCount = 0

      for line in lines {
          if line.contains("alloc_") {
              allocations += 1
          }
          if line.contains("dealloc") {
              deallocations += 1
          }
          if line.contains("strong_retain") {
              retainCount += 1
          }
          if line.contains("strong_release") {
              releaseCount += 1
          }
      }

      return """
      Memory Analysis Results:
      - Allocations: \(allocations)
      - Deallocations: \(deallocations)
      - Retains: \(retainCount)
      - Releases: \(releaseCount)
      - Balance: \(allocations - deallocations) allocations, \(retainCount - releaseCount) retains
      """
  }

  private func generateSwiftFileStructure(fileName: String, imports: [String], types: [String], protocols: [String]) -> String {
    var content = """
// Imports
"""

    // Add imports with proper ordering
    for importStatement in imports.sorted() {
      content += "\nimport \(importStatement)"
    }

    content += "\n\n"

    // Add protocols
    if !protocols.isEmpty {
      content += "// Public protocols\n"
      for protocolName in protocols {
        content += "public protocol \(protocolName) {}\n"
      }
      content += "\n"
    }

    // Add types
    if !types.isEmpty {
      content += "// Public types\n"
      for typeName in types {
        content += """
public struct \(typeName) {
  // Implementation
}

"""
      }
    }

    // Add MARK sections structure
    content += """
// MARK: - Extension

// MARK: - Public

// MARK: - Internal

// MARK: - Private

"""

    return content
  }
}

// MARK: - Supporting Types

public struct MCPResult {
  public let success: Bool
  public let output: String
  public let error: String?

  public init(success: Bool, output: String, error: String?) {
      self.success = success
      self.output = output
      self.error = error
  }
}

private struct CommandResult {
  let exitCode: Int
  let output: String
  let error: String
}
