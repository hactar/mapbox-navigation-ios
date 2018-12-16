import XCTest
import FBSnapshotTestCase
import Turf
import TestHelper
import MapboxDirections
@testable import MapboxCoreNavigation
@testable import MapboxNavigation

struct AssociatedLocation {
    let location: CLLocation
    let text: String
}

class HistoricRouteProgressTests: FBSnapshotTestCase {

    override func setUp() {
        super.setUp()
        recordMode = false
    }

    func testHistoricRouteProgressDisabled() {
        runTest(shouldDiscardHistory: true)
    }
    
    func testHistoricRouteProgressEnabled() {
        runTest(shouldDiscardHistory: false)
    }
    
    func runTest(shouldDiscardHistory: Bool) {
        // Short initial route (Blue line)
        let route = Fixture.route(from: "historic-route-progress")
        // New route from where the trace missed a turn (Green line)
        let reroute = Fixture.route(from: "historic-route-progress-reroute")
        // Trace of a detour from the initial origin to the destination (generated by `Fixture.generateTrace(for:)`) (Red dots)
        let rawTrace = Fixture.locations(from: "historic-route-progress.trace")
        
        var trace = (rawTrace as [CLLocation?]).enumerated().compactMap { return $0.offset % 2 == 0 ? nil : $0.element }
                                               .enumerated().compactMap { return $0.offset % 2 == 0 ? nil : $0.element }
        trace.append(rawTrace.last!)
        
        
        let directions = DirectionsSpy(accessToken: "foo")
        
        let locationManager = ReplayLocationManager(locations: trace)
        let service = MapboxNavigationService(route: route,
                                              directions: directions,
                                              locationSource: locationManager,
                                              eventsManagerType: NavigationEventsManagerSpy.self,
                                              simulating: SimulationMode.never)
        
        let tester = HistoricProgressTester(navigationService: service, shouldDiscardHistory: shouldDiscardHistory, upcomingRoutes: [reroute])
        
        let view = NavigationPlotter(frame: CGRect(origin: .zero, size: CGSize(width: 1000, height: 1000)))
        view.routePlotters = [RoutePlotter(route: route, color: .route, lineWidth: 8, drawDotIndicator: false, drawTextIndicator: false),
                              RoutePlotter(route: reroute, color: .green, lineWidth: 8, drawDotIndicator: false, drawTextIndicator: false)]
        
        var associatedLocations = [AssociatedLocation]()
        
        for location in trace {
            service.router!.locationManager!(locationManager, didUpdateLocations: [location])
            
            let totalDistanceTraveled = service.router!.routeProgress.totalDistanceTraveled
            let totalFractionTraveled = service.router!.routeProgress.totalFractionTraveled
            let loc = AssociatedLocation.init(location: location, text: "\(Int(totalDistanceTraveled)):\( Double(round(1000*totalFractionTraveled)/1000))")
            associatedLocations.append(loc)
        }
        
        view.coordinatePlotters = [CoordinatePlotter(coordinates: associatedLocations.map { $0.location.coordinate },
                                                     coordinateText: associatedLocations.map { $0.text },
                                                     fontSize: 16,
                                                     color: .red,
                                                     drawIndexesAsText: false)]
        
        verify(view)
    }
}

class HistoricProgressTester: NavigationServiceDelegate {

    let navigationService: MapboxNavigationService
    let shouldDiscardHistory: Bool
    var upcomingRoutes: [Route]
    
    init(navigationService: MapboxNavigationService, shouldDiscardHistory: Bool, upcomingRoutes: [Route]) {
        self.navigationService = navigationService
        self.shouldDiscardHistory = shouldDiscardHistory
        self.upcomingRoutes = upcomingRoutes
        
        self.navigationService.delegate = self
    }
    
    func navigationServiceShouldDiscardHistory(_ service: NavigationService) -> Bool {
        return shouldDiscardHistory
    }
    
    func navigationService(_ service: NavigationService, shouldRerouteFrom location: CLLocation) -> Bool {
        navigationService.route = upcomingRoutes.popLast()!
        return false
    }
}