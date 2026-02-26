import BackgroundTasks
import Foundation
import SwiftData

enum AutoImportBackgroundScheduler {
    static let refreshTaskIdentifier = "com.local.LanguageReader.autoRefresh"

    private static var isRegistered = false
    private static var modelContainer: ModelContainer?

    static func registerIfNeeded(container: ModelContainer) {
        modelContainer = container
        guard !isRegistered else { return }

        isRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask: refreshTask)
        }
    }

    static func scheduleIfNeeded() {
        let defaults = UserDefaults.standard
        let backgroundEnabled: Bool = {
            if defaults.object(forKey: AutoImportSettings.backgroundRefreshEnabledKey) == nil {
                return AutoImportSettings.defaultBackgroundRefreshEnabled
            }
            return defaults.bool(forKey: AutoImportSettings.backgroundRefreshEnabledKey)
        }()

        guard backgroundEnabled else { return }

        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(AutoImportSettings.defaultCooldownHours * 3600))
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(refreshTask: BGAppRefreshTask) {
        scheduleIfNeeded()

        let operation = Task { @MainActor () -> Bool in
            guard let modelContainer else { return true }
            let context = ModelContext(modelContainer)
            _ = await AutoImportCoordinator.shared.performAutoTopUpIfNeeded(
                modelContext: context,
                trigger: .backgroundRefresh
            )
            return true
        }

        refreshTask.expirationHandler = {
            operation.cancel()
        }

        Task {
            let success = await operation.value
            refreshTask.setTaskCompleted(success: success)
        }
    }
}
