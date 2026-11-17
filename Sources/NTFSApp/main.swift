import Foundation

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--render-demo"), args.count > i + 1 {
    renderDemo(to: args[i + 1])
} else if args.contains("--reinstall-helper") {
    // Restarts the root helper so it picks up the new binary after an app update.
    let client = HelperClient()
    try? await client.unregister()
    do { try client.register(); print("helper:", client.status) } catch { print("register failed:", error) }
} else {
    NTFSMenuApp.main()
}
