import Foundation
import FirebaseDatabase
import FirebaseCore

final class FirebaseServerClock {
    static let shared = FirebaseServerClock()

    private var offsetRef: DatabaseReference?
    private var offsetHandle: DatabaseHandle?
    private var serverOffsetMs: Double = 0
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        let root: DatabaseReference
        let options = FirebaseApp.app()?.options
        if let configuredURL = options?.databaseURL, !configuredURL.isEmpty {
            root = Database.database(url: configuredURL).reference()
        } else if let projectID = options?.projectID, !projectID.isEmpty {
            root = Database.database(url: "https://\(projectID)-default-rtdb.firebaseio.com").reference()
        } else {
            root = Database.database().reference()
        }

        let ref = root.child(".info/serverTimeOffset")
        offsetRef = ref
        offsetHandle = ref.observe(.value) { [weak self] snapshot in
            if let ms = snapshot.value as? Double {
                self?.serverOffsetMs = ms
            } else if let num = snapshot.value as? NSNumber {
                self?.serverOffsetMs = num.doubleValue
            }
        }
    }

    func serverNowEpoch() -> TimeInterval {
        Date().timeIntervalSince1970 + (serverOffsetMs / 1000.0)
    }
}
