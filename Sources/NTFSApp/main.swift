import Foundation
import NTFSCore

// TEMPORARY smoke-test entry point for Task 5. Replaced by the SwiftUI MenuBarExtra app in Task 9.
let client = HelperClient()
let args = CommandLine.arguments.dropFirst()

switch args.first {
case "status":
    print("helper status:", client.status)
case "register":
    do { try client.register(); print("registered; status:", client.status) }
    catch { print("register failed:", error) }
case "probe":
    guard let dev = args.dropFirst().first else { print("usage: probe /dev/diskN"); exit(2) }
    do { print(try await client.send(.probe(device: dev))) }
    catch { print("error:", error) }
case "mount":
    guard let dev = args.dropFirst().first else { print("usage: mount /dev/diskN [label]"); exit(2) }
    do { print(try await client.send(.mount(device: dev, label: args.dropFirst(2).first))) }
    catch { print("error:", error) }
case "unmount":
    guard let dev = args.dropFirst().first else { print("usage: unmount /dev/diskN"); exit(2) }
    do { print(try await client.send(.unmount(device: dev))) }
    catch { print("error:", error) }
default:
    print("usage: NTFS status | register | probe|mount|unmount /dev/diskN")
}
