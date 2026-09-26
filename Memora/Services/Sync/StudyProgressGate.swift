import Foundation

/// One account's progress POST and reset sequence cannot interleave. A waiting
/// reset takes priority after the current HTTP operation finishes.
@MainActor
final class StudyProgressGate {
    var resetCalls = Set<String>()
    private var owners = Set<UUID>()
    private var waiters: [UUID: [CheckedContinuation<Void, Never>]] = [:]

    func tryAcquire(_ owner: UUID) -> Bool { owners.insert(owner).inserted }
    func acquire(_ owner: UUID) async {
        if tryAcquire(owner) { return }
        await withCheckedContinuation { waiters[owner, default: []].append($0) }
    }
    func hasWaiter(_ owner: UUID) -> Bool { !(waiters[owner]?.isEmpty ?? true) }
    func release(_ owner: UUID) {
        if var queued = waiters[owner], !queued.isEmpty {
            let next = queued.removeFirst()
            waiters[owner] = queued
            next.resume()
        } else {
            waiters[owner] = nil
            owners.remove(owner)
        }
    }
}
