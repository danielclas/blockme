import Foundation
import Network
import NetworkExtension

final class FilterDataProvider: NEFilterDataProvider {
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let blockedDomains = BlockmeFilterConfiguration.blockedDomains(from: filterConfiguration.vendorConfiguration)
        guard !blockedDomains.isEmpty else {
            return .allow()
        }

        for host in hostCandidates(for: flow) where BlockmeFilterConfiguration.matches(host: host, blockedDomains: blockedDomains) {
            return .drop()
        }

        return .allow()
    }

    private func hostCandidates(for flow: NEFilterFlow) -> [String] {
        var candidates: [String] = []

        if let host = flow.url?.host, !host.isEmpty {
            candidates.append(host)
        }

        if let socketFlow = flow as? NEFilterSocketFlow {
            if let host = socketFlow.remoteHostname, !host.isEmpty {
                candidates.append(host)
            }

            if #available(macOS 15.0, *) {
                let endpoint = socketFlow.remoteFlowEndpoint
                switch endpoint {
                case .hostPort(let host, _):
                    switch host {
                    case .name(let hostname, _):
                        candidates.append(hostname)
                    default:
                        break
                    }
                default:
                    break
                }
            }
        }

        return Array(Set(candidates))
    }
}
