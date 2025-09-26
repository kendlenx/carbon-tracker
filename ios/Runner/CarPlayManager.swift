import UIKit
import CarPlay
import Intents
import MapKit

@available(iOS 12.0, *)
class CarPlayManager: NSObject {
    static let shared = CarPlayManager()
    
    private var interfaceController: CPInterfaceController?
    private var mapTemplate: CPMapTemplate?
    private var listTemplate: CPListTemplate?
    private var window: CPWindow?
    
    // Flutter method channel
    private var methodChannel: FlutterMethodChannel?
    
    // Trip tracking
    private var isTripActive = false
    private var tripStartTime: Date?
    private var tripDistance: Double = 0.0
    
    override init() {
        super.init()
        setupCarPlayScene()
    }
    
    func setupCarPlayScene() {
        // This will be called when CarPlay connects
    }
    
    func setMethodChannel(_ channel: FlutterMethodChannel) {
        self.methodChannel = channel
    }
    
    // MARK: - CarPlay Scene Setup
    
    func setupCarPlayInterface(with interfaceController: CPInterfaceController, window: CPWindow) {
        self.interfaceController = interfaceController
        self.window = window
        
        setupMainDashboard()
    }
    
    private func setupMainDashboard() {
        // Create map template
        mapTemplate = CPMapTemplate()
        mapTemplate?.mapDelegate = self
        
        // Create dashboard actions
        let startTripButton = createBarButton(
            title: "Start Trip",
            image: UIImage(systemName: "play.circle.fill"),
            action: #selector(startTrip)
        )
        
        let endTripButton = createBarButton(
            title: "End Trip", 
            image: UIImage(systemName: "stop.circle.fill"),
            action: #selector(endTrip)
        )
        
        let statusButton = createBarButton(
            title: "Status",
            image: UIImage(systemName: "chart.bar.fill"),
            action: #selector(showStatus)
        )
        
        // Set navigation bar buttons based on trip state
        updateNavigationButtons()
        
        // Set the root template
        interfaceController?.setRootTemplate(mapTemplate!, animated: true, completion: nil)
        
        // Setup Siri shortcuts
        setupSiriShortcuts()
    }
    
    private func createBarButton(title: String, image: UIImage?, action: Selector) -> CPBarButton {
        let button = CPBarButton(type: .text) { [weak self] _ in
            self?.perform(action)
        }
        button.title = title
        button.image = image
        return button
    }
    
    private func updateNavigationButtons() {
        var buttons: [CPBarButton] = []
        
        if isTripActive {
            let endButton = createBarButton(
                title: "End Trip",
                image: UIImage(systemName: "stop.circle.fill"),
                action: #selector(endTrip)
            )
            buttons.append(endButton)
        } else {
            let startButton = createBarButton(
                title: "Start Trip",
                image: UIImage(systemName: "play.circle.fill"),
                action: #selector(startTrip)
            )
            buttons.append(startButton)
        }
        
        let statusButton = createBarButton(
            title: "Status",
            image: UIImage(systemName: "chart.bar.fill"),
            action: #selector(showStatus)
        )
        buttons.append(statusButton)
        
        mapTemplate?.leadingNavigationBarButtons = buttons
    }
    
    // MARK: - Trip Management
    
    @objc private func startTrip() {
        guard !isTripActive else { return }
        
        isTripActive = true
        tripStartTime = Date()
        tripDistance = 0.0
        
        // Notify Flutter
        methodChannel?.invokeMethod("tripStarted", arguments: [
            "startTime": tripStartTime?.timeIntervalSince1970 ?? 0
        ])
        
        updateNavigationButtons()
        showTripStartedAlert()
        
        // Update Siri shortcuts
        updateSiriShortcuts()
    }
    
    @objc private func endTrip() {
        guard isTripActive else { return }
        
        let endTime = Date()
        let duration = tripStartTime?.timeIntervalSince(endTime) ?? 0
        
        isTripActive = false
        
        // Notify Flutter
        methodChannel?.invokeMethod("tripEnded", arguments: [
            "endTime": endTime.timeIntervalSince1970,
            "duration": abs(duration),
            "distance": tripDistance
        ])
        
        tripStartTime = nil
        tripDistance = 0.0
        
        updateNavigationButtons()
        showTripEndedAlert(duration: abs(duration))
        
        // Update Siri shortcuts
        updateSiriShortcuts()
    }
    
    @objc private func showStatus() {
        showStatusList()
    }
    
    private func showTripStartedAlert() {
        let alert = CPAlertTemplate(
            titleVariants: ["Trip Started"],
            actions: [CPAlertAction(title: "OK", style: .default) { _ in }]
        )
        
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
        
        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
    }
    
    private func showTripEndedAlert(duration: TimeInterval) {
        let minutes = Int(duration / 60)
        let alert = CPAlertTemplate(
            titleVariants: ["Trip Ended"],
            actions: [CPAlertAction(title: "OK", style: .default) { _ in }]
        )
        
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
    }
    
    private func showStatusList() {
        // Get current stats from Flutter
        methodChannel?.invokeMethod("getStats", arguments: nil) { [weak self] result in
            DispatchQueue.main.async {
                self?.displayStatusList(with: result)
            }
        }
    }
    
