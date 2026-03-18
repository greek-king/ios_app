import UIKit
import Contacts
import CallKit
import Messages
import Photos
import ReplayKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var server: TalosHTTPServer?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MainViewController()
        window?.makeKeyAndVisible()

        server = TalosHTTPServer(port: 27042)
        server?.start()

        // Keep alive in background
        application.beginBackgroundTask(withName: "TalosAgent") { }
        return true
    }
}
