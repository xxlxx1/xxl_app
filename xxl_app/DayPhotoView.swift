//
//  DayPhotoView.swift
//  xxl_app
//
//  Created by Ducc on 2025-02-13.
//

import SwiftUI
import Photos

struct DayPhotoView: View {
    let day: Int
    let photoManager: PhotoAlbumManager
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
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(hasPhoto ? .white : .black)
                .shadow(color: .black.opacity(hasPhoto ? 0.5 : 0), radius: hasPhoto ? 2 : 0, x: 0, y: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(3)
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: photoManager.photosByDay) { _, _ in
            loadImage()
        }
    }

    private func loadImage() {
        guard !isLoading else { return }
        isLoading = true

        // Store current day to validate callback when it returns
        let requestedDay = self.day

        // Check if there's a photo for this day
        let hasPhotoForDay = photoManager.photosByDay[day] != nil

        if hasPhotoForDay {
            photoManager.loadImage(for: day, size: size) { loadedImage in
                // Only update if we're still requesting the same day
                if self.day == requestedDay {
                    self.image = loadedImage
                    self.currentAsset = self.photoManager.photosByDay[day]
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
    DayPhotoView(day: 15, photoManager: PhotoAlbumManager(), size: CGSize(width: 100, height: 100))
}
