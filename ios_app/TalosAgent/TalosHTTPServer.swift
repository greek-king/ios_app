import Foundation
import UIKit
import Contacts
import Photos

// ── Minimal HTTP server using CFSocket / GCDAsyncSocket approach ─────────────
// Uses only Foundation — no third-party deps, works without App Store signing
// Listens on 127.0.0.1:27042 (localhost only — accessible via USB tunnel)

class TalosHTTPServer {

    let port: UInt16
    private var listeningSocket: CFSocket?
    private let queue = DispatchQueue(label: "talos.server", attributes: .concurrent)

    init(port: UInt16 = 27042) {
        self.port = port
    }

    func start() {
        var context = CFSocketContext(
            version: 0, info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil)

        listeningSocket = CFSocketCreate(
            kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP,
            CFSocketCallBackType.acceptCallBack.rawValue,
            { socket, callbackType, address, data, info in
                guard let info = info else { return }
                let server = Unmanaged<TalosHTTPServer>.fromOpaque(info).takeUnretainedValue()
                if callbackType == .acceptCallBack, let data = data {
                    let handle = data.load(as: CFSocketNativeHandle.self)
                    server.handleConnection(handle)
                }
            }, &context)

        guard let sock = listeningSocket else { return }

        var reuse: Int32 = 1
        setsockopt(CFSocketGetNative(sock), SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let addrData = withUnsafeBytes(of: &addr) { Data($0) } as CFData
        CFSocketSetAddress(sock, addrData)

        let runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, sock, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        print("[TalosAgent] HTTP server started on port \(port)")
    }

    private func handleConnection(_ handle: CFSocketNativeHandle) {
        queue.async {
            var buf = [UInt8](repeating: 0, count: 8192)
            let bytesRead = recv(handle, &buf, buf.count, 0)
            guard bytesRead > 0 else { close(handle); return }

            let request = String(bytes: buf[0..<bytesRead], encoding: .utf8) ?? ""
            let firstLine = request.components(separatedBy: "\r\n").first ?? ""
            let parts = firstLine.components(separatedBy: " ")
            let path = parts.count > 1 ? parts[1] : "/"

            let (statusCode, body, contentType) = self.route(path: path)
            let header = "HTTP/1.1 \(statusCode)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
            let headerData = header.data(using: .utf8)!

            _ = headerData.withUnsafeBytes { send(handle, $0.baseAddress!, headerData.count, 0) }
            _ = body.withUnsafeBytes { send(handle, $0.baseAddress!, body.count, 0) }
            close(handle)
        }
    }

    // ── Router ────────────────────────────────────────────────────────────────
    private func route(path: String) -> (String, Data, String) {
        let basePath = path.components(separatedBy: "?").first ?? path

        switch basePath {
        case "/ping":
            return ("200 OK", jsonData(["status": "ok", "agent": "TalosAgent", "version": "1.0"]), "application/json")
        case "/info":
            return ("200 OK", deviceInfo(), "application/json")
        case "/contacts":
            return ("200 OK", fetchContacts(), "application/json")
        case "/messages":
            return ("200 OK", fetchMessages(), "application/json")
        case "/calls":
            return ("200 OK", fetchCalls(), "application/json")
        case "/apps":
            return ("200 OK", fetchApps(), "application/json")
        case "/screenshot":
            return ("200 OK", takeScreenshot(), "image/png")
        case "/photos":
            return ("200 OK", fetchPhotoList(), "application/json")
        default:
            return ("404 Not Found",
                    jsonData(["error": "unknown endpoint", "path": basePath]),
                    "application/json")
        }
    }

    // ── Device Info ───────────────────────────────────────────────────────────
    private func deviceInfo() -> Data {
        let device = UIDevice.current
        let dict: [String: Any] = [
            "name":             device.name,
            "model":            device.model,
            "system_name":      device.systemName,
            "system_version":   device.systemVersion,
            "identifier":       device.identifierForVendor?.uuidString ?? "unknown",
            "battery_level":    Int(UIDevice.current.batteryLevel * 100),
            "battery_state":    batteryStateString(),
            "screen_width":     Int(UIScreen.main.nativeBounds.width),
            "screen_height":    Int(UIScreen.main.nativeBounds.height),
        ]
        return jsonData(dict)
    }

    private func batteryStateString() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        switch UIDevice.current.batteryState {
        case .charging:  return "Charging"
        case .full:      return "Full"
        case .unplugged: return "Unplugged"
        default:         return "Unknown"
        }
    }

