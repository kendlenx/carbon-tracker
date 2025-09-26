import WidgetKit
import SwiftUI
import Foundation

// MARK: - Control Center Widget
@available(iOS 18.0, *)
struct CarbonTrackerControlWidget: ControlWidget {
    let kind: String = "CarbonTrackerControlWidget"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetToggle(
                "Quick Add Activity",
                isOn: false,
                action: AddActivityIntent()
            ) { isOn in
                Label {
                    Text("Carbon Tracker")
                } icon: {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .displayName("Carbon Tracker")
        .description("Quick carbon activity tracking")
    }
}

// MARK: - Quick Activity Intent
@available(iOS 16.0, *)
struct AddActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Carbon Activity"
    static var description = IntentDescription("Quickly add a carbon footprint activity")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        // This will be handled by the app when it opens
        return .result()
    }
}

// MARK: - Quick Actions for 3D Touch / Haptic Touch
struct QuickActionsManager {
    static func setupQuickActions() {
        let quickActions = [
            // Car Trip
            UIApplicationShortcutItem(
                type: "com.carbontracker.car-trip",
                localizedTitle: "Car Trip",
                localizedSubtitle: "Add car journey",
                icon: UIApplicationShortcutIcon(systemImageName: "car.fill"),
                userInfo: [
                    "type": "car" as NSSecureCoding,
                    "category": "transport" as NSSecureCoding
                ]
            ),
            
            // Walking
            UIApplicationShortcutItem(
                type: "com.carbontracker.walking",
                localizedTitle: "Walking",
                localizedSubtitle: "Add walking activity",
                icon: UIApplicationShortcutIcon(systemImageName: "figure.walk"),
                userInfo: [
                    "type": "walking" as NSSecureCoding,
                    "category": "transport" as NSSecureCoding
                ]
            ),
            
            // Public Transport
            UIApplicationShortcutItem(
                type: "com.carbontracker.public-transport",
                localizedTitle: "Public Transport",
                localizedSubtitle: "Add bus/metro trip",
                icon: UIApplicationShortcutIcon(systemImageName: "bus.fill"),
                userInfo: [
                    "type": "bus" as NSSecureCoding,
                    "category": "transport" as NSSecureCoding
                ]
            ),
            
            // View Stats
            UIApplicationShortcutItem(
                type: "com.carbontracker.view-stats",
                localizedTitle: "View Today's Stats",
                localizedSubtitle: "See carbon footprint",
                icon: UIApplicationShortcutIcon(systemImageName: "chart.bar.fill"),
                userInfo: [
                    "action": "view-stats" as NSSecureCoding
                ]
            )
        ]
        
        UIApplication.shared.shortcutItems = quickActions
    }
    
    static func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        switch shortcutItem.type {
        case "com.carbontracker.car-trip":
            openTransportScreen(type: "car")
            return true
            
        case "com.carbontracker.walking":
            openTransportScreen(type: "walking")
            return true
            
        case "com.carbontracker.public-transport":
            openTransportScreen(type: "bus")
            return true
            
        case "com.carbontracker.view-stats":
            openStatsScreen()
            return true
            
        default:
            return false
        }
    }
    
    private static func openTransportScreen(type: String) {
        // This will be handled by Flutter app
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenTransportScreen"),
            object: nil,
            userInfo: ["type": type]
        )
    }
    
    private static func openStatsScreen() {
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenStatsScreen"),
            object: nil
        )
    }
}

// MARK: - Today Extension Widget (iOS 13+)
@available(iOS 13.0, *)
struct TodayExtensionWidget: Widget {
    let kind: String = "TodayExtensionWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayExtensionView(entry: entry)
        }
        .configurationDisplayName("Today's Carbon")
        .description("Quick view of today's carbon footprint")
        .supportedFamilies([.systemSmall])
    }
}

@available(iOS 13.0, *)
struct TodayExtensionEntry: TimelineEntry {
    let date: Date
    let todayCO2: Double
    let comparisonText: String
    let quickActions: [QuickAction]
}

@available(iOS 13.0, *)
struct QuickAction {
    let title: String
    let icon: String
    let type: String
    let color: Color
}

