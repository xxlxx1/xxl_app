//
//  PhotoAlbumManager.swift
//  xxl_app
//
//  Created by Ducc on 2025-02-13.
//

import UIKit
import Photos
import Combine
import CoreLocation
import MapKit

class PhotoAlbumManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var photosByDay: [Int: PHAsset] = [:]  // [day: PHAsset], day is 1-31
    @Published var photosByMonth: [Int: [Int: PHAsset]] = [:]  // [month: [day: PHAsset]], for yearly view
    @Published var cityInfo: [(city: String, count: Int)] = []  // [(city name, photo count)]

    private let imageManager = PHCachingImageManager()
    private var calendar = Calendar(identifier: .gregorian)
    private var targetYear: Int?
    private var targetMonth: Int?
    private var locationTask: Task<Void, Never>?
    private var yearLoadTask: Task<Void, Never>?

    // Local city bounding boxes to avoid unnecessary API calls
    private struct CityBounds {
        let name: String
        let minLng: Double
        let maxLng: Double
        let minLat: Double
        let maxLat: Double

        func contains(lat: Double, lng: Double) -> Bool {
            lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng
        }
    }

    private let knownCities: [CityBounds] = [
        CityBounds(name: "北京市",  minLng: 115.42, maxLng: 117.50, minLat: 39.44, maxLat: 41.05),
        CityBounds(name: "上海市",  minLng: 120.52, maxLng: 122.12, minLat: 30.66, maxLat: 31.86),
        CityBounds(name: "广州市",  minLng: 112.68, maxLng: 113.70, minLat: 22.50, maxLat: 23.50),
        CityBounds(name: "深圳市",  minLng: 113.75, maxLng: 114.88, minLat: 22.45, maxLat: 22.78),
        CityBounds(name: "桂林市",  minLng: 110.08, maxLng: 110.48, minLat: 24.78, maxLat: 25.45),
        CityBounds(name: "珠海市",  minLng: 113.10, maxLng: 113.68, minLat: 21.80, maxLat: 22.37),
        CityBounds(name: "成都市",  minLng: 103.57, maxLng: 104.23, minLat: 30.40, maxLat: 30.98),
        CityBounds(name: "杭州市",  minLng: 119.85, maxLng: 120.46, minLat: 30.05, maxLat: 30.45),
        CityBounds(name: "香港特别行政区", minLng: 113.80, maxLng: 114.40, minLat: 22.10, maxLat: 22.50),
    ]

    private func lookupLocalCity(lat: Double, lng: Double) -> String? {
        for city in knownCities {
            if city.contains(lat: lat, lng: lng) {
                return city.name
            }
        }
        return nil
    }

    init() {
        calendar.firstWeekday = 2  // Monday is the first day
    }

    // Request photo library authorization
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                completion(status == .authorized)
            }
        }
    }

    // Load photos for specified year and month
    func loadPhotos(year: Int, month: Int, completion: @escaping ([Int: PHAsset]) -> Void) {
        guard authorizationStatus == .authorized else {
            completion([:])
            return
        }

        targetYear = year
        targetMonth = month

        // Get date range for month
        let (startDate, endDate) = getMonthRange(year: year, month: month)

        // Configure fetch options
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate)
        // No fetchLimit - we need all photos to cover all days in the month

        // Fetch assets
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var groupedPhotos: [Int: [PHAsset]] = [:]

        fetchResult.enumerateObjects { asset, _, _ in
            if let creationDate = asset.creationDate {
                let components = self.calendar.dateComponents([.year, .month, .day], from: creationDate)
                if let day = components.day {
                    if groupedPhotos[day] == nil {
                        groupedPhotos[day] = []
                    }
                    groupedPhotos[day]?.append(asset)
                }
            }
        }

        // Randomly select one photo per day
        var selectedPhotos: [Int: PHAsset] = [:]
        for (day, photos) in groupedPhotos {
            if let randomPhoto = photos.randomElement() {
                selectedPhotos[day] = randomPhoto
            }
        }

        DispatchQueue.main.async {
            self.photosByDay = selectedPhotos
            completion(selectedPhotos)
        }
    }

    // Load image for a specific day
    func loadImage(for day: Int, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        guard let asset = photosByDay[day] else {
            completion(nil)
            return
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
            if let image = image {
                completion(self.cropToSquare(image: image))
            } else {
                completion(nil)
            }
        }
    }

    // Crop image to center square
    private func cropToSquare(image: UIImage) -> UIImage {
        // Get the actual pixel dimensions
        guard let cgImage = image.cgImage else {
            return image
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let minDimension = min(width, height)

        let cropRect = CGRect(
            x: (width - minDimension) / 2,
            y: (height - minDimension) / 2,
            width: minDimension,
            height: minDimension
        )

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }

        return UIImage(cgImage: croppedCGImage, scale: 1.0, orientation: image.imageOrientation)
    }

    // Fallback geocoding using multiple APIs
    private func geocodeWithNominatim(location: CLLocation) async -> String? {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Try BigDataCloud first (works better in China, free, no API key needed)
        if let city = await geocodeWithBigDataCloud(lat: lat, lon: lon) {
            return city
        }

        // Fallback to Nominatim
        return await geocodeWithNominatimAPI(lat: lat, lon: lon)
    }

    private func geocodeWithBigDataCloud(lat: Double, lon: Double) async -> String? {
        await Task.detached(priority: .userInitiated) {
            let urlString = "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=\(lat)&longitude=\(lon)&localityLanguage=zh"

            guard let url = URL(string: urlString) else { return nil }

            var request = URLRequest(url: url)
            request.timeoutInterval = 15

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    print("[Location] BigDataCloud HTTP status: \(httpResponse.statusCode)")
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Try to get city name
                    let city = json["city"] as? String
                        ?? json["locality"] as? String
                        ?? json["principalSubdivision"] as? String
                        ?? json["countryName"] as? String
                    if let city = city {
                        print("[Location] BigDataCloud found: \(city)")
                        return city
                    }
                }
            } catch {
                print("[Location] BigDataCloud error: \(error.localizedDescription)")
            }
            return nil
        }.value
    }

    private func geocodeWithNominatimAPI(lat: Double, lon: Double) async -> String? {
        await Task.detached(priority: .userInitiated) {
            let urlString = "https://nominatim.openstreetmap.org/reverse?format=json&lat=\(lat)&lon=\(lon)&zoom=10"

            guard let url = URL(string: urlString) else { return nil }

            var request = URLRequest(url: url)
            request.setValue("xxl-app/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 30

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    print("[Location] Nominatim HTTP status: \(httpResponse.statusCode)")
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let address = json["address"] as? [String: Any] {
                    let city = address["city"] as? String
                        ?? address["town"] as? String
                        ?? address["village"] as? String
                        ?? address["county"] as? String
                        ?? address["state"] as? String
                        ?? address["country"] as? String
                    return city
                }
            } catch let error as URLError {
                print("[Location] Nominatim URL error: \(error.code.rawValue) - \(error.localizedDescription)")
            } catch {
                print("[Location] Nominatim error: \(error.localizedDescription)")
            }
            return nil
        }.value
    }

    // Get date range for a month (month starts at 1)
    private func getMonthRange(year: Int, month: Int) -> (Date, Date) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0

        guard let startDate = calendar.date(from: components) else {
            fatalError("Invalid date components")
        }

        components.month = month + 1
        components.day = 0
        components.hour = 23
        components.minute = 59
        components.second = 59

        guard let endDate = calendar.date(from: components) else {
            // Handle December by using next year January
            components.year = year + 1
            components.month = 1
            components.day = 0
            guard let endDate = calendar.date(from: components) else {
                fatalError("Invalid date components")
            }
            return (startDate, endDate)
        }

        return (startDate, endDate)
    }

    // Get month info including first weekday (Monday-based) and total days
    func getMonthInfo(year: Int, month: Int) -> (firstWeekday: Int, totalDays: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let firstDayDate = calendar.date(from: components) else {
            return (0, 0)
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayDate)
        // Apple weekday: Sun=1, Mon=2, ..., Sat=7
        // Convert to Monday-based: Mon=1, Tue=2, ..., Sun=7
        let mondayBasedIndex = (firstWeekday - 2 + 7) % 7 + 1

        let range = calendar.range(of: .day, in: .month, for: firstDayDate)
        let totalDays = range?.count ?? 0

        return (mondayBasedIndex, totalDays)
    }

    // Load location info for all photos in the month
    func loadLocationInfo(year: Int, month: Int) async {
        // Cancel any previous location loading task
        locationTask?.cancel()

        locationTask = Task {
            guard authorizationStatus == .authorized else {
                await MainActor.run {
                    self.cityInfo = []
                }
                return
            }

            // Get date range for month
            let (startDate, endDate) = getMonthRange(year: year, month: month)

            // Configure fetch options
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate)

            // Fetch all assets (not just one per day)
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            // Collect all locations first
            var locations: [CLLocation] = []
            fetchResult.enumerateObjects { asset, _, _ in
                if let location = asset.location {
                    locations.append(CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
                }
            }

            // If no locations, clear city info and return
            if locations.isEmpty {
                await MainActor.run {
                    self.cityInfo = []
                }
                return
            }

            // Deduplicate nearby locations (within 500m to reduce API calls)
            var uniqueLocations: [CLLocation] = []
            for location in locations {
                let isNearby = uniqueLocations.contains { existing in
                    existing.distance(from: location) < 15000  // 1500m threshold
                }
                if !isNearby {
                    uniqueLocations.append(location)
                }
            }

            // Limit to max 45 unique locations to avoid API throttling (50 requests/60s limit)
            let maxLocations = 45
            if uniqueLocations.count > maxLocations {
                uniqueLocations = Array(uniqueLocations.prefix(maxLocations))
            }

            print("[Location] Total photos: \(locations.count), Unique locations: \(uniqueLocations.count)")

            // Geocode all unique locations using CLGeocoder with rate limiting
            var cityCounts: [String: Int] = [:]
            var cityOrder: [String] = []  // Preserve insertion order
            let geocoder = CLGeocoder()

            // Helper: record a city and immediately update UI, preserving order
            @Sendable func recordCity(_ city: String) async {
                guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                if cityCounts[city] == nil {
                    cityOrder.append(city)
                }
                cityCounts[city, default: 0] += 1
                let ordered = cityOrder.map { ($0, cityCounts[$0]!) }
                await MainActor.run {
                    self.cityInfo = ordered
                }
            }

            for (index, location) in uniqueLocations.enumerated() {
                // Check for cancellation
                if Task.isCancelled { return }

                // Try local bounding box lookup first
                let lat = location.coordinate.latitude
                let lng = location.coordinate.longitude
                if let localCity = self.lookupLocalCity(lat: lat, lng: lng) {
                    print("[Location] Local match: \(localCity)")
                    await recordCity(localCity)
                    continue
                }

                var success = false
                var retryCount = 0
                let maxRetries = 3

                while !success && retryCount < maxRetries {
                    do {
                        let placemarks = try await geocoder.reverseGeocodeLocation(location)
                        if let placemark = placemarks.first {
                            // Try multiple fields for city name, works for both China and international locations
                            if let city = placemark.locality
                                ?? placemark.subAdministrativeArea
                                ?? placemark.administrativeArea
                                ?? placemark.name {
                                print("[Location] Found city: \(city)")
                                await recordCity(city)
                            }
                        }
                        success = true
                    } catch {
                        let nsError = error as NSError
                        print("[Location] Error domain: \(nsError.domain), code: \(nsError.code), desc: \(error.localizedDescription)")

                        // If throttled (GEOErrorDomain code -3), wait and retry
                        if nsError.domain == "GEOErrorDomain" && nsError.code == -3 {
                            retryCount += 1
                            print("[Location] API throttled, waiting 30 seconds... (retry \(retryCount)/\(maxRetries))")
                            try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30 seconds
                        } else if nsError.domain == "kCLErrorDomain" && nsError.code == 8 {
                            // No result found - try Nominatim as fallback
                            print("[Location] CLGeocoder failed, trying Nominatim...")
                            if let city = await geocodeWithNominatim(location: location) {
                                print("[Location] Nominatim found: \(city)")
                                await recordCity(city)
                            } else {
                                print("[Location] Nominatim also failed, skipping this location")
                            }
                            success = true
                        } else if nsError.domain == "GEOErrorDomain" && nsError.code == 2 {
                            // GEOErrorDomain code 2: try Nominatim as fallback
                            print("[Location] GEO error 2, trying Nominatim...")
                            if let city = await geocodeWithNominatim(location: location) {
                                print("[Location] Nominatim found: \(city)")
                                await recordCity(city)
                            } else {
                                print("[Location] Nominatim also failed, skipping this location")
                            }
                            success = true
                        } else {
                            print("[Location] Other error, skipping this location")
                            break  // Non-throttle error, skip this location
                        }
                    }
                }
            }

            print("[Location] Final city info: \(cityCounts)")
        }

        await locationTask?.value
    }

    // Load photos for entire year (for yearly view)
    func loadPhotosForYear(year: Int) async {
        // Cancel any previous year loading task
        yearLoadTask?.cancel()

        yearLoadTask = Task {
            guard authorizationStatus == .authorized else {
                await MainActor.run {
                    self.photosByMonth = [:]
                }
                return
            }

            var result: [Int: [Int: PHAsset]] = [:]

            for month in 1...12 {
                // Check for cancellation
                if Task.isCancelled { return }

                // Get date range for month
                let (startDate, endDate) = getMonthRange(year: year, month: month)

                // Configure fetch options
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate)
                // No fetchLimit - need all photos to cover all days

                // Fetch assets
                let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

                var groupedPhotos: [Int: [PHAsset]] = [:]

                fetchResult.enumerateObjects { asset, _, _ in
                    if let creationDate = asset.creationDate {
                        let components = self.calendar.dateComponents([.year, .month, .day], from: creationDate)
                        if let day = components.day {
                            if groupedPhotos[day] == nil {
                                groupedPhotos[day] = []
                            }
                            groupedPhotos[day]?.append(asset)
                        }
                    }
                }

                // Randomly select one photo per day
                var selectedPhotos: [Int: PHAsset] = [:]
                for (day, photos) in groupedPhotos {
                    if let randomPhoto = photos.randomElement() {
                        selectedPhotos[day] = randomPhoto
                    }
                }

                result[month] = selectedPhotos
            }

            // Check for cancellation before updating UI
            if Task.isCancelled { return }

            await MainActor.run {
                self.photosByMonth = result
            }
        }

        await yearLoadTask?.value
    }

    // Get photos for a specific month (for yearly view)
    func getPhotosForMonth(_ month: Int) -> [Int: PHAsset] {
        return photosByMonth[month] ?? [:]
    }

    // Load image for a specific asset (for yearly view)
    func loadImage(for asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
            if let image = image {
                completion(self.cropToSquare(image: image))
            } else {
                completion(nil)
            }
        }
    }
}
