import Foundation
import Intents
import SwiftUI
import WidgetKit

// MARK: - Widget Configuration Intent
@available(iOS 14.0, *)
class ConfigurationIntent: INIntent {
    @NSManaged public var widgetSize: WidgetSize
    @NSManaged public var showAchievements: NSNumber?
    @NSManaged public var showComparison: NSNumber?
    @NSManaged public var showProgress: NSNumber?
    @NSManaged public var colorTheme: ColorTheme
    @NSManaged public var updateFrequency: UpdateFrequency
}

// MARK: - Widget Size Enum
@available(iOS 14.0, *)
@objc public enum WidgetSize: Int, CaseIterable {
    case small = 1
    case medium = 2
    case large = 3
    
    public var displayString: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    public var displayStringTurkish: String {
        switch self {
        case .small: return "Küçük"
        case .medium: return "Orta"
        case .large: return "Büyük"
        }
    }
    
    public var widgetFamily: WidgetFamily {
        switch self {
        case .small: return .systemSmall
        case .medium: return .systemMedium
        case .large: return .systemLarge
        }
    }
}

// MARK: - Color Theme Enum
@available(iOS 14.0, *)
@objc public enum ColorTheme: Int, CaseIterable {
    case green = 1
    case blue = 2
    case purple = 3
    case orange = 4
    case system = 5
    
    public var displayString: String {
        switch self {
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .orange: return "Orange"
        case .system: return "System"
        }
    }
    
    public var displayStringTurkish: String {
        switch self {
        case .green: return "Yeşil"
        case .blue: return "Mavi"
        case .purple: return "Mor"
        case .orange: return "Turuncu"
        case .system: return "Sistem"
        }
    }
    
    public var primaryColor: Color {
        switch self {
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .system: return .primary
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .green: return .mint
        case .blue: return .cyan
        case .purple: return .indigo
        case .orange: return .yellow
        case .system: return .accentColor
        }
    }
}

// MARK: - Update Frequency Enum
@available(iOS 14.0, *)
@objc public enum UpdateFrequency: Int, CaseIterable {
    case minutes5 = 1
    case minutes15 = 2
    case minutes30 = 3
    case hour1 = 4
    case hours2 = 5
    
    public var displayString: String {
        switch self {
        case .minutes5: return "5 Minutes"
        case .minutes15: return "15 Minutes"
        case .minutes30: return "30 Minutes"
        case .hour1: return "1 Hour"
        case .hours2: return "2 Hours"
        }
    }
    
    public var displayStringTurkish: String {
        switch self {
        case .minutes5: return "5 Dakika"
        case .minutes15: return "15 Dakika"
        case .minutes30: return "30 Dakika"
        case .hour1: return "1 Saat"
        case .hours2: return "2 Saat"
        }
    }
    
    public var timeInterval: TimeInterval {
        switch self {
        case .minutes5: return 5 * 60
        case .minutes15: return 15 * 60
        case .minutes30: return 30 * 60
        case .hour1: return 60 * 60
        case .hours2: return 2 * 60 * 60
        }
    }
}