    private func displayStatusList(with data: Any?) {
        guard let stats = data as? [String: Any] else { return }
        
        let todayCO2 = stats["todayCO2"] as? Double ?? 0.0
        let todayDistance = stats["todayDistance"] as? Double ?? 0.0
        let activitiesCount = stats["activitiesCount"] as? Int ?? 0
        
        let items = [
            CPListItem(
                text: "Today's CO₂",
                detailText: String(format: "%.1f kg", todayCO2)
            ),
            CPListItem(
                text: "Distance Traveled",
                detailText: String(format: "%.1f km", todayDistance)
            ),
            CPListItem(
                text: "Number of Trips",
                detailText: "\(activitiesCount)"
            ),
            CPListItem(
                text: "Current Status",
                detailText: isTripActive ? "Trip Active" : "No Active Trip"
            )
        ]
        
        let statusList = CPListTemplate(title: "Carbon Tracker Status", sections: [
            CPListSection(items: items)
        ])
        
        interfaceController?.pushTemplate(statusList, animated: true, completion: nil)
    }
    
    // MARK: - Siri Shortcuts Integration
    
    private func setupSiriShortcuts() {
        donateStartTripShortcut()
        donateEndTripShortcut()
        donateCheckStatusShortcut()
        donateEcoRouteShortcut()
    }
    
    private func updateSiriShortcuts() {
        if isTripActive {
            donateEndTripShortcut()
        } else {
            donateStartTripShortcut()
        }
    }
    
    private func donateStartTripShortcut() {
        let intent = INStartWorkoutIntent()
        intent.workoutName = INSpeakableString(spokenPhrase: "Carbon tracking trip")
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.identifier = "start_trip"
        
        interaction.donate { error in
            if let error = error {
                print("Failed to donate start trip shortcut: \(error)")
            }
        }
    }
    
    private func donateEndTripShortcut() {
        let intent = INEndWorkoutIntent()
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.identifier = "end_trip"
        
        interaction.donate { error in
            if let error = error {
                print("Failed to donate end trip shortcut: \(error)")
            }
        }
    }
    
    private func donateCheckStatusShortcut() {
        if #available(iOS 13.0, *) {
            let intent = INGetVisualCodeIntent()
            intent.codeType = .other
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.identifier = "check_status"
            
            interaction.donate { error in
                if let error = error {
                    print("Failed to donate check status shortcut: \(error)")
                }
            }
        }
    }
    
    private func donateEcoRouteShortcut() {
        if #available(iOS 13.0, *) {
            let intent = INSearchForNotebookItemsIntent()
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.identifier = "eco_route"
            
            interaction.donate { error in
                if let error = error {
                    print("Failed to donate eco route shortcut: \(error)")
                }
            }
        }
    }
    
    // MARK: - Voice Recognition Handler
    
    func handleVoiceCommand(_ command: String, parameters: [String: Any] = [:]) {
        switch command.lowercased() {
        case "start trip", "begin journey", "start tracking":
            if !isTripActive {
                startTrip()
            }
        case "end trip", "stop trip", "finish journey":
            if isTripActive {
                endTrip()
            }
        case "check status", "show status", "quick status":
            showStatus()
        case "eco route", "green route", "efficient route":
            showEcoRouteSuggestions()
        default:
            showUnknownCommandAlert()
        }
    }
    
    private func showEcoRouteSuggestions() {
        let suggestions = [
            "Choose routes with less traffic",
            "Maintain steady speeds",
            "Avoid excessive acceleration",
            "Use cruise control on highways"
        ]
        
        let items = suggestions.map { suggestion in
            CPListItem(text: suggestion, detailText: nil)
        }
        
        let ecoList = CPListTemplate(title: "Eco-Friendly Tips", sections: [
            CPListSection(items: items)
        ])
        
        interfaceController?.pushTemplate(ecoList, animated: true, completion: nil)
    }
    
    private func showUnknownCommandAlert() {
        let alert = CPAlertTemplate(
            titleVariants: ["Unknown Command"],
            actions: [CPAlertAction(title: "OK", style: .default) { _ in }]
        )
        
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
        
        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
    }
}

// MARK: - CPMapTemplateDelegate

@available(iOS 12.0, *)
extension CarPlayManager: CPMapTemplateDelegate {
    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
        // Handle navigation start
        if !isTripActive {
            startTrip()
        }
    }
    
    func mapTemplate(_ mapTemplate: CPMapTemplate, displayStyleFor maneuver: CPManeuver) -> CPManeuverDisplayStyle {
        return .default
    }
}

// MARK: - CarPlay Scene Delegate

@available(iOS 13.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, 
                                  didConnect interfaceController: CPInterfaceController) {
        CarPlayManager.shared.setupCarPlayInterface(
            with: interfaceController,
            window: templateApplicationScene.carWindow
        )
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, 
                                  didDisconnect interfaceController: CPInterfaceController) {
        CarPlayManager.shared.interfaceController = nil
        CarPlayManager.shared.window = nil
    }
}