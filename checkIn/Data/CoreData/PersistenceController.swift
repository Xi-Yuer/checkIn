import CoreData
import Foundation

final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    let storeURL: URL?
    let repositoryStore: CoreDataStore

    init(
        inMemory: Bool = false,
        storeURL: URL? = nil,
        model: NSManagedObjectModel? = nil
    ) {
        let resolvedModel = model ?? Self.loadManagedObjectModel()
        let container = NSPersistentContainer(name: "CheckInModel", managedObjectModel: resolvedModel)
        self.container = container

        let description = NSPersistentStoreDescription()
        let resolvedStoreURL: URL?
        if inMemory {
            description.type = NSInMemoryStoreType
            description.url = URL(fileURLWithPath: "/dev/null")
            resolvedStoreURL = nil
        } else {
            let resolvedURL = storeURL ?? Self.defaultStoreURL()
            description.type = NSSQLiteStoreType
            description.url = resolvedURL
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            description.setOption(
                FileProtectionType.completeUntilFirstUserAuthentication.rawValue as NSString,
                forKey: NSPersistentStoreFileProtectionKey
            )
            resolvedStoreURL = resolvedURL
        }
        self.storeURL = resolvedStoreURL
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadingError: Error?
        container.loadPersistentStores { _, error in
            loadingError = error
        }
        if let loadingError {
            fatalError("Unable to load CheckIn Core Data store: \(loadingError.localizedDescription)")
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.name = "checkIn.viewContext"
        repositoryStore = CoreDataStore(container: container)
    }

    static func temporarySQLite(at directoryURL: URL? = nil) -> PersistenceController {
        let baseURL = directoryURL ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("checkIn-tests-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        } catch {
            fatalError("Unable to create temporary Core Data directory: \(error.localizedDescription)")
        }
        return PersistenceController(storeURL: baseURL.appendingPathComponent("CheckIn.sqlite"))
    }

    private static func defaultStoreURL() -> URL {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = appSupport.appendingPathComponent("checkIn", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("CheckIn.sqlite")
        } catch {
            fatalError("Unable to create Application Support directory: \(error.localizedDescription)")
        }
    }

    static func loadManagedObjectModel(version: String? = nil) -> NSManagedObjectModel {
        let bundles = [Bundle.main] + Bundle.allFrameworks + Bundle.allBundles
        for bundle in bundles {
            if let modelDirectoryURL = bundle.url(forResource: "CheckInModel", withExtension: "momd") {
                if let version,
                   let model = NSManagedObjectModel(
                       contentsOf: modelDirectoryURL.appendingPathComponent("\(version).mom")
                   ) {
                    return model
                }
                if version == nil, let model = NSManagedObjectModel(contentsOf: modelDirectoryURL) {
                    return model
                }
            }
            if version == nil,
               let modelURL = bundle.url(forResource: "CheckInModel", withExtension: "mom"),
               let model = NSManagedObjectModel(contentsOf: modelURL) {
                return model
            }
        }
        fatalError("CheckInModel \(version ?? "current") is missing from the app bundle")
    }
}

actor CoreDataStore {
    private let container: NSPersistentContainer

    init(container: NSPersistentContainer) {
        self.container = container
    }

    func perform<T: Sendable>(
        _ operation: @Sendable (NSManagedObjectContext) throws -> T
    ) throws -> T {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        context.name = "checkIn.repositoryContext"

        var outcome: Result<T, Error>?
        context.performAndWait {
            outcome = Result { try operation(context) }
        }
        guard let outcome else {
            throw RepositoryError.persistence("Core Data transaction did not finish")
        }
        return try outcome.get()
    }
}
