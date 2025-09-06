// PreviousBookingsView.swift
// DEFENDO-AI

import SwiftUI

struct PreviousBookingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var bookings: [BookingData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedBooking: BookingData?

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                if isLoading {
                    ProgressView("Loading...")
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.red)
                        Text(errorMessage).foregroundColor(.red).multilineTextAlignment(.center)
                        Button("Retry") { fetchBookings() }.buttonStyle(PrimaryButtonStyle())
                    }
                } else if bookings.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath").font(.largeTitle).foregroundColor(.gray)
                        Text("No previous bookings found.").foregroundColor(.secondary)
                    }
                } else {
                    List(bookings) { booking in
                        Button {
                            selectedBooking = booking
                        } label: {
                            BookingRowView(booking: booking)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Bookings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear(perform: fetchBookings)
            .sheet(item: $selectedBooking) { booking in
                BookingDetailSheet(booking: booking)
            }
        }
    }

    private func fetchBookings() {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "Not logged in."
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let items = try await SupabaseService.shared.getBookings(userId: userId)
                await MainActor.run {
                    bookings = items.sorted { $0.startTime > $1.startTime }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load bookings. Please try again."
                    isLoading = false
                }
            }
        }
    }
}

struct BookingRowView: View {
    let booking: BookingData
    var body: some View {
        HStack {
            Image(systemName: booking.serviceType == .securityGuard ? "shield.lefthalf.fill" : "person.fill.checkmark")
                .foregroundColor(.blue)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.serviceType.rawValue).font(.headline)
                Text(booking.date.formatted(date: .long, time: .omitted) + ", " + booking.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Status: \(booking.status.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundColor(booking.status == .pending ? .orange : .green)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

private struct BookingDetailSheet: View {
    let booking: BookingData
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: booking.serviceType == .securityGuard ? "shield.lefthalf.fill" : "person.fill.checkmark")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text(booking.serviceType.rawValue).font(.title2).fontWeight(.bold)
                        Text("\(booking.date.formatted(date: .long, time: .omitted)) at \(booking.startTime.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Divider()
                Group {
                    detailRow(label: "Duration", value: "\(booking.durationHours) hour\(booking.durationHours == 1 ? "" : "s")")
                    detailRow(label: "Location", value: booking.location)
                    if let notes = booking.userNotes, !notes.isEmpty {
                        detailRow(label: "Instructions", value: notes)
                    }
                    Divider()
                    detailRow(label: "Provider", value: booking.providerId)
                    detailRow(label: "Status", value: booking.status.rawValue.capitalized)
                    detailRow(label: "Total", value: String(format: "$%.2f", booking.price))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                  .fill(Color(UIColor.secondarySystemBackground))
                  .shadow(radius: 5)
            )
            .padding()
            Spacer()
            Button("Close") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
        }
        .interactiveDismissDisabled(false)
    }
    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

