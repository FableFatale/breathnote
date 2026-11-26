import AVFoundation
import Flutter
import StoreKit
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "BreathnoteNativePlugin") {
      BreathnoteNativeBridge.shared.register(with: registrar.messenger(), appDelegate: self)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    BreathnoteNativeBridge.shared.pauseActiveAudio()
    super.applicationWillResignActive(application)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    BreathnoteNativeBridge.shared.pauseActiveAudio()
    super.applicationDidEnterBackground(application)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    BreathnoteNativeBridge.shared.shutdown()
    super.applicationWillTerminate(application)
  }
}

final class BreathnoteNativeBridge: NSObject, FlutterStreamHandler, UIDocumentPickerDelegate {
  static let shared = BreathnoteNativeBridge()

  private let audioControlChannelName = "app.breathnote/audio_control"
  private let pitchEventsChannelName = "app.breathnote/pitch_events"
  private let preferencesChannelName = "app.breathnote/preferences"
  private let billingChannelName = "app.breathnote/billing"
  private let filePickerChannelName = "app.breathnote/file_picker"
  private let shareChannelName = "app.breathnote/share"

  private let preferencesSuiteName = "breathnote_preferences"
  private let maxImportedFileBytes = 2 * 1024 * 1024

  private weak var appDelegate: AppDelegate?
  private var eventSink: FlutterEventSink?
  private var pendingFilePickerResult: FlutterResult?
  private var pendingFilePickerDefaultName: String = "imported.mid"

  private lazy var pitchDetector = PitchDetector(
    onReading: { [weak self] reading in
      DispatchQueue.main.async {
        self?.eventSink?(reading)
      }
    },
    onError: { [weak self] code, message in
      DispatchQueue.main.async {
        self?.eventSink?(FlutterError(code: code, message: message, details: nil))
      }
    }
  )

  private let guideTonePlayer = GuideTonePlayer()
  private let metronomePlayer = MetronomePlayer()

  func register(with messenger: FlutterBinaryMessenger, appDelegate: AppDelegate) {
    self.appDelegate = appDelegate

    FlutterMethodChannel(name: audioControlChannelName, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleAudioMethod(call, result: result)
      }

    FlutterEventChannel(name: pitchEventsChannelName, binaryMessenger: messenger)
      .setStreamHandler(self)

    FlutterMethodChannel(name: preferencesChannelName, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handlePreferencesMethod(call, result: result)
      }

    FlutterMethodChannel(name: billingChannelName, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleBillingMethod(call, result: result)
      }

    FlutterMethodChannel(name: filePickerChannelName, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleFilePickerMethod(call, result: result)
      }

    FlutterMethodChannel(name: shareChannelName, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handleShareMethod(call, result: result)
      }
  }

  func pauseActiveAudio() {
    pitchDetector.stop()
    guideTonePlayer.stop()
  }

