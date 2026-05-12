import Foundation
import SystemExtensions

enum SystemExtensionActivationResult {
    case activated
    case needsApproval
    case needsReboot
}

struct SystemExtensionSnapshot {
    let isEnabled: Bool
    let isAwaitingApproval: Bool
    let isUninstalling: Bool
}

@MainActor
final class SystemExtensionManager {
    func activateExtension(identifier: String) async throws -> SystemExtensionActivationResult {
        try await withCheckedThrowingContinuation { continuation in
            let request = OSSystemExtensionRequest.activationRequest(
                forExtensionWithIdentifier: identifier,
                queue: .main
            )
            let bridge = ActivationRequestBridge(continuation: continuation)
            bridge.start(request: request)
        }
    }

    func loadProperties(identifier: String) async -> SystemExtensionSnapshot? {
        await withCheckedContinuation { continuation in
            let request = OSSystemExtensionRequest.propertiesRequest(
                forExtensionWithIdentifier: identifier,
                queue: .main
            )
            let bridge = PropertiesRequestBridge(continuation: continuation)
            bridge.start(request: request)
        }
    }
}

private final class ActivationRequestBridge: NSObject, OSSystemExtensionRequestDelegate {
    private var continuation: CheckedContinuation<SystemExtensionActivationResult, Error>?
    private var keepAlive: ActivationRequestBridge?
    private var didFinish = false

    init(continuation: CheckedContinuation<SystemExtensionActivationResult, Error>) {
        self.continuation = continuation
    }

    func start(request: OSSystemExtensionRequest) {
        keepAlive = self
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        finish(with: .success(.needsApproval))
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        let activationResult: SystemExtensionActivationResult = switch result {
        case .completed:
            .activated
        case .willCompleteAfterReboot:
            .needsReboot
        @unknown default:
            .activated
        }

        finish(with: .success(activationResult))
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        finish(with: .failure(error))
    }

    private func finish(with result: Result<SystemExtensionActivationResult, Error>) {
        guard !didFinish else { return }
        didFinish = true

        switch result {
        case .success(let value):
            continuation?.resume(returning: value)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }

        continuation = nil
        keepAlive = nil
    }
}

private final class PropertiesRequestBridge: NSObject, OSSystemExtensionRequestDelegate {
    private var continuation: CheckedContinuation<SystemExtensionSnapshot?, Never>?
    private var keepAlive: PropertiesRequestBridge?
    private var didFinish = false
    private var snapshot: SystemExtensionSnapshot?

    init(continuation: CheckedContinuation<SystemExtensionSnapshot?, Never>) {
        self.continuation = continuation
    }

    func start(request: OSSystemExtensionRequest) {
        keepAlive = self
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        guard let properties = properties.first else { return }
        snapshot = SystemExtensionSnapshot(
            isEnabled: properties.isEnabled,
            isAwaitingApproval: properties.isAwaitingUserApproval,
            isUninstalling: properties.isUninstalling
        )
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        if snapshot == nil {
            snapshot = SystemExtensionSnapshot(
                isEnabled: false,
                isAwaitingApproval: true,
                isUninstalling: false
            )
        }
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        finish()
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        continuation?.resume(returning: snapshot)
        continuation = nil
        keepAlive = nil
    }
}
