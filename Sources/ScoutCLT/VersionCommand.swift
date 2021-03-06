import ArgumentParser
import Scout

struct VersionCommand: ParsableCommand {

    // MARK: - Constants

    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "display the current version of the program")

    // MARK: - Functions

    func run() throws {
        print(Version.current)
    }
}
