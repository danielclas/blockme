import AppKit
import Darwin
import SwiftUI
import SteadfastCore

@MainActor
enum BlockmeDesktopLauncher {
    static func main() {
        if CommandLine.arguments.count > 1 {
            exit(CLI.run(arguments: CommandLine.arguments).rawValue)
        }

        BlockmeDesktopApp.main()
    }
}

BlockmeDesktopLauncher.main()
