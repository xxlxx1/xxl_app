//
//  CityPhotosView.swift
//  xxl_app
//
//  Created by Ducc on 2026-02-16.
//

import SwiftUI
import Photos

struct CityPhotosView: View {
    let cityName: String
    let year: Int
    let month: Int
    @ObservedObject var photoManager: PhotoAlbumManager

    @State private var selectedAsset: PHAsset?
    @State private var selectedDay: Int?
    @State private var showFullScreen = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 4)
    private let monthNames = [
        1: "1月", 2: "2月", 3: "3月", 4: "4月",
        5: "5月", 6: "6月", 7: "7月", 8: "8月",
        9: "9月", 10: "10月", 11: "11月", 12: "12月"
    ]

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }

    private var groupedByDay: [(day: Int, date: Date, assets: [PHAsset])] {
        let assets = photoManager.photosByCity[cityName] ?? []
        var dayAssets: [Int: [PHAsset]] = [:]
        var dayDates: [Int: Date] = [:]

        for asset in assets {
            guard let date = asset.creationDate else { continue }
            let components = calendar.dateComponents([.day], from: date)
            guard let day = components.day else { continue }
            dayAssets[day, default: []].append(asset)
            if dayDates[day] == nil {
                dayDates[day] = date
            }
        }

        return dayAssets.keys.sorted().compactMap { day in
            guard let date = dayDates[day], let assets = dayAssets[day] else { return nil }
            return (day, date, assets)
        }
    }

    private var allAssetsFlattened: [PHAsset] {
        groupedByDay.flatMap { $0.assets }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupedByDay, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatDate(group.date))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(group.assets, id: \.localIdentifier) { asset in
                                CityPhotoThumbnail(asset: asset, photoManager: photoManager)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .onTapGesture {
                                        let components = calendar.dateComponents([.day], from: asset.creationDate ?? Date())
                                        selectedDay = components.day ?? group.day
                                        selectedAsset = asset
                                    }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(cityName)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: Binding(
            get: { selectedAsset != nil && selectedDay != nil },
            set: { if !$0 { selectedAsset = nil; selectedDay = nil } }
        )) {
            if let asset = selectedAsset, let day = selectedDay {
                FullScreenImageView(
                    asset: asset,
                    day: day,
                    monthName: monthNames[month] ?? "\(month)月",
                    year: year,
                    onDismiss: {
                        selectedAsset = nil
                        selectedDay = nil
                    },
                    allAssets: allAssetsFlattened,
                    onAssetChanged: { newAsset, newDay in
                        selectedAsset = newAsset
                        selectedDay = newDay
                    }
                )
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

private struct CityPhotoThumbnail: View {
    let asset: PHAsset
    let photoManager: PhotoAlbumManager
    @State private var image: UIImage?
    @State private var loaded = false

    private static let thumbnailSize = CGSize(width: 200, height: 200)

    var body: some View {
        let cached = photoManager.cachedImage(for: asset, size: Self.thumbnailSize)
        ZStack {
            if let img = cached ?? image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.15)
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .onAppear {
            if cached == nil && !loaded {
                loadThumbnail()
            }
        }
    }

    private func loadThumbnail() {
        photoManager.loadImage(for: asset, size: Self.thumbnailSize) { loadedImage in
            self.image = loadedImage
            self.loaded = true
        }
    }
}
