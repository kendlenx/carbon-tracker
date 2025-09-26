import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes
struct CarbonTrackingAttributes: ActivityAttributes {
    public typealias ContentState = ContentState
    
    public struct ContentState: Codable, Hashable {
        var currentCO2: Double
        var targetCO2: Double
        var currentActivity: String
        var duration: TimeInterval
        var startTime: Date
        var progress: Double
        var category: String
        var isActive: Bool
        var achievements: [String]
    }
    
    // Fixed attributes for the activity
    let sessionName: String
    let goalType: String
}

// MARK: - Live Activity Widget
@available(iOS 16.1, *)
struct LiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CarbonTrackingAttributes.self) { context in
            // Lock screen/banner UI for Live Activity
            LiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island configuration
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityExpandedBottom(context: context)
                }
            } compactLeading: {
                // Compact leading view
                LiveActivityCompactLeading(context: context)
            } compactTrailing: {
                // Compact trailing view
                LiveActivityCompactTrailing(context: context)
            } minimal: {
                // Minimal view when space is very constrained
                LiveActivityMinimal(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View
@available(iOS 16.1, *)
struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<CarbonTrackingAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    Text("Carbon Tracker")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(context.attributes.goalType)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            // Main content
            HStack(alignment: .center, spacing: 16) {
                // Current CO2 display
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current CO₂")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(context.state.currentCO2, specifier: "%.1f") kg")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("of \(context.state.targetCO2, specifier: "%.1f") kg goal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(.tertiary, lineWidth: 6)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: min(1.0, context.state.progress))
                        .stroke(getProgressColor(context.state.progress), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Activity info
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: getCategoryIcon(context.state.category))
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text(context.state.currentActivity)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    Text(formatDuration(context.state.duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if context.state.isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("Active")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            // Progress bar
            ProgressView(value: min(1.0, context.state.progress))
                .progressViewStyle(LinearProgressViewStyle(tint: getProgressColor(context.state.progress)))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Recent achievement (if any)
            if !context.state.achievements.isEmpty {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))
                    Text("Achievement: \(context.state.achievements.last ?? "")")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .cornerRadius(12)
    }
    
    private func getProgressColor(_ progress: Double) -> Color {
        if progress < 0.5 {
            return .green
        } else if progress < 0.8 {
            return .orange
        } else {
            return .red
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Dynamic Island Views

@available(iOS 16.1, *)
struct LiveActivityExpandedLeading: View {
    let context: ActivityViewContext<CarbonTrackingAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 10))
                Text("CO₂ Tracker")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text("\(context.state.currentCO2, specifier: "%.1f") kg")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

@available(iOS 16.1, *)
struct LiveActivityExpandedTrailing: View {
    let context: ActivityViewContext<CarbonTrackingAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Goal: \(context.state.targetCO2, specifier: "%.1f") kg")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                if context.state.isActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 4, height: 4)
                }
            }
        }
    }
}

@available(iOS 16.1, *)
struct LiveActivityExpandedBottom: View {
    let context: ActivityViewContext<CarbonTrackingAttributes>
    
