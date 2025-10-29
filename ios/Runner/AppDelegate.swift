import UIKit
import Flutter
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var widgetChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up widget method channel
    setupWidgetChannel()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupWidgetChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    widgetChannel = FlutterMethodChannel(
      name: "carbon_tracker/widgets",
      binaryMessenger: controller.binaryMessenger
    )
    
    widgetChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleWidgetMethodCall(call: call, result: result)
    }
  }
  
  private func handleWidgetMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "updateWidgetData":
      updateWidgetData(arguments: call.arguments as? [String: Any], result: result)
      
    case "startLiveActivity":
      if #available(iOS 16.1, *) {
        startLiveActivity(arguments: call.arguments as? [String: Any], result: result)
      } else {
        result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.1+", details: nil))
      }
      
    case "updateLiveActivity":
      if #available(iOS 16.1, *) {
        updateLiveActivity(arguments: call.arguments as? [String: Any], result: result)
      } else {
        result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.1+", details: nil))
      }
      
    case "stopLiveActivity":
      if #available(iOS 16.1, *) {
        stopLiveActivity(result: result)
      } else {
        result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.1+", details: nil))
      }
      
    case "isLiveActivityActive":
      if #available(iOS 16.1, *) {
        checkLiveActivityStatus(result: result)
      } else {
        result(false)
      }
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func updateWidgetData(arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = arguments else {
      result(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
      return
    }
    
    // Update UserDefaults for App Groups
    if let sharedDefaults = UserDefaults(suiteName: "group.carbon-tracker.shared") {
      sharedDefaults.set(args["todayCO2"], forKey: "todayCO2")
      sharedDefaults.set(args["weeklyAverage"], forKey: "weeklyAverage")
      sharedDefaults.set(args["monthlyGoal"], forKey: "monthlyGoal")
      sharedDefaults.set(args["yesterdayCO2"], forKey: "yesterdayCO2")
      sharedDefaults.set(args["topCategory"], forKey: "topCategory")
      sharedDefaults.set(args["recentAchievements"], forKey: "recentAchievements")
      sharedDefaults.set(Date(), forKey: "lastUpdate")
      sharedDefaults.synchronize()
    }
    
    // Reload widgets (all kinds)
    WidgetCenter.shared.reloadTimelines(ofKind: "CarbonTrackerWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "ConfigurableCarbonTrackerWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "TodayExtensionWidget")
    if #available(iOS 17.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: "InteractiveCarbonWidget")
    }
    
    result(true)
  }
  
  @available(iOS 16.1, *)
  private func startLiveActivity(arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = arguments else {
      result(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
      return
    }
    
    let sessionName = args["sessionName"] as? String ?? "Carbon Tracking"
    let goalType = args["goalType"] as? String ?? "Daily Goal"
    let targetCO2 = args["targetCO2"] as? Double ?? 15.0
    let currentActivity = args["currentActivity"] as? String ?? "Tracking Started"
    let category = args["category"] as? String ?? "Transport"
    
    #if canImport(ActivityKit)
    // let success = LiveActivityManager.shared.startCarbonTracking(
    //   sessionName: sessionName,
    //   goalType: goalType,
    //   targetCO2: targetCO2,
    //   currentActivity: currentActivity,
    //   category: category
    // )
    // result(success)
    result(false) // Temporarily disabled
    #else
    result(false)
    #endif
  }
  
  @available(iOS 16.1, *)
  private func updateLiveActivity(arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = arguments else {
      result(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
      return
    }
    
    let currentCO2 = args["currentCO2"] as? Double ?? 0.0
    let currentActivity = args["currentActivity"] as? String ?? ""
    let category = args["category"] as? String ?? ""
    let achievements = args["achievements"] as? [String] ?? []
    
    #if canImport(ActivityKit)
    // LiveActivityManager.shared.updateCarbonTracking(
    //   currentCO2: currentCO2,
    //   currentActivity: currentActivity,
    //   category: category,
    //   achievements: achievements
    // )
    result(false) // Temporarily disabled
    #else
    result(false)
    #endif
  }
  
  @available(iOS 16.1, *)
  private func stopLiveActivity(result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    // LiveActivityManager.shared.stopCarbonTracking()
    result(false) // Temporarily disabled
    #else
    result(false)
    #endif
  }
  
  @available(iOS 16.1, *)
  private func checkLiveActivityStatus(result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    // let isActive = LiveActivityManager.shared.isActivityActive()
    result(false) // Temporarily disabled
    #else
    result(false)
    #endif
  }
  
  // Handle app lifecycle for widgets
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    
    // Update widgets when app goes to background
    widgetChannel?.invokeMethod("onAppPaused", arguments: nil)
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    
    // Update widgets when app becomes active
    widgetChannel?.invokeMethod("onAppResumed", arguments: nil)
  }
}