  func shutdown() {
    pitchDetector.stop()
    guideTonePlayer.stop()
    metronomePlayer.release()
  }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    pitchDetector.stop()
    return nil
  }

  // MARK: - Audio Control & Haptics

  private func handleAudioMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "hasMicrophonePermission":
      result(BreathnoteAudioSession.hasMicrophonePermission())

    case "requestMicrophonePermission":
      requestMicrophonePermission(result: result)

    case "startPitchDetection":
      guard BreathnoteAudioSession.hasMicrophonePermission() else {
        result(
          FlutterError(
            code: "microphone_permission_required",
            message: "Microphone permission has not been granted.",
            details: nil
          )
        )
        return
      }
      guideTonePlayer.stop()
      let sensitivity = (args?["sensitivity"] as? NSNumber)?.doubleValue ?? 0.68
      result(pitchDetector.start(initialSensitivity: sensitivity))

    case "setSensitivity":
      let value = (args?["value"] as? NSNumber)?.doubleValue ?? 0.68
      pitchDetector.sensitivity = value
      result(nil)

    case "stopPitchDetection":
      pitchDetector.stop()
      result(nil)

    case "playGuideSequence":
      let rawFrequencies = (args?["frequencies"] as? [NSNumber])?.map { $0.doubleValue } ?? []
      if rawFrequencies.isEmpty || !rawFrequencies.contains(where: { $0 > 0 }) {
        result(
          FlutterError(
            code: "invalid_guide_sequence",
            message: "At least one positive frequency is required.",
            details: nil
          )
        )
        return
      }
      let beats = (args?["beats"] as? [NSNumber])?.map { $0.doubleValue }
      let speed = (args?["speed"] as? NSNumber)?.doubleValue ?? 1.0
      let repeatSequence = (args?["repeat"] as? Bool) ?? false
      pitchDetector.stop()
      do {
        let durationMs = try guideTonePlayer.play(
          frequencies: rawFrequencies,
          speed: speed,
          repeatSequence: repeatSequence,
          beats: beats
        )
        result(durationMs)
      } catch {
        result(
          FlutterError(
            code: "guide_audio_error",
            message: error.localizedDescription.isEmpty
              ? "The guide tone could not be started."
              : error.localizedDescription,
            details: nil
          )
        )
      }

    case "playMetronomeClick":
      let accent = (args?["accent"] as? Bool) ?? false
      metronomePlayer.playClick(accent: accent, pitchDetectorRunning: pitchDetector.isRunning)
      result(nil)

    case "stopGuideSequence":
      guideTonePlayer.stop()
      result(nil)

    case "triggerHaptic":
      let type = (args?["type"] as? String) ?? "selection"
      triggerNativeHaptic(type: type)
      result(nil)

    case "openAppSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestMicrophonePermission(result: @escaping FlutterResult) {
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .granted:
        result("granted")
      case .denied:
        result("permanentlyDenied")
      case .undetermined:
        AVAudioApplication.requestRecordPermission { granted in
          DispatchQueue.main.async {
            result(granted ? "granted" : "denied")
          }
        }
      @unknown default:
        result("denied")
      }
    } else {
      let session = AVAudioSession.sharedInstance()
      switch session.recordPermission {
      case .granted:
        result("granted")
      case .denied:
        result("permanentlyDenied")
      case .undetermined:
        session.requestRecordPermission { granted in
          DispatchQueue.main.async {
            result(granted ? "granted" : "denied")
          }
        }
      @unknown default:
        result("denied")
      }
    }
  }

  private func triggerNativeHaptic(type: String) {
    DispatchQueue.main.async {
      switch type {
      case "reed":
        let first = UIImpactFeedbackGenerator(style: .rigid)
        first.prepare()
        first.impactOccurred(intensity: 0.72)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
          let second = UIImpactFeedbackGenerator(style: .medium)
          second.impactOccurred(intensity: 0.95)
        }
      case "success":
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
      case "warning":
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
      case "light":
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
      default:
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
      }
    }
  }

  // MARK: - Preferences

  private func preferencesStore() -> UserDefaults {
    return UserDefaults(suiteName: preferencesSuiteName) ?? UserDefaults.standard
  }

  private func handlePreferencesMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let store = preferencesStore()
    switch call.method {
    case "getAll":
      var payload = store.persistentDomain(forName: preferencesSuiteName) ?? [:]
      let shortVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.9.0"
      let buildVersion =
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "23"
      payload["__runtimeAppVersion"] = "v\(shortVersion) (\(buildVersion))"
      result(payload)

    case "setValue":
      guard let args = call.arguments as? [String: Any],
        let key = args["key"] as? String,
        let rawValue = args["value"]
      else {
        result(
          FlutterError(
            code: "invalid_preference",
            message: "A key and value are required.",
            details: nil
          )
        )
        return
      }

      if let str = rawValue as? String {
        store.set(str, forKey: key)
      } else if let number = rawValue as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
          store.set(number.boolValue, forKey: key)
        } else if CFNumberIsFloatType(number) {
          store.set(number.doubleValue, forKey: key)
        } else {
          store.set(number.int64Value, forKey: key)
        }
      } else {
        result(
          FlutterError(
            code: "unsupported_preference",
            message: "Unsupported preference type.",
            details: nil
          )
        )
        return
      }
      result(nil)

    case "clear":
      store.removePersistentDomain(forName: preferencesSuiteName)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - StoreKit 2 Billing

  private func handleBillingMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let productId = (args?["productId"] as? String) ?? "breathnote_pro_lifetime"

    switch call.method {
    case "purchaseProLifetime":
      Task {
        do {
          let products = try await Product.products(for: [productId])
          guard let product = products.first else {
            await MainActor.run { result("unavailable") }
            return
          }
          let purchaseOutcome = try await product.purchase()
          switch purchaseOutcome {
          case .success(let verification):
            switch verification {
            case .verified(let transaction):
              await transaction.finish()
              await MainActor.run { result("purchased") }
            case .unverified:
              await MainActor.run { result("error") }
            }
          case .userCancelled:
            await MainActor.run { result("cancelled") }
          case .pending:
            await MainActor.run { result("cancelled") }
          @unknown default:
            await MainActor.run { result("error") }
          }
        } catch {
          await MainActor.run { result("unavailable") }
        }
      }

    case "restorePurchases":
      Task {
        do {
          try await AppStore.sync()
          var unlocked = false
          for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
              transaction.productID == productId,
              transaction.revocationDate == nil
            {
              unlocked = true
              break
            }
          }
          await MainActor.run {
            result(unlocked ? "restored" : "notFound")
          }
        } catch {
          await MainActor.run { result("unavailable") }
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - File Picker (MIDI / MusicXML / JSON Backup)

  private func handleFilePickerMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickScoreFile":
      var types: [UTType] = [.midi, .xml, .data]
      if let musicXml = UTType(filenameExtension: "musicxml") {
        types.insert(musicXml, at: 2)
      }
      presentDocumentPicker(
        contentTypes: types,
        defaultName: "imported.mid",
        result: result
      )

    case "pickJsonFile":
      presentDocumentPicker(
        contentTypes: [.json, .plainText, .data],
        defaultName: "breathnote_backup.json",
        result: result
      )

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func presentDocumentPicker(
    contentTypes: [UTType],
    defaultName: String,
    result: @escaping FlutterResult
  ) {
    if pendingFilePickerResult != nil {
      result(
        FlutterError(
          code: "file_picker_active",
          message: "A file picker request is already active.",
          details: nil
        )
      )
      return
    }
    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "file_picker_unavailable",
          message: "No active view controller available.",
          details: nil
        )
      )
      return
    }
    pendingFilePickerResult = result
    pendingFilePickerDefaultName = defaultName

    let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let pending = pendingFilePickerResult else { return }
    pendingFilePickerResult = nil

    guard let url = urls.first else {
      pending(nil)
      return
    }

    let securityScoped = url.startAccessingSecurityScopedResource()
    defer {
      if securityScoped {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let data = try Data(contentsOf: url)
      if data.isEmpty {
        pending(nil)
        return
      }
      if data.count > maxImportedFileBytes {
        pending(
          FlutterError(
            code: "file_read_error",
            message: "File exceeds 2MB limit.",
            details: nil
          )
        )
        return
      }
      let fileName =
        url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? pendingFilePickerDefaultName
        : url.lastPathComponent
      pending([
        "name": fileName,
        "bytes": FlutterStandardTypedData(bytes: data),
      ])
    } catch {
      pending(
        FlutterError(
          code: "file_read_error",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let pending = pendingFilePickerResult
    pendingFilePickerResult = nil
    pending?(nil)
  }

  // MARK: - Share Sheet (Achievement PNG & JSON Backup)

  private func handleShareMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "shareImage":
      guard let typedBytes = args?["bytes"] as? FlutterStandardTypedData,
        !typedBytes.data.isEmpty
      else {
        result(
          FlutterError(
            code: "invalid_image",
            message: "Image bytes are required.",
            details: nil
          )
        )
        return
      }
      let rawName = (args?["fileName"] as? String) ?? "breathnote_achievement.png"
      let safeBase = sanitizeFileName(rawName, fallback: "breathnote_achievement.png")
      let safeName = safeBase.lowercased().hasSuffix(".png") ? safeBase : "\(safeBase).png"
      let text = args?["text"] as? String
      let subject = args?["subject"] as? String

      do {
        let sharesDir = FileManager.default.temporaryDirectory.appendingPathComponent(
          "shares",
          isDirectory: true
        )
        try FileManager.default.createDirectory(at: sharesDir, withIntermediateDirectories: true)
        let outUrl = sharesDir.appendingPathComponent(safeName)
        try typedBytes.data.write(to: outUrl, options: .atomic)

        var items: [Any] = [outUrl]
        if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          items.append(text)
        }
        presentShareSheet(items: items, subject: subject, result: result)
      } catch {
        result(
          FlutterError(
            code: "share_error",
            message: error.localizedDescription,
            details: nil
          )
        )
      }

    case "shareTextFile":
      guard let content = args?["content"] as? String, !content.isEmpty else {
        result(
          FlutterError(
            code: "invalid_file",
            message: "File content is required.",
            details: nil
          )
        )
        return
      }
      let rawName = (args?["fileName"] as? String) ?? "breathnote_backup.json"
      let mimeType = (args?["mimeType"] as? String) ?? "application/json"
      let subject = args?["subject"] as? String
      let safeBase = sanitizeFileName(rawName, fallback: "breathnote_backup.json")
      let safeName =
        (mimeType == "application/json" && !safeBase.lowercased().hasSuffix(".json"))
        ? "\(safeBase).json"
        : safeBase

      do {
        let sharesDir = FileManager.default.temporaryDirectory.appendingPathComponent(
          "shares",
          isDirectory: true
        )
        try FileManager.default.createDirectory(at: sharesDir, withIntermediateDirectories: true)
        let outUrl = sharesDir.appendingPathComponent(safeName)
        guard let utf8Data = content.data(using: .utf8) else {
          result(
            FlutterError(
              code: "share_error",
              message: "Unable to encode UTF-8 file content.",
              details: nil
            )
          )
          return
        }
        try utf8Data.write(to: outUrl, options: .atomic)
        presentShareSheet(items: [outUrl], subject: subject, result: result)
      } catch {
        result(
          FlutterError(
            code: "share_error",
            message: error.localizedDescription,
            details: nil
          )
        )
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func presentShareSheet(
    items: [Any],
    subject: String?,
    result: @escaping FlutterResult
  ) {
    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "share_error",
          message: "No active view controller available.",
          details: nil
        )
      )
      return
    }
    let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
    if let subject = subject, !subject.isEmpty {
      activityVC.setValue(subject, forKey: "subject")
    }
    if let popover = activityVC.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(activityVC, animated: true) {
      result(true)
    }
  }

  private func sanitizeFileName(_ raw: String, fallback: String) -> String {
    let lastSegment =
      raw
      .components(separatedBy: CharacterSet(charactersIn: "/\\"))
      .last ?? fallback
    let cleaned = lastSegment.replacingOccurrences(
      of: "[^A-Za-z0-9._-]",
      with: "_",
      options: .regularExpression
    )
    return cleaned.isEmpty ? fallback : cleaned
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let keyWindow =
      scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
      ?? appDelegate?.window
      ?? scenes.flatMap { $0.windows }.first
    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