// MARK: - Configurable Carbon Widget
@available(iOS 14.0, *)
struct ConfigurableCarbonTrackerWidget: Widget {
    let kind: String = "ConfigurableCarbonTrackerWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind, 
            intent: ConfigurationIntent.self,
            provider: ConfigurableCarbonProvider()
        ) { entry in
            ConfigurableCarbonTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Carbon Step")
        .description("Customizable carbon footprint tracking widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Configurable Carbon Entry
@available(iOS 14.0, *)
struct ConfigurableCarbonEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let todayCO2: Double
    let weeklyAverage: Double
    let monthlyGoal: Double
    let topCategory: String
    let isDataAvailable: Bool
    let progressPercentage: Double
    let todayComparison: String
    let trend: String
    let achievements: [String]
    let colorTheme: ColorTheme
    let showAchievements: Bool
    let showComparison: Bool
    let showProgress: Bool
}

// MARK: - Configurable Carbon Provider
@available(iOS 14.0, *)
struct ConfigurableCarbonProvider: IntentTimelineProvider {
    
    func placeholder(in context: Context) -> ConfigurableCarbonEntry {
        ConfigurableCarbonEntry(
            date: Date(),
            configuration: ConfigurationIntent(),
            todayCO2: 12.5,
            weeklyAverage: 15.2,
            monthlyGoal: 400.0,
            topCategory: "Transport",
            isDataAvailable: true,
            progressPercentage: 0.65,
            todayComparison: "↓ 2.1 kg less than yesterday",
            trend: "improving",
            achievements: ["🌱 Green Week", "🚶 Walker"],
            colorTheme: .green,
            showAchievements: true,
            showComparison: true,
            showProgress: true
        )
    }
    
    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (ConfigurableCarbonEntry) -> ()) {
        let entry = getConfigurableWidgetData(configuration: configuration)
        completion(entry)
    }
    
    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let updateFrequency = configuration.updateFrequency.timeInterval
        let nextUpdate = Calendar.current.date(byAdding: .second, value: Int(updateFrequency), to: currentDate)!
        
        let entry = getConfigurableWidgetData(configuration: configuration)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getConfigurableWidgetData(configuration: ConfigurationIntent) -> ConfigurableCarbonEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.carbon-tracker.shared")
        
        let todayCO2 = sharedDefaults?.double(forKey: "todayCO2") ?? 0.0
        let weeklyAverage = sharedDefaults?.double(forKey: "weeklyAverage") ?? 0.0
        let monthlyGoal = sharedDefaults?.double(forKey: "monthlyGoal") ?? 400.0
        let topCategory = sharedDefaults?.string(forKey: "topCategory") ?? "Transport"
        let lastUpdate = sharedDefaults?.object(forKey: "lastUpdate") as? Date ?? Date.distantPast
        let isDataAvailable = Date().timeIntervalSince(lastUpdate) < 3600 // 1 hour
        
        // Calculate progress percentage
        let dailyGoal = monthlyGoal / 30.0
        let progressPercentage = min(1.0, todayCO2 / dailyGoal)
        
        // Get yesterday's CO2 for comparison
        let yesterdayCO2 = sharedDefaults?.double(forKey: "yesterdayCO2") ?? 0.0
        let difference = todayCO2 - yesterdayCO2
        let comparison = difference >= 0 ? "↑ \(String(format: "%.1f", abs(difference))) kg more than yesterday" : "↓ \(String(format: "%.1f", abs(difference))) kg less than yesterday"
        
        // Determine trend
        let trend: String
        if difference < -1.0 {
            trend = "improving"
        } else if difference > 1.0 {
            trend = "worsening"
        } else {
            trend = "stable"
        }
        
        // Get achievements
        let achievementsData = sharedDefaults?.array(forKey: "recentAchievements") as? [String] ?? []
        
        return ConfigurableCarbonEntry(
            date: Date(),
            configuration: configuration,
            todayCO2: todayCO2,
            weeklyAverage: weeklyAverage,
            monthlyGoal: monthlyGoal,
            topCategory: topCategory,
            isDataAvailable: isDataAvailable,
            progressPercentage: progressPercentage,
            todayComparison: comparison,
            trend: trend,
            achievements: achievementsData,
            colorTheme: configuration.colorTheme,
            showAchievements: configuration.showAchievements?.boolValue ?? true,
            showComparison: configuration.showComparison?.boolValue ?? true,
            showProgress: configuration.showProgress?.boolValue ?? true
        )
    }
}

// MARK: - Configurable Entry View
@available(iOS 14.0, *)
struct ConfigurableCarbonTrackerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ConfigurableCarbonProvider.Entry
    
    var body: some View {
        switch family {
        case .systemSmall:
            ConfigurableSmallWidgetView(entry: entry)
        case .systemMedium:
            ConfigurableMediumWidgetView(entry: entry)
        case .systemLarge:
            ConfigurableLargeWidgetView(entry: entry)
        default:
            ConfigurableSmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Configurable Small Widget View
@available(iOS 14.0, *)
struct ConfigurableSmallWidgetView: View {
    let entry: ConfigurableCarbonEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(entry.colorTheme.primaryColor)
                    .font(.system(size: 12))
                Spacer()
                Text("CO₂")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.todayCO2, specifier: "%.1f") kg")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Progress indicator (if enabled)
            if entry.showProgress {
                HStack {
                    Rectangle()
                        .fill(entry.colorTheme.primaryColor)
                        .frame(height: 3)
                        .scaleEffect(x: entry.progressPercentage, anchor: .leading)
                        .clipped()
                    Spacer()
                }
                .background(Color.gray.opacity(0.3))
                .cornerRadius(1.5)
            }
        }
        .padding(12)
        .widgetBackground()
    }
}

