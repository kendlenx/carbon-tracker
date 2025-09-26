import Foundation
import Intents
import IntentsUI

// MARK: - Carbon Activity Intent
@available(iOS 14.0, *)
class AddCarbonActivityIntent: INIntent {
    
    @NSManaged public var activityType: ActivityType
    @NSManaged public var distance: NSNumber?
    @NSManaged public var duration: NSNumber?
    @NSManaged public var notes: String?
    @NSManaged public var category: ActivityCategory
    
}

// MARK: - Activity Type Enum
@available(iOS 14.0, *)
@objc public enum ActivityType: Int, CaseIterable {
    case carTrip = 1
    case busRide = 2
    case trainRide = 3
    case walking = 4
    case cycling = 5
    case flight = 6
    case electricityUsage = 7
    case gasUsage = 8
    case meal = 9
    case shopping = 10
    
    public var displayString: String {
        switch self {
        case .carTrip: return "Car Trip"
        case .busRide: return "Bus Ride"
        case .trainRide: return "Train Ride"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .flight: return "Flight"
        case .electricityUsage: return "Electricity Usage"
        case .gasUsage: return "Gas Usage"
        case .meal: return "Meal"
        case .shopping: return "Shopping"
        }
    }
    
    public var displayStringTurkish: String {
        switch self {
        case .carTrip: return "Araba Yolculuğu"
        case .busRide: return "Otobüs Yolculuğu"
        case .trainRide: return "Tren Yolculuğu"
        case .walking: return "Yürüyüş"
        case .cycling: return "Bisiklet"
        case .flight: return "Uçak"
        case .electricityUsage: return "Elektrik Kullanımı"
        case .gasUsage: return "Gaz Kullanımı"
        case .meal: return "Yemek"
        case .shopping: return "Alışveriş"
        }
    }
}

// MARK: - Activity Category Enum
@available(iOS 14.0, *)
@objc public enum ActivityCategory: Int, CaseIterable {
    case transport = 1
    case energy = 2
    case food = 3
    case shopping = 4
    
    public var displayString: String {
        switch self {
        case .transport: return "Transport"
        case .energy: return "Energy"
        case .food: return "Food"
        case .shopping: return "Shopping"
        }
    }
    
    public var displayStringTurkish: String {
        switch self {
        case .transport: return "Ulaşım"
        case .energy: return "Enerji"
        case .food: return "Yemek"
        case .shopping: return "Alışveriş"
        }
    }
}

// MARK: - Intent Handler
@available(iOS 14.0, *)
class CarbonActivityIntentHandler: NSObject, AddCarbonActivityIntentHandling {
    
    func handle(intent: AddCarbonActivityIntent, completion: @escaping (AddCarbonActivityIntentResponse) -> Void) {
        
        // Calculate CO2 based on activity type
        let co2Amount = calculateCO2(for: intent)
        
        // Save activity to shared storage
        let success = saveActivity(intent: intent, co2Amount: co2Amount)
        
        if success {
            let response = AddCarbonActivityIntentResponse(code: .success, userActivity: nil)
            response.activityType = intent.activityType
            response.co2Amount = NSNumber(value: co2Amount)
            completion(response)
        } else {
            let response = AddCarbonActivityIntentResponse(code: .failure, userActivity: nil)
            completion(response)
        }
    }
    
    func resolveActivityType(for intent: AddCarbonActivityIntent, with completion: @escaping (ActivityTypeResolutionResult) -> Void) {
        completion(ActivityTypeResolutionResult.success(with: intent.activityType))
    }
    
    func resolveCategory(for intent: AddCarbonActivityIntent, with completion: @escaping (ActivityCategoryResolutionResult) -> Void) {
        completion(ActivityCategoryResolutionResult.success(with: intent.category))
    }
    
