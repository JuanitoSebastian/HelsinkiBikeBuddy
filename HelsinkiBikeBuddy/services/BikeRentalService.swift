//
//  BikeRentalService.swift
//  HelsinkiBikeBuddy
//
//  Created by Juan Covarrubias on 12.2.2021.
//

import Foundation
import Apollo
import ApolloWebSocket

class Network {
    static let shared = Network()
    let url = "https://api.digitransit.fi/routing/v1/routers/hsl/index/graphql"
    private(set) lazy var apollo = ApolloClient(url: URL(string: url)!)
}

enum ApiState {
    case allGood
    case setup
    case error
}

// TODO: Handle errors in networking
// TODO: Handle upddating of saved stations

class BikeRentalService: ObservableObject, ReachabilityObserverDelegate {

    private var timer: Timer?
    @Published var apiState: ApiState
    var lastFetchAccurate: Bool?

    // Singleton
    static let shared = BikeRentalService()

    private init() {
        self.timer = nil
        self.apiState = .setup
        try? addReachabilityObserver()
    }

    deinit {
        removeReachabilityObserver()
    }

    func reachabilityChanged(_ isReachable: Bool) {
        if isReachable {
            setState(.allGood)
            return
        }
        setState(.error)
    }

    func setTimer() {
        self.timer = Timer.scheduledTimer(
            timeInterval: 30,
            target: self,
            selector: #selector(updateAll),
            userInfo: nil,
            repeats: true
        )
    }

    @objc
    func updateAll() {
        updateFavorites()
        fetchNearbyStations()
    }

    func updateFavorites() {
        for var bikeRentalStation in BikeRentalStationStorage.shared.stationsFavorite.value {
            bikeRentalStation.fetched = Date()

        }
        BikeRentalStationStorage.shared.saveMoc()
    }

    func updateStationValues(
        bikeRentalStation: BikeRentalStation,
        resBikeRentalStop: FetchNearByBikeRentalStationsQuery.Data.Nearest.Edge.Node.Place.AsBikeRentalStation
    ) {
        bikeRentalStation.lat = resBikeRentalStop.lat!
        bikeRentalStation.lon = resBikeRentalStop.lon!
        bikeRentalStation.spacesAvailable = Int64(resBikeRentalStop.spacesAvailable!)
        bikeRentalStation.bikesAvailable = Int64(resBikeRentalStop.bikesAvailable!)
        bikeRentalStation.allowDropoff = resBikeRentalStop.allowDropoff!
        bikeRentalStation.state = parseStateString(resBikeRentalStop.state!)
    }

    func fetchNearbyStations() {
        guard let userLocation = UserLocationManager.shared.userLocationObj else { return }
        if apiState == .error { return }

        lastFetchAccurate = UserLocationManager.shared.isLocationAccurate
        Network.shared.apollo.fetch(
            query: FetchNearByBikeRentalStationsQuery(
                lat: userLocation.coordinate.latitude,
                lon: userLocation.coordinate.longitude,
                maxDistance: UserSettingsManager.shared.nearbyDistance
            )
        ) { result in
            switch result {
            case .success(let graphQLResult):
                guard let edgesUnwrapped = graphQLResult.data?.nearest?.edges else { return }
                // Iterating thru the fetched stations
                var nearbyStationFetched: [RentalStation] = []
                for edge in edgesUnwrapped {
                    guard let stationUnwrapped = self.unwrapGraphQLStationObject(edge?.node?.place?.asBikeRentalStation) else {
                        return
                    }
                    if let bikeRentalStationCoreData = BikeRentalStationStorage.shared.bikeRentalStationFromCoreData(
                        stationId: stationUnwrapped.stationId!
                    ) {
                        self.updateStationValues(
                            bikeRentalStation: bikeRentalStationCoreData,
                            resBikeRentalStop: stationUnwrapped
                        )
                        nearbyStationFetched.append(bikeRentalStationCoreData)
                    } else {
                        let bikeRentalStationUnmanaged = UnmanagedBikeRentalStation(
                            stationId: stationUnwrapped.stationId!,
                            name: stationUnwrapped.name,
                            allowDropoff: stationUnwrapped.allowDropoff!,
                            bikesAvailable: Int64(stationUnwrapped.bikesAvailable!),
                            favorite: false,
                            fetched: Date(),
                            lat: stationUnwrapped.lat!,
                            lon: stationUnwrapped.lon!,
                            spacesAvailable: Int64(stationUnwrapped.spacesAvailable!),
                            state: self.parseStateString(stationUnwrapped.state!)
                        )
                        nearbyStationFetched.append(bikeRentalStationUnmanaged)
                    }
                    BikeRentalStationStorage.shared.stationsNearby.value = nearbyStationFetched
                }
            case .failure(let error):
                Helper.log("API Fecth failed: \(error)")
            }
        }
    }

    func fetchBikeRentalStation(stationId: String, completition: @escaping (_ rentalStation: UnmanagedBikeRentalStation?) -> Void) {
        Network.shared.apollo.fetch(query: FetchBikeRentalStationByStationIdQuery(stationId: stationId)) { result in
            switch result {
            case .success(let graphQlResults):
                guard let stationUnwrapped = graphQlResults.data?.bikeRentalStation else { return }

                let bikeRentalStationUnmanaged = UnmanagedBikeRentalStation(
                    stationId: stationUnwrapped.stationId!,
                    name: stationUnwrapped.name,
                    allowDropoff: stationUnwrapped.allowDropoff!,
                    bikesAvailable: Int64(stationUnwrapped.bikesAvailable!),
                    favorite: false,
                    fetched: Date(),
                    lat: stationUnwrapped.lat!,
                    lon: stationUnwrapped.lon!,
                    spacesAvailable: Int64(stationUnwrapped.spacesAvailable!),
                    state: self.parseStateString(stationUnwrapped.state!)
                )

                completition(bikeRentalStationUnmanaged)

                Helper.log("Success!")
            case .failure(let error):
                Helper.log("AI Fetch failed: \(error)")
                completition(nil)
            }
        }
    }

    private func unwrapGraphQLStationObject(_ wrapped: FetchNearByBikeRentalStationsQuery.Data.Nearest.Edge.Node.Place.AsBikeRentalStation?)
    -> FetchNearByBikeRentalStationsQuery.Data.Nearest.Edge.Node.Place.AsBikeRentalStation? {
        guard let stationUnwrapped = wrapped else { return nil }
        if stationUnwrapped.stationId == nil || stationUnwrapped.lat == nil || stationUnwrapped.lon == nil ||
            stationUnwrapped.spacesAvailable == nil || stationUnwrapped.spacesAvailable == nil ||
            stationUnwrapped.state == nil || stationUnwrapped.allowDropoff == nil {
            return nil
        }
        return stationUnwrapped
    }

    private func parseStateString(_ state: String) -> Bool {
        if state.contains("off") { return false }
        return true
    }

    private func setState(_ newApiState: ApiState) {
        if apiState != newApiState {
            apiState = newApiState
        }
    }
}