// MARK: - Configurable Medium Widget View
@available(iOS 14.0, *)
struct ConfigurableMediumWidgetView: View {
    let entry: ConfigurableCarbonEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Main stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(entry.colorTheme.primaryColor)
                        .font(.system(size: 14))
                    Text("Carbon Step")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.todayCO2, specifier: "%.1f") kg CO₂")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Today's Footprint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Progress bar with goal (if enabled)
                if entry.showProgress {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Rectangle()
                                .fill(getTrendColor())
                                .frame(height: 4)
                                .scaleEffect(x: entry.progressPercentage, anchor: .leading)
                                .clipped()
                            Spacer()
                        }
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(2)
                        
                        Text("Goal: \(entry.monthlyGoal/30, specifier: "%.1f") kg/day")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Right side - Additional info
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Avg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(entry.weeklyAverage, specifier: "%.1f") kg")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top Category")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: getCategoryIcon(entry.topCategory))
                            .font(.system(size: 10))
                            .foregroundColor(entry.colorTheme.accentColor)
                        Text(entry.topCategory)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                
                // Achievements (if enabled)
                if entry.showAchievements && !entry.achievements.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest Badge")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(entry.achievements.first ?? "")
                            .font(.caption)
                            .foregroundColor(entry.colorTheme.primaryColor)
                    }
                }
            }
        }
        .padding(16)
        .widgetBackground()
    }
    
    private func getTrendColor() -> Color {
        switch entry.trend {
        case "improving":
            return entry.colorTheme.primaryColor
        case "worsening":
            return .red
        default:
            return entry.colorTheme.accentColor
        }
    }
    
    private func getCategoryIcon(_ category: String) -> String {
        switch category.lowercased() {
        case "transport":
            return "car.fill"
        case "energy":
            return "bolt.fill"
        case "food":
            return "fork.knife"
        case "shopping":
            return "bag.fill"
        default:
            return "leaf.fill"
        }
    }
}

// MARK: - Configurable Large Widget View
@available(iOS 14.0, *)
struct ConfigurableLargeWidgetView: View {
    let entry: ConfigurableCarbonEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(entry.colorTheme.primaryColor)
                    .font(.system(size: 16))
                Text("Carbon Step")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Main CO2 display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.todayCO2, specifier: "%.1f") kg CO₂")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Today's Carbon Footprint")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Comparison (if enabled)
                    if entry.showComparison {
                        Text(entry.todayComparison)
                            .font(.caption)
                            .foregroundColor(entry.trend == "improving" ? entry.colorTheme.primaryColor : entry.trend == "worsening" ? .red : .secondary)
                    }
                }
                
                Spacer()
                
                // Circular progress (if enabled)
                if entry.showProgress {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: entry.progressPercentage)
                            .stroke(getTrendColor(), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(entry.progressPercentage * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Stats row
            HStack {
                StatBox(title: "Weekly Avg", value: "\(entry.weeklyAverage, specifier: "%.1f") kg", color: entry.colorTheme.accentColor)
                StatBox(title: "Monthly Goal", value: "\(entry.monthlyGoal, specifier: "%.0f") kg", color: entry.colorTheme.primaryColor)
                StatBox(title: "Top Category", value: entry.topCategory, color: .orange)
            }
            
            // Achievements (if enabled)
            if entry.showAchievements && !entry.achievements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Achievements")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(entry.achievements.prefix(3), id: \.self) { achievement in
                            Text(achievement)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(entry.colorTheme.primaryColor.opacity(0.2))
                                .foregroundColor(entry.colorTheme.primaryColor)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .widgetBackground()
    }
    
    private func getTrendColor() -> Color {
        switch entry.trend {
        case "improving":
            return entry.colorTheme.primaryColor
        case "worsening":
            return .red
        default:
            return entry.colorTheme.accentColor
        }
    }
}

// MARK: - Preview
@available(iOS 14.0, *)
struct ConfigurableCarbonTrackerWidget_Previews: PreviewProvider {
    static var previews: some View {
        let configuration = ConfigurationIntent()
        configuration.colorTheme = .green
        configuration.showAchievements = NSNumber(value: true)
        configuration.showComparison = NSNumber(value: true)
        configuration.showProgress = NSNumber(value: true)
        
        let sampleEntry = ConfigurableCarbonEntry(
            date: Date(),
            configuration: configuration,
            todayCO2: 12.5,
            weeklyAverage: 15.2,
            monthlyGoal: 400.0,
            topCategory: "Transport",
            isDataAvailable: true,
            progressPercentage: 0.65,
            todayComparison: "↓ 2.1 kg less than yesterday",
            trend: "improving",
            achievements: ["🌱 Green Week", "🚶 Walker"],
            colorTheme: .green,
            showAchievements: true,
            showComparison: true,
            showProgress: true
        )
        
        Group {
            ConfigurableCarbonTrackerWidgetEntryView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            ConfigurableCarbonTrackerWidgetEntryView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            ConfigurableCarbonTrackerWidgetEntryView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}