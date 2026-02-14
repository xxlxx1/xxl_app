//
//  CalendarGridView.swift
//  xxl_app
//
//  Created by Ducc on 2025-02-13.
//

import SwiftUI
import Photos

struct CalendarGridView: View {
    let year: Int
    let month: Int
    @ObservedObject var photoManager: PhotoAlbumManager
    var onPhotoTap: ((Int, PHAsset) -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers (Monday to Sunday)
            HStack(spacing: 0) {
                ForEach(["周一", "周二", "周三", "周四", "周五", "周六", "周日"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 2) {
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
                DayPhotoView(
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

#Preview {
    CalendarGridView(year: 2025, month: 2, photoManager: PhotoAlbumManager(), onPhotoTap: nil)
}