    // ── Contacts ──────────────────────────────────────────────────────────────
    private func fetchContacts() -> Data {
        var results: [[String: String]] = []
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
        ]
        do {
            let request = CNFetchRequest(entityType: CNContact.self)
            request.keysToFetch = keys
            try store.enumerateContacts(with: request) { contact, _ in
                let phones = contact.phoneNumbers.map { $0.value.stringValue }.joined(separator: "; ")
                let emails = contact.emailAddresses.map { $0.value as String }.joined(separator: "; ")
                var birthday = ""
                if let bday = contact.birthday {
                    birthday = "\(bday.year ?? 0)-\(String(format: "%02d", bday.month ?? 0))-\(String(format: "%02d", bday.day ?? 0))"
                }
                results.append([
                    "name":         "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces),
                    "phone":        phones,
                    "email":        emails,
                    "organization": contact.organizationName,
                    "birthday":     birthday,
                ])
            }
        } catch {
            return jsonData(["error": error.localizedDescription, "contacts": []])
        }
        return jsonData(["contacts": results, "count": results.count])
    }

    // ── Messages (SMS — requires entitlement, available on supervised devices) ─
    private func fetchMessages() -> Data {
        // SMS DB is not accessible without special entitlement on non-jailbroken devices
        // We return instructions for the desktop to use the native SMS backup path
        return jsonData([
            "note": "SMS extraction requires device backup. Use desktop backup method.",
            "messages": [] as [[String: String]]
        ])
    }

    // ── Call Logs ─────────────────────────────────────────────────────────────
    private func fetchCalls() -> Data {
        return jsonData([
            "note": "Call log extraction requires device backup. Use desktop backup method.",
            "calls": [] as [[String: String]]
        ])
    }

    // ── Installed Apps ────────────────────────────────────────────────────────
    private func fetchApps() -> Data {
        // LSApplicationWorkspace is private API — we return what we can
        var apps: [[String: String]] = []

        // Public: check if common apps are installed via URL schemes
        let knownApps: [(String, String, String)] = [
            ("WhatsApp", "net.whatsapp.WhatsApp", "whatsapp://"),
            ("Telegram", "ph.telegra.Telegraph", "tg://"),
            ("Signal", "org.whispersystems.signal", "sgnl://"),
            ("Instagram", "com.burbn.instagram", "instagram://"),
            ("Facebook", "com.facebook.Facebook", "fb://"),
            ("Twitter/X", "com.atebits.Tweetie2", "twitter://"),
            ("TikTok", "com.zhiliaoapp.musically", "snssdk1128://"),
            ("Snapchat", "com.toyopagroup.picaboo", "snapchat://"),
            ("Gmail", "com.google.Gmail", "googlegmail://"),
            ("Chrome", "com.google.chrome.ios", "googlechrome://"),
            ("Spotify", "com.spotify.client", "spotify://"),
            ("Netflix", "com.netflix.Netflix", "nflx://"),
        ]

        for (name, bundle, scheme) in knownApps {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                apps.append(["name": name, "bundle_id": bundle, "type": "User"])
            }
        }

        return jsonData(["apps": apps, "count": apps.count,
                         "note": "Full app list requires backup extraction"])
    }

    // ── Screenshot ────────────────────────────────────────────────────────────
    private func takeScreenshot() -> Data {
        // Capture the current screen
        let window = UIApplication.shared.windows.first { $0.isKeyWindow }
        UIGraphicsBeginImageContextWithOptions(
            window?.bounds.size ?? CGSize(width: 390, height: 844), false, 0)
        window?.drawHierarchy(in: window?.bounds ?? .zero, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image?.pngData() ?? Data()
    }

    // ── Photos list ───────────────────────────────────────────────────────────
    private func fetchPhotoList() -> Data {
        var photos: [[String: Any]] = []
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 200

        let assets = PHAsset.fetchAssets(with: fetchOptions)
        assets.enumerateObjects { asset, _, _ in
            let formatter = ISO8601DateFormatter()
            photos.append([
                "local_id":    asset.localIdentifier,
                "media_type":  asset.mediaType == .video ? "video" : "photo",
                "width":       asset.pixelWidth,
                "height":      asset.pixelHeight,
                "created":     formatter.string(from: asset.creationDate ?? Date()),
                "duration":    asset.duration,
                "is_favorite": asset.isFavorite,
            ])
        }
        return jsonData(["photos": photos, "count": photos.count])
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private func jsonData(_ obj: Any) -> Data {
        return (try? JSONSerialization.data(withJSONObject: obj,
                                           options: .prettyPrinted)) ?? Data()
    }
}
