import Foundation

enum DeepLinkDestination: Hashable, Sendable {
    case today
    case task(UUID)
}

struct DeepLinkRouter: Sendable {
    static let scheme = "checkin"

    func parse(_ url: URL) -> DeepLinkDestination? {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        switch url.host?.lowercased() {
        case "today":
            return url.pathComponents.count <= 1 ? .today : nil
        case "task":
            let components = url.pathComponents.filter { $0 != "/" }
            guard components.count == 1, let id = UUID(uuidString: components[0]) else { return nil }
            return .task(id)
        default:
            return nil
        }
    }

    func resolve(
        _ url: URL,
        tasks: any TaskRepository
    ) async -> DeepLinkDestination {
        guard let destination = parse(url) else { return .today }
        guard case let .task(id) = destination else { return destination }
        guard let task = try? await tasks.get(id: id), !task.isArchived else { return .today }
        return .task(id)
    }
}
