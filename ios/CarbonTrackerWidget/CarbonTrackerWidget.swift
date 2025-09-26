import WidgetKit
import SwiftUI
import Foundation

// MARK: - Widget Entry
struct CarbonEntry: TimelineEntry {
    let date: Date
    let todayCO2: Double
    let weeklyAverage: Double
    let monthlyGoal: Double
    let topCategory: String
    let isDataAvailable: Bool
    let progressPercentage: Double
    let todayComparison: String
    let trend: String
    let achievements: [String]
}

// MARK: - Widget Data Provider
struct CarbonProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> CarbonEntry {
        CarbonEntry(
            date: Date(),
            todayCO2: 12.5,
            weeklyAverage: 15.2,
            monthlyGoal: 400.0,
            topCategory: "Transport",
            isDataAvailable: true,
            progressPercentage: 0.65,
            todayComparison: "↓ 2.1 kg less than yesterday",
            trend: "improving",
            achievements: ["🌱 Green Week", "🚶 Walker"]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CarbonEntry) -> ()) {
        let entry = getWidgetData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        let entry = getWidgetData()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getWidgetData() -> CarbonEntry {
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
        
        return CarbonEntry(
            date: Date(),
            todayCO2: todayCO2,
            weeklyAverage: weeklyAverage,
            monthlyGoal: monthlyGoal,
            topCategory: topCategory,
            isDataAvailable: isDataAvailable,
            progressPercentage: progressPercentage,
            todayComparison: comparison,
            trend: trend,
            achievements: achievementsData
        )
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: CarbonEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
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
            
            // Progress indicator
            HStack {
                Rectangle()
                    .fill(Color.green)
                    .frame(height: 3)
                    .scaleEffect(x: entry.progressPercentage, anchor: .leading)
                    .clipped()
                Spacer()
            }
            .background(Color.gray.opacity(0.3))
            .cornerRadius(1.5)
        }
        .padding(12)
        .widgetBackground()
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: CarbonEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Main stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    Text("Carbon Tracker")
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
                
                // Progress bar with goal
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
                            .foregroundColor(.blue)
                        Text(entry.topCategory)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                
                if !entry.achievements.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest Badge")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(entry.achievements.first ?? "")
                            .font(.caption)
                            .foregroundColor(.orange)
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
            return .green
        case "worsening":
            return .red
        default:
            return .blue
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

// MARK: - Large Widget View
struct LargeWidgetView: View {
    let entry: CarbonEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
                Text("Carbon Tracker")
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
                    
                    Text(entry.todayComparison)
                        .font(.caption)
                        .foregroundColor(entry.trend == "improving" ? .green : entry.trend == "worsening" ? .red : .secondary)
                }
                
                Spacer()
                
                // Circular progress
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
            
            // Stats row
            HStack {
                StatBox(title: "Weekly Avg", value: "\(entry.weeklyAverage, specifier: "%.1f") kg", color: .blue)
                StatBox(title: "Monthly Goal", value: "\(entry.monthlyGoal, specifier: "%.0f") kg", color: .purple)
                StatBox(title: "Top Category", value: entry.topCategory, color: .orange)
            }
            
            // Achievements
            if !entry.achievements.isEmpty {
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
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
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
            return .green
        case "worsening":
            return .red
        default:
            return .blue
        }
    }
}

// MARK: - Helper Views
struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Widget Background Extension
extension View {
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            return self.background()
        }
    }
}

// MARK: - Main Widget Configuration
struct CarbonTrackerWidget: Widget {
    let kind: String = "CarbonTrackerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarbonProvider()) { entry in
            CarbonTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Carbon Tracker")
        .description("Track your daily carbon footprint right from your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Main Entry View
struct CarbonTrackerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: CarbonProvider.Entry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle
@main
struct CarbonTrackerWidgets: WidgetBundle {
    var body: some Widget {
        CarbonTrackerWidget()
        if #available(iOSApplicationExtension 16.1, *) {
            LiveActivityWidget()
        }
    }
}

// MARK: - Preview
struct CarbonTrackerWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = CarbonEntry(
            date: Date(),
            todayCO2: 12.5,
            weeklyAverage: 15.2,
            monthlyGoal: 400.0,
            topCategory: "Transport",
            isDataAvailable: true,
            progressPercentage: 0.65,
            todayComparison: "↓ 2.1 kg less than yesterday",
            trend: "improving",
            achievements: ["🌱 Green Week", "🚶 Walker"]
        )
        
        Group {
            CarbonTrackerWidgetEntryView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            CarbonTrackerWidgetEntryView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            CarbonTrackerWidgetEntryView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}