    private func calculateCO2(for intent: AddCarbonActivityIntent) -> Double {
        let distance = intent.distance?.doubleValue ?? 1.0
        let duration = intent.duration?.doubleValue ?? 30.0 // minutes
        
        switch intent.activityType {
        case .carTrip:
            return distance * 0.21 // kg CO₂ per km for petrol car
        case .busRide:
            return distance * 0.089 // kg CO₂ per km for bus
        case .trainRide:
            return distance * 0.041 // kg CO₂ per km for metro
        case .walking, .cycling:
            return 0.0 // Zero emission
        case .flight:
            return distance * 0.255 // kg CO₂ per km for flight
        case .electricityUsage:
            let kWh = duration / 60.0 * 0.5 // Estimate 0.5 kWh per hour
            return kWh * 0.49 // kg CO₂ per kWh
        case .gasUsage:
            let kWh = duration / 60.0 * 2.0 // Estimate 2.0 kWh per hour for gas
            return kWh * 0.202 // kg CO₂ per kWh for gas
        case .meal:
            return 2.5 // Average meal CO₂ footprint
        case .shopping:
            return 5.0 // Average shopping item CO₂ footprint
        }
    }
    
    private func saveActivity(intent: AddCarbonActivityIntent, co2Amount: Double) -> Bool {
        // Save to shared UserDefaults for the app to pick up
        guard let sharedDefaults = UserDefaults(suiteName: "group.carbon-tracker.shared") else {
            return false
        }
        
        let activityData: [String: Any] = [
            "id": UUID().uuidString,
            "type": intent.activityType.displayString,
            "category": intent.category.displayString,
            "co2Amount": co2Amount,
            "distance": intent.distance?.doubleValue ?? 0.0,
            "duration": intent.duration?.doubleValue ?? 0.0,
            "notes": intent.notes ?? "",
            "timestamp": Date().timeIntervalSince1970,
            "source": "siri_shortcut"
        ]
        
        // Get existing pending activities
        var pendingActivities = sharedDefaults.array(forKey: "pending_activities") as? [[String: Any]] ?? []
        pendingActivities.append(activityData)
        
        // Save back to shared defaults
        sharedDefaults.set(pendingActivities, forKey: "pending_activities")
        sharedDefaults.synchronize()
        
        return true
    }
}

// MARK: - Daily Stats Intent
@available(iOS 14.0, *)
class GetDailyStatsIntent: INIntent {
    // This intent gets the daily carbon stats
}

@available(iOS 14.0, *)
class DailyStatsIntentHandler: NSObject, GetDailyStatsIntentHandling {
    
    func handle(intent: GetDailyStatsIntent, completion: @escaping (GetDailyStatsIntentResponse) -> Void) {
        
        // Get stats from shared storage
        guard let sharedDefaults = UserDefaults(suiteName: "group.carbon-tracker.shared") else {
            let response = GetDailyStatsIntentResponse(code: .failure, userActivity: nil)
            completion(response)
            return
        }
        
        let todayCO2 = sharedDefaults.double(forKey: "todayCO2")
        let weeklyAverage = sharedDefaults.double(forKey: "weeklyAverage")
        let monthlyGoal = sharedDefaults.double(forKey: "monthlyGoal")
        let topCategory = sharedDefaults.string(forKey: "topCategory") ?? "Transport"
        
        let response = GetDailyStatsIntentResponse(code: .success, userActivity: nil)
        response.todayCO2 = NSNumber(value: todayCO2)
        response.weeklyAverage = NSNumber(value: weeklyAverage)
        response.monthlyGoal = NSNumber(value: monthlyGoal)
        response.topCategory = topCategory
        
        completion(response)
    }
}

// MARK: - Shortcut Donations Manager
@available(iOS 14.0, *)
class ShortcutDonationManager {
    static let shared = ShortcutDonationManager()
    
    private init() {}
    
    func donateAddActivityShortcut(activityType: ActivityType, category: ActivityCategory) {
        let intent = AddCarbonActivityIntent()
        intent.activityType = activityType
        intent.category = category
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate shortcut: \(error)")
            } else {
                print("Successfully donated \(activityType.displayString) shortcut")
            }
        }
    }
    
    func donateGetStatsShortcut() {
        let intent = GetDailyStatsIntent()
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate stats shortcut: \(error)")
            } else {
                print("Successfully donated get stats shortcut")
            }
        }
    }
    
    func donateCommonShortcuts() {
        // Donate common activity shortcuts
        donateAddActivityShortcut(activityType: .carTrip, category: .transport)
        donateAddActivityShortcut(activityType: .walking, category: .transport)
        donateAddActivityShortcut(activityType: .cycling, category: .transport)
        donateAddActivityShortcut(activityType: .busRide, category: .transport)
        
        // Donate stats shortcut
        donateGetStatsShortcut()
    }
}

// MARK: - Siri Shortcuts Helper
@available(iOS 14.0, *)
class SiriShortcutsHelper {
    
    static func setupVoiceShortcuts() {
        // Request Siri authorization
        INPreferences.requestSiriAuthorization { status in
            switch status {
            case .authorized:
                print("Siri authorization granted")
                // Donate shortcuts after authorization
                ShortcutDonationManager.shared.donateCommonShortcuts()
            case .denied:
                print("Siri authorization denied")
            case .restricted:
                print("Siri authorization restricted")
            case .notDetermined:
                print("Siri authorization not determined")
            @unknown default:
                print("Unknown Siri authorization status")
            }
        }
    }
    
    static func addToSiri(intent: INIntent, completion: @escaping (Bool) -> Void) {
        let shortcut = INShortcut(intent: intent)
        
        let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        viewController.modalPresentationStyle = .formSheet
        
        // This would typically be called from a view controller
        // completion(true)
    }
    
    static func getAvailableShortcuts() -> [INShortcut] {
        var shortcuts: [INShortcut] = []
        
        // Add activity shortcuts
        for activityType in ActivityType.allCases {
            let intent = AddCarbonActivityIntent()
            intent.activityType = activityType
            intent.category = getCategoryForActivityType(activityType)
            
            if let shortcut = INShortcut(intent: intent) {
                shortcuts.append(shortcut)
            }
        }
        
        // Add stats shortcut
        let statsIntent = GetDailyStatsIntent()
        if let statsShortcut = INShortcut(intent: statsIntent) {
            shortcuts.append(statsShortcut)
        }
        
        return shortcuts
    }
    
    private static func getCategoryForActivityType(_ activityType: ActivityType) -> ActivityCategory {
        switch activityType {
        case .carTrip, .busRide, .trainRide, .walking, .cycling, .flight:
            return .transport
        case .electricityUsage, .gasUsage:
            return .energy
        case .meal:
            return .food
        case .shopping:
            return .shopping
        }
    }
}

// MARK: - Intent Response Extensions
@available(iOS 14.0, *)
extension AddCarbonActivityIntentResponse {
    var activityType: ActivityType {
        get { return ActivityType(rawValue: self.activityTypeValue) ?? .carTrip }
        set { self.activityTypeValue = newValue.rawValue }
    }
    
    var co2Amount: NSNumber? {
        get { return self.co2AmountValue }
        set { self.co2AmountValue = newValue }
    }
    
    @NSManaged private var activityTypeValue: Int
    @NSManaged private var co2AmountValue: NSNumber?
}

@available(iOS 14.0, *)
extension GetDailyStatsIntentResponse {
    var todayCO2: NSNumber? {
        get { return self.todayCO2Value }
        set { self.todayCO2Value = newValue }
    }
    
    var weeklyAverage: NSNumber? {
        get { return self.weeklyAverageValue }
        set { self.weeklyAverageValue = newValue }
    }
    
    var monthlyGoal: NSNumber? {
        get { return self.monthlyGoalValue }
        set { self.monthlyGoalValue = newValue }
    }
    
    var topCategory: String? {
        get { return self.topCategoryValue }
        set { self.topCategoryValue = newValue }
    }
    
    @NSManaged private var todayCO2Value: NSNumber?
    @NSManaged private var weeklyAverageValue: NSNumber?
    @NSManaged private var monthlyGoalValue: NSNumber?
    @NSManaged private var topCategoryValue: String?
}