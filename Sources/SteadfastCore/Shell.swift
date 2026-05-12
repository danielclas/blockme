import Foundation

public struct CommandResult: Sendable {
    public let executable: String
    public let arguments: [String]
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
}

public enum ShellError: Error, LocalizedError {
    case commandFailed(CommandResult)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let result):
            let renderedArguments = result.arguments.joined(separator: " ")
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                return "Command failed: \(result.executable) \(renderedArguments)"
            }

            return "Command failed: \(result.executable) \(renderedArguments)\n\(message)"
        }
    }
}

public enum Shell {
    @discardableResult
    public static func run(_ executable: String, arguments: [String] = [], allowFailure: Bool = false) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let result = CommandResult(
            executable: executable,
            arguments: arguments,
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )

        if result.exitCode != 0 && !allowFailure {
            throw ShellError.commandFailed(result)
        }

        return result
    }
}