    var body: some View {
        HStack {
            // Current activity
            HStack(spacing: 6) {
                Image(systemName: getCategoryIcon(context.state.category))
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text(context.state.currentActivity)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text("•")
                    .foregroundColor(.secondary)
                    .font(.caption2)
                
                Text(formatDuration(context.state.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Progress indicator
            ProgressView(value: min(1.0, context.state.progress))
                .progressViewStyle(LinearProgressViewStyle(tint: getProgressColor(context.state.progress)))
                .frame(width: 80)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
        }
    }
    
    private func getProgressColor(_ progress: Double) -> Color {
        if progress < 0.5 {
            return .green
        } else if progress < 0.8 {
            return .orange
        } else {
            return .red
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

@available(iOS 16.1, *)
struct LiveActivityCompactLeading: View {
    let context: ActivityViewContext<CarbonTrackingAttributes>
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .foregroundColor(.green)
                .font(.system(size: 10))
            
            Text("\(context.state.currentCO2, specifier: "%.1f")")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

@available(iOS 16.1, *)
struct LiveActivityCompactTrailing: View {
    let context: ActivityViewContext<CarbonTrackingAttributes>
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(Int(context.state.progress * 100))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            
            if context.state.isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

@available(iOS 16.1, *)
struct LiveActivityMinimal: View {
    let context: ActivityViewContext<CarbonTrackingAttributes>
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "leaf.fill")
                .foregroundColor(.green)
                .font(.system(size: 8))
            
            if context.state.isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - Live Activity Manager (Flutter Bridge)
@available(iOS 16.1, *)
class LiveActivityManager: NSObject {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<CarbonTrackingAttributes>?
    
    override init() {
        super.init()
    }
    
    func startCarbonTracking(
        sessionName: String,
        goalType: String,
        targetCO2: Double,
        currentActivity: String,
        category: String
    ) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return false
        }
        
        let attributes = CarbonTrackingAttributes(
            sessionName: sessionName,
            goalType: goalType
        )
        
        let contentState = CarbonTrackingAttributes.ContentState(
            currentCO2: 0.0,
            targetCO2: targetCO2,
            currentActivity: currentActivity,
            duration: 0,
            startTime: Date(),
            progress: 0.0,
            category: category,
            isActive: true,
            achievements: []
        )
        
        do {
            currentActivity = try Activity<CarbonTrackingAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            print("Live Activity started successfully")
            return true
        } catch {
            print("Failed to start Live Activity: \(error)")
            return false
        }
    }
    
    func updateCarbonTracking(
        currentCO2: Double,
        currentActivity: String,
        category: String,
        achievements: [String] = []
    ) {
        guard let activity = currentActivity else { return }
        
        let duration = Date().timeIntervalSince(activity.contentState.startTime)
        let progress = currentCO2 / activity.contentState.targetCO2
        
        let updatedContentState = CarbonTrackingAttributes.ContentState(
            currentCO2: currentCO2,
            targetCO2: activity.contentState.targetCO2,
            currentActivity: currentActivity,
            duration: duration,
            startTime: activity.contentState.startTime,
            progress: progress,
            category: category,
            isActive: true,
            achievements: achievements
        )
        
        Task {
            await activity.update(using: updatedContentState)
        }
    }
    
    func stopCarbonTracking() {
        guard let activity = currentActivity else { return }
        
        let finalContentState = CarbonTrackingAttributes.ContentState(
            currentCO2: activity.contentState.currentCO2,
            targetCO2: activity.contentState.targetCO2,
            currentActivity: "Session Completed",
            duration: Date().timeIntervalSince(activity.contentState.startTime),
            startTime: activity.contentState.startTime,
            progress: activity.contentState.progress,
            category: activity.contentState.category,
            isActive: false,
            achievements: activity.contentState.achievements
        )
        
        Task {
            await activity.end(using: finalContentState, dismissalPolicy: .after(Date().addingTimeInterval(5)))
        }
        
        currentActivity = nil
    }
    
    func isActivityActive() -> Bool {
        return currentActivity != nil && currentActivity?.activityState == .active
    }
}

// MARK: - Preview
@available(iOS 16.1, *)
struct LiveActivityWidget_Previews: PreviewProvider {
    static var previews: some View {
        let attributes = CarbonTrackingAttributes(
            sessionName: "Daily Tracking",
            goalType: "Daily Goal"
        )
        
        let contentState = CarbonTrackingAttributes.ContentState(
            currentCO2: 8.5,
            targetCO2: 15.0,
            currentActivity: "Car Trip",
            duration: 2400, // 40 minutes
            startTime: Date().addingTimeInterval(-2400),
            progress: 0.57,
            category: "Transport",
            isActive: true,
            achievements: ["🌱 Green Day"]
        )
        
        return LiveActivityLockScreenView(
            context: ActivityViewContext(
                attributes: attributes,
                state: contentState
            )
        )
        .previewDisplayName("Live Activity Lock Screen")
    }
}