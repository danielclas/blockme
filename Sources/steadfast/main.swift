import Darwin
import Foundation
import SteadfastCore

@main
struct SteadfastMain {
    static func main() {
        let code = CLI.run(arguments: CommandLine.arguments)
        exit(code.rawValue)
    }
}
