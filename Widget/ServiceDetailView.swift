// ServiceDetailView.swift
// DEFENDO-AI

import SwiftUI

struct ServiceDetailView: View {
    let service: HostService
    let onBook: ((HostService) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Images Banner
                if let images = service.images, !images.isEmpty, let url = URL(string: images[0]) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.gray.opacity(0.18)
                                .frame(height: 240)
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                                .frame(height: 240)
                                .clipped()
                        case .failure:
                            Color.gray.opacity(0.18)
                                .frame(height: 240)
                        @unknown default:
                            Color.gray.opacity(0.18)
                                .frame(height: 240)
                        }
                    }
                    .frame(height: 240)
                    .cornerRadius(0)
                } else {
                    ZStack {
                        Color.gray.opacity(0.18)
                            .frame(height: 180)
                        Image(systemName: "photo")
                            .font(.system(size: 64))
                            .foregroundColor(.gray.opacity(0.55))
                    }
                }
                VStack(alignment: .leading, spacing: 16) {
                    // Title, price, city
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(service.service_name)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            if let city = service.city, !city.isEmpty {
                                Text(city)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(priceString)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            if let rating = service.rating {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(String(format: "%.1f", rating))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    // Tags
                    if let tags = tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.11))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    // Description
                    if let description = service.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.top, 10)
                    }
                    // Specialization, etc.
                    detailsSection
                }
                .padding()
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) {
            VStack {
                Button(action: {
                    onBook?(service)
                }) {
                    Text("Book Now")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(radius: 3, y: 2)
                }
                .padding([.horizontal, .bottom])
            }
            .background(.ultraThinMaterial)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var priceString: String {
        if let price = service.price, let currency = service.currency {
            return "\(currency)\(String(format: "%.2f", price))"
        } else if let price = service.price_per_hour, let currency = service.currency {
            return "\(currency)\(String(format: "%.2f", price))/hr"
        } else {
            return "--"
        }
    }

    private var tags: [String]? {
        if let specializations = service.specializations, !specializations.isEmpty {
            return specializations
        } else if let type = service.service_type {
            return [type]
        } else {
            return nil
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let equip = service.equipment_included, !equip.isEmpty {
                HStack(alignment: .top) {
                    Text("Equipment Included:")
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(equip.joined(separator: ", "))
                        .font(.body)
                }
            }
            if let bookings = service.total_bookings {
                HStack {
                    Text("Total Bookings:")
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text("\(bookings)")
                }
            }
            if let isActive = service.is_active {
                HStack {
                    Text("Status:")
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(isActive ? "Available" : "Unavailable")
                        .foregroundColor(isActive ? .green : .red)
                }
            }
        }
    }
}

// Preview
#if DEBUG
#Preview {
    ServiceDetailView(service: HostService(
        id: "1",
        service_name: "Elite Security Services",
        price: 25.0,
        price_per_hour: 25.0,
        currency: "$",
        rating: 4.8,
        city: "San Francisco",
        service_type: "Guards",
        description: "Professional guards for all kinds of events.",
        specializations: ["Night Patrol", "Event Guard"],
        equipment_included: ["Radio", "Uniform"],
        images: ["https://via.placeholder.com/600x240"],
        is_active: true,
        total_bookings: 32
    ), onBook: { _ in })
}
#endif