@available(iOS 13.0, *)
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayExtensionEntry {
        TodayExtensionEntry(
            date: Date(),
            todayCO2: 12.5,
            comparisonText: "↓ 2.1 kg less than yesterday",
            quickActions: getQuickActions()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodayExtensionEntry) -> ()) {
        let entry = getTodayData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        
        let entry = getTodayData()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getTodayData() -> TodayExtensionEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.carbon-tracker.shared")
        
        let todayCO2 = sharedDefaults?.double(forKey: "todayCO2") ?? 0.0
        let yesterdayCO2 = sharedDefaults?.double(forKey: "yesterdayCO2") ?? 0.0
        
        let difference = todayCO2 - yesterdayCO2
        let comparisonText = difference >= 0 
            ? "↑ \(String(format: "%.1f", abs(difference))) kg more than yesterday"
            : "↓ \(String(format: "%.1f", abs(difference))) kg less than yesterday"
        
        return TodayExtensionEntry(
            date: Date(),
            todayCO2: todayCO2,
            comparisonText: comparisonText,
            quickActions: getQuickActions()
        )
    }
    
    private func getQuickActions() -> [QuickAction] {
        return [
            QuickAction(title: "Car", icon: "car.fill", type: "car", color: .blue),
            QuickAction(title: "Walk", icon: "figure.walk", type: "walking", color: .green),
            QuickAction(title: "Bus", icon: "bus.fill", type: "bus", color: .orange),
        ]
    }
}

@available(iOS 13.0, *)
struct TodayExtensionView: View {
    let entry: TodayExtensionEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                Text("Today's CO₂")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Main stat
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.todayCO2, specifier: "%.1f") kg")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(entry.comparisonText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            
            // Quick actions
            HStack(spacing: 8) {
                ForEach(entry.quickActions, id: \.type) { action in
                    Button(intent: QuickAddIntent(activityType: action.type)) {
                        VStack(spacing: 2) {
                            Image(systemName: action.icon)
                                .font(.system(size: 12))
                                .foregroundColor(action.color)
                            
                            Text(action.title)
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(action.color.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .widgetBackground()
    }
}

// MARK: - Quick Add Intent for Today Extension
@available(iOS 16.0, *)
struct QuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Activity"
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Activity Type")
    var activityType: String
    
    init(activityType: String = "car") {
        self.activityType = activityType
    }
    
    func perform() async throws -> some IntentResult {
        // Save quick add request to shared storage
        let sharedDefaults = UserDefaults(suiteName: "group.carbon-tracker.shared")
        sharedDefaults?.set(activityType, forKey: "quick_add_type")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "quick_add_timestamp")
        sharedDefaults?.synchronize()
        
        return .result()
    }
}

// MARK: - Interactive Widget (iOS 17+)
@available(iOS 17.0, *)
struct InteractiveCarbonWidget: Widget {
    let kind: String = "InteractiveCarbonWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InteractiveProvider()) { entry in
            InteractiveWidgetView(entry: entry)
        }
        .configurationDisplayName("Interactive Carbon Tracker")
        .description("Add activities directly from widget")
        .supportedFamilies([.systemMedium])
    }
}

@available(iOS 17.0, *)
struct InteractiveEntry: TimelineEntry {
    let date: Date
    let todayCO2: Double
    let quickActions: [QuickAction]
}

@available(iOS 17.0, *)
struct InteractiveProvider: TimelineProvider {
    func placeholder(in context: Context) -> InteractiveEntry {
        InteractiveEntry(
            date: Date(),
            todayCO2: 12.5,
            quickActions: [
                QuickAction(title: "Car Trip", icon: "car.fill", type: "car", color: .blue),
                QuickAction(title: "Walking", icon: "figure.walk", type: "walking", color: .green),
                QuickAction(title: "Public Transport", icon: "bus.fill", type: "bus", color: .orange),
            ]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (InteractiveEntry) -> ()) {
        completion(placeholder(in: context))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

@available(iOS 17.0, *)
struct InteractiveWidgetView: View {
    let entry: InteractiveEntry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with current stats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.todayCO2, specifier: "%.1f") kg CO₂")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Today's Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            }
            
            // Interactive buttons
            HStack(spacing: 8) {
                ForEach(entry.quickActions, id: \.type) { action in
                    Button(intent: QuickAddIntent(activityType: action.type)) {
                        VStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            
                            Text(action.title)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(action.color)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .widgetBackground()
    }
}

// MARK: - Widget Bundle Update
extension CarbonTrackerWidgets {
    var body: some Widget {
        CarbonTrackerWidget()
        
        if #available(iOSApplicationExtension 16.1, *) {
            LiveActivityWidget()
        }
        
        if #available(iOSApplicationExtension 14.0, *) {
            ConfigurableCarbonTrackerWidget()
        }
        
        if #available(iOSApplicationExtension 13.0, *) {
            TodayExtensionWidget()
        }
        
        if #available(iOSApplicationExtension 17.0, *) {
            InteractiveCarbonWidget()
        }
        
        if #available(iOSApplicationExtension 18.0, *) {
            CarbonTrackerControlWidget()
        }
    }
}