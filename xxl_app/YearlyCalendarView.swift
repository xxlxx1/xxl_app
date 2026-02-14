//
//  YearlyCalendarView.swift
//  xxl_app
//
//  Created by Ducc on 2025-02-13.
//

import SwiftUI
import Photos

struct YearlyCalendarView: View {
    let year: Int
    @ObservedObject var photoManager: PhotoAlbumManager
    var onMonthTap: ((Int) -> Void)?
    var onPhotoTap: ((Int, Int, PHAsset) -> Void)?  // (month, day, asset)

    private let monthNames = ["", "1月", "2月", "3月", "4月", "5月", "6月",
                              "7月", "8月", "9月", "10月", "11月", "12月"]

    var body: some View {
        LazyVStack(spacing: 24) {
            ForEach(1...12, id: \.self) { month in
                VStack(spacing: 8) {
                    // Month header - tappable
                    HStack {
                        Text(monthNames[month])
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onMonthTap?(month)
                    }

                    // Calendar grid for this month
                    YearlyMonthGridView(
                        year: year,
                        month: month,
                        photoManager: photoManager,
                        onPhotoTap: { day, asset in
                            onPhotoTap?(month, day, asset)
                        }
                    )
                    .padding(.horizontal, 8)
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
    }
}

// Grid view for a single month in yearly view
struct YearlyMonthGridView: View {
    let year: Int
    let month: Int
    @ObservedObject var photoManager: PhotoAlbumManager
    var onPhotoTap: ((Int, PHAsset) -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(spacing: 4) {
            // Weekday headers (Monday to Sunday)
            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(0..<totalCells, id: \.self) { index in
                    cellView(for: index)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var monthInfo: (firstWeekday: Int, totalDays: Int) {
        photoManager.getMonthInfo(year: year, month: month)
    }

    private var totalCells: Int {
        let (firstWeekday, totalDays) = monthInfo
        return firstWeekday - 1 + totalDays
    }

    private func cellView(for index: Int) -> some View {
        let day = index - (monthInfo.firstWeekday - 1) + 1
        let isValidDay = day >= 1 && day <= monthInfo.totalDays

        return GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            if isValidDay {
                YearlyDayPhotoView(
                    month: month,
                    day: day,
                    photoManager: photoManager,
                    size: CGSize(width: size, height: size),
                    onPhotoTap: onPhotoTap
                )
                .aspectRatio(1, contentMode: .fit)
                .background(Color.gray.opacity(0.1))
            } else {
                // Empty cell placeholder
                Rectangle()
                    .fill(Color.clear)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// Day photo view for yearly view (reads from photosByMonth)
struct YearlyDayPhotoView: View {
    let month: Int
    let day: Int
    @ObservedObject var photoManager: PhotoAlbumManager
    let size: CGSize
    var onPhotoTap: ((Int, PHAsset) -> Void)?

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var currentAsset: PHAsset?
    @State private var hasPhoto = false

    var body: some View {
        ZStack {
            if hasPhoto, let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let asset = currentAsset {
                            onPhotoTap?(day, asset)
                        }
                    }
            } else {
                // Placeholder for no photo
                Rectangle()
                    .fill(Color.white)
                    .frame(width: size.width, height: size.height)
            }

            // Day number overlay
            Text("\(day)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(hasPhoto ? .white : .black)
                .shadow(color: .black.opacity(hasPhoto ? 0.5 : 0), radius: hasPhoto ? 1 : 0, x: 0, y: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(2)
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: photoManager.photosByMonth[month]) { _, _ in
            loadImage()
        }
    }

    private func loadImage() {
        guard !isLoading else { return }
        isLoading = true

        // Store current values to validate callback
        let requestedMonth = self.month
        let requestedDay = self.day

        // Check if there's a photo for this month and day
        let photosForMonth = photoManager.photosByMonth[month]
        let asset = photosForMonth?[day]

        if let asset = asset {
            photoManager.loadImage(for: asset, size: size) { loadedImage in
                if self.month == requestedMonth && self.day == requestedDay {
                    self.image = loadedImage
                    self.currentAsset = asset
                    self.hasPhoto = true
                }
                self.isLoading = false
            }
        } else {
            self.image = nil
            self.currentAsset = nil
            self.hasPhoto = false
            self.isLoading = false
        }
    }
}

#Preview {
    YearlyCalendarView(year: 2025, photoManager: PhotoAlbumManager())
}
