//
//  CalendarPhotoView.swift
//  xxl_app
//
//  Created by Ducc on 2025-02-13.
//

import SwiftUI
import Photos

struct CalendarPhotoView: View {
    @StateObject private var photoManager = PhotoAlbumManager()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var viewMode: ViewMode = .month
    @State private var showingPermissionAlert = false
    @State private var selectedAsset: PHAsset?
    @State private var selectedDay: Int?
    @State private var selectedMonthForPhoto: Int?  // For yearly view photo tap
    @State private var isSaving = false
    @State private var showSaveSuccessAlert = false
    @State private var thumbnailImages: [Int: UIImage] = [:]  // Store thumbnails for export
    @State private var debounceTask: Task<Void, Never>?

    enum ViewMode {
        case month
        case year
    }

    private let years = Array(2000...2030)
    private let months = Array(1...12)
    private let monthNames = [
        1: "1月", 2: "2月", 3: "3月", 4: "4月",
        5: "5月", 6: "6月", 7: "7月", 8: "8月",
        9: "9月", 10: "10月", 11: "11月", 12: "12月"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Year selector and view mode toggle
                HStack(spacing: 16) {
                    Spacer()

                    Picker("年份", selection: $selectedYear) {
                        ForEach(years, id: \.self) { year in
                            Text(String(format: "%d", year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 130)
                    .clipped()
                    .environment(\.locale, Locale(identifier: "en_US_POSIX"))

                    // Month picker only shown in month mode
                    if viewMode == .month {
                        Picker("月份", selection: $selectedMonth) {
                            ForEach(months, id: \.self) { month in
                                Text(monthNames[month] ?? "\(month)").tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .clipped()
                    }

                    // View mode toggle
                    Button(action: toggleViewMode) {
                        HStack(spacing: 4) {
                            Image(systemName: viewMode == .month ? "calendar.badge.plus" : "calendar")
                            Text(viewMode == .month ? "年" : "月")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .frame(height: 120)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))

                Divider()

                // Selected year/month display with download button (only in month mode)
                if viewMode == .month {
                    HStack {
                        Text("\(String(format: "%d", selectedYear))年 \(monthNames[selectedMonth] ?? "\(selectedMonth)月")")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()

                        Button(action: saveCalendarAsImage) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("保存")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .disabled(isSaving)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))

                    Divider()
                }

                // Calendar content based on view mode
                if viewMode == .month {
                    // Month view
                    ScrollView {
                        CalendarGridView(
                            year: selectedYear,
                            month: selectedMonth,
                            photoManager: photoManager,
                            onPhotoTap: { day, asset in
                                selectedDay = day
                                selectedAsset = asset
                            }
                        )
                        .padding()

                        // City info section
                        if !photoManager.cityInfo.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("拍摄地点")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)

                                if photoManager.cityInfo.count == 1 {
                                    // Single location: just show it
                                    let cityInfo = photoManager.cityInfo[0]
                                    HStack(spacing: 6) {
                                        Text("📍")
                                            .font(.system(size: 12))
                                        Text(cityInfo.city)
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Text("(\(cityInfo.count))")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.05))
                                    .cornerRadius(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                } else {
                                    // Multiple locations: two columns, each left-aligned
                                    HStack(alignment: .top, spacing: 8) {
                                        // Left column
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(Array(photoManager.cityInfo.enumerated()), id: \.offset) { index, cityInfo in
                                                if index % 2 == 0 {
                                                    HStack(spacing: 6) {
                                                        Text("📍")
                                                            .font(.system(size: 12))
                                                        Text(cityInfo.city)
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.primary)
                                                        Text("(\(cityInfo.count))")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(Color.blue.opacity(0.05))
                                                    .cornerRadius(8)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        // Right column
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(Array(photoManager.cityInfo.enumerated()), id: \.offset) { index, cityInfo in
                                                if index % 2 == 1 {
                                                    HStack(spacing: 6) {
                                                        Text("📍")
                                                            .font(.system(size: 12))
                                                        Text(cityInfo.city)
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.primary)
                                                        Text("(\(cityInfo.count))")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(Color.blue.opacity(0.05))
                                                    .cornerRadius(8)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                        }
                    }
                } else {
                    // Year view
                    ScrollView {
                        YearlyCalendarView(
                            year: selectedYear,
                            photoManager: photoManager,
                            onMonthTap: { month in
                                // Navigate to month view
                                selectedMonth = month
                                viewMode = .month
                            },
                            onPhotoTap: { month, day, asset in
                                selectedMonthForPhoto = month
                                selectedDay = day
                                selectedAsset = asset
                            }
                        )
                    }
                }
            }
            .onChange(of: selectedYear) { _, _ in
                debouncedLoad()
            }
            .onChange(of: selectedMonth) { _, _ in
                debouncedLoad()
            }
            .alert("相册权限", isPresented: $showingPermissionAlert) {
                Button("取消", role: .cancel) { }
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("需要访问相册权限才能显示照片。请在设置中开启相册权限。")
            }
            .alert("保存成功", isPresented: $showSaveSuccessAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("日历图片已保存到相册。")
            }
            .fullScreenCover(isPresented: Binding(
                get: { selectedAsset != nil && selectedDay != nil },
                set: { if !$0 { selectedAsset = nil; selectedDay = nil; selectedMonthForPhoto = nil } }
            )) {
                if let asset = selectedAsset, let day = selectedDay {
                    FullScreenImageView(
                        asset: asset,
                        day: day,
                        monthName: monthNames[selectedMonthForPhoto ?? selectedMonth] ?? "\(selectedMonthForPhoto ?? selectedMonth)月",
                        year: selectedYear,
                        onDismiss: {
                            selectedAsset = nil
                            selectedDay = nil
                            selectedMonthForPhoto = nil
                        }
                    )
                }
            }
        }
        .onAppear {
            checkPermissionAndLoad()
        }
    }

    private func checkPermissionAndLoad() {
        switch photoManager.authorizationStatus {
        case .notDetermined:
            photoManager.requestAuthorization { granted in
                if granted {
                    if viewMode == .month {
                        loadPhotos()
                    } else {
                        loadYearPhotos()
                    }
                } else {
                    showingPermissionAlert = true
                }
            }
        case .authorized:
            if viewMode == .month {
                loadPhotos()
            } else {
                loadYearPhotos()
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        case .limited:
            if viewMode == .month {
                loadPhotos()
            } else {
                loadYearPhotos()
            }
        @unknown default:
            showingPermissionAlert = true
        }
    }

    private func toggleViewMode() {
        withAnimation {
            if viewMode == .month {
                viewMode = .year
                loadYearPhotos()
            } else {
                viewMode = .month
                loadPhotos()
            }
        }
    }

    private func loadPhotos() {
        // Clear location info first when switching months
        photoManager.cityInfo = []
        photoManager.loadPhotos(year: selectedYear, month: selectedMonth) { _ in
            // Photos loaded, now load location info
            self.loadLocationInfo()
        }
    }

    private func debouncedLoad() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms debounce
            guard !Task.isCancelled else { return }
            if viewMode == .month {
                loadPhotos()
            } else {
                loadYearPhotos()
            }
        }
    }

    private func loadYearPhotos() {
        Task {
            await photoManager.loadPhotosForYear(year: selectedYear)
        }
    }

    private func loadLocationInfo() {
        Task {
            await photoManager.loadLocationInfo(year: selectedYear, month: selectedMonth)
        }
    }

    private func saveCalendarAsImage() {
        isSaving = true

        // Preload all thumbnails before rendering
        loadAllThumbnails { thumbnails in
            self.thumbnailImages = thumbnails

            // Create the export view and render it
            let exportView = ExportableCalendarView(
                year: selectedYear,
                month: selectedMonth,
                monthName: monthNames[selectedMonth] ?? "\(selectedMonth)月",
                thumbnailImages: thumbnails,
                cityInfo: photoManager.cityInfo
            )

            let renderer = ImageRenderer(content: exportView)
            renderer.scale = 3  // High resolution
            renderer.isOpaque = true

            if let uiImage = renderer.uiImage {
                self.saveImageToPhotos(uiImage)
            } else {
                self.isSaving = false
            }
        }
    }

    private func loadAllThumbnails(completion: @escaping ([Int: UIImage]) -> Void) {
        var thumbnails: [Int: UIImage] = [:]
        let photosByDay = photoManager.photosByDay
        let totalDays = photosByDay.count

        guard totalDays > 0 else {
            completion(thumbnails)
            return
        }

        let imageManager = PHCachingImageManager()
        // Use high resolution for export
        let targetSize = CGSize(width: 200, height: 200)  // Reduced to 1/4 of original 300x300
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact

        let group = DispatchGroup()

        for (day, asset) in photosByDay {
            group.enter()
            imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
                // Only process final high-quality image, not degraded versions
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if let image = image, !isDegraded {
                    thumbnails[day] = self.forceCropToSquare(image: image)
                }
                if !isDegraded {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion(thumbnails)
        }
    }

    private func forceCropToSquare(image: UIImage) -> UIImage {
        // Ensure square crop by using UIGraphicsImageRenderer
        let minDimension = min(image.size.width, image.size.height)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: minDimension, height: minDimension))

        return renderer.image { context in
            // Calculate offset to center the crop
            let x = (image.size.width - minDimension) / 2
            let y = (image.size.height - minDimension) / 2

            // Draw the image offset so the center square fills the canvas
            image.draw(at: CGPoint(x: -x, y: -y))
        }
    }

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

    private func saveImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                self.isSaving = false
                if success {
                    self.showSaveSuccessAlert = true
                } else if let error = error {
                    print("Error saving image: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    CalendarPhotoView()
}

// Full screen image view
struct FullScreenImageView: View {
    let asset: PHAsset
    let day: Int
    let monthName: String
    let year: Int
    let onDismiss: () -> Void

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showDeleteConfirm = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value.magnification
                                    scale = min(max(newScale, 1.0), 5.0)
                                }
                                .onEnded { value in
                                    lastScale = scale
                                    if scale <= 1.0 {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            scale = 1.0
                                            lastScale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            if scale > 1.0 {
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                        }
                                        .onEnded { value in
                                            lastOffset = offset
                                        }
                                )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 3.0
                                    lastScale = 3.0
                                }
                            }
                        }
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }

                // Top bar: back button and delete button
                VStack {
                    HStack {
                        Button(action: { onDismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("返回")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(20)
                        }

                        Spacer()

                        Button(action: { showDeleteConfirm = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, geometry.safeAreaInsets.top + 20)
                    Spacer()
                }

                // Date info
                VStack {
                    Spacer()
                    Text("\(String(format: "%d", year))年 \(monthName) \(day)日")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                }
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            loadFullImage()
        }
        .alert("删除照片", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                deletePhoto()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要从系统相册中删除这张照片吗？此操作不可撤销。")
        }
    }

    private func loadFullImage() {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        let targetSize = PHImageManagerMaximumSize
        let imageManager = PHImageManager.default()

        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { result, info in
            DispatchQueue.main.async {
                self.image = result
                self.isLoading = false
            }
        }
    }

    private func deletePhoto() {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    onDismiss()
                } else if let error = error {
                    print("Error deleting photo: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Exportable calendar view for generating image
struct ExportableCalendarView: View {
    let year: Int
    let month: Int
    let monthName: String
    let thumbnailImages: [Int: UIImage]
    let cityInfo: [(city: String, count: Int)]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("\(String(format: "%d", year))年 \(monthName)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .center)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["周一", "周二", "周三", "周四", "周五", "周六", "周日"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(white: 0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<totalCells, id: \.self) { index in
                    exportCell(for: index)
                }
            }

            // Location info section
            if !cityInfo.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("拍摄地点")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.black)

                    if cityInfo.count == 1 {
                        let info = cityInfo[0]
                        HStack(spacing: 8) {
                            Text("📍")
                                .font(.system(size: 18))
                            Text(info.city)
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                            Text("(\(info.count))")
                                .font(.system(size: 18))
                                .foregroundColor(Color(white: 0.4))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            // Left column
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(cityInfo.enumerated()), id: \.offset) { index, info in
                                    if index % 2 == 0 {
                                        HStack(spacing: 8) {
                                            Text("📍")
                                                .font(.system(size: 18))
                                            Text(info.city)
                                                .font(.system(size: 20))
                                                .foregroundColor(.black)
                                            Text("(\(info.count))")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color(white: 0.4))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.blue.opacity(0.05))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Right column
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(cityInfo.enumerated()), id: \.offset) { index, info in
                                    if index % 2 == 1 {
                                        HStack(spacing: 8) {
                                            Text("📍")
                                                .font(.system(size: 18))
                                            Text(info.city)
                                                .font(.system(size: 20))
                                                .foregroundColor(.black)
                                            Text("(\(info.count))")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color(white: 0.4))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.blue.opacity(0.05))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(24)
        .background(Color.white)
    }

    private var monthInfo: (firstWeekday: Int, totalDays: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2  // Monday is the first day

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

    private var totalCells: Int {
        let (firstWeekday, totalDays) = monthInfo
        return firstWeekday - 1 + totalDays
    }

    private func exportCell(for index: Int) -> some View {
        let day = index - (monthInfo.firstWeekday - 1) + 1
        let isValidDay = day >= 1 && day <= monthInfo.totalDays

        return ZStack(alignment: .topLeading) {
            // White background for all cells
            Rectangle()
                .fill(Color.white)

            if isValidDay {
                if let thumbnail = thumbnailImages[day] {
                    // Thumbnail with padding to make it smaller
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .padding(4)  // Make image slightly smaller
                        .clipped()
                }

                // Day number overlay - always top left
                Text("\(day)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(thumbnailImages[day] != nil ? .white : .black)
                    .shadow(color: .black.opacity(thumbnailImages[day] != nil ? 0.5 : 0), radius: 1, x: 0, y: 0.5)
                    .padding(4)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }
}
