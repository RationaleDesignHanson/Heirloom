//
//  ConnectionRequestCard.swift
//  Heirloom
//
//  Social Layer Phase 6: Card showing a connection request
//  With accept/decline actions and type picker
//

import SwiftUI

struct ConnectionRequestCard: View {
    let request: Connection
    let isProcessing: Bool
    let onAccept: () async -> Void
    let onDecline: () async -> Void

    var body: some View {
        VStack(spacing: HeirloomSpacing.md) {
            // Header with avatar and name
            HStack(spacing: HeirloomSpacing.sm) {
                avatarView
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.connectedUserDisplayName)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    if let handle = request.connectedUserHandle {
                        Text("@\(handle)")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                Spacer()
            }

            // Kitchen Table context
            if request.sourceKitchenTableId != nil {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "fork.knife")
                        .font(.caption2)
                    Text("From Kitchen Table")
                        .font(HeirloomFonts.caption2)
                }
                .foregroundStyle(HeirloomColors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Private note if available
            if let note = request.privateNote {
                Text(note)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Action buttons
            HStack(spacing: HeirloomSpacing.sm) {
                // Decline button
                Button {
                    Task {
                        await onDecline()
                    }
                } label: {
                    Text("Decline")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HeirloomSpacing.sm)
                        .background(HeirloomColors.warmGray.opacity(0.1))
                        .cornerRadius(10)
                }
                .disabled(isProcessing)

                // Accept button
                Button {
                    Task {
                        await onAccept()
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Accept")
                        }
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HeirloomSpacing.sm)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(10)
                }
                .disabled(isProcessing)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        if let photoURL = request.connectedUserPhotoURL,
           let url = URL(string: photoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    placeholderAvatar
                @unknown default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.tomato.opacity(0.8),
                        HeirloomColors.tomato.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(initials)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let name = request.connectedUserDisplayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[components.count - 1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else {
            return String(name.prefix(1)).uppercased()
        }
    }
}

#Preview {
    VStack {
        ConnectionRequestCard(
            request: Connection(
                id: "preview",
                userId: "user1",
                connectedUserId: "user2",
                connectedUserDisplayName: "Chef Julia",
                connectedUserPhotoURL: nil,
                status: .pending,
                initiatedBy: "user2",
                requestedAt: Date(),
                acceptedAt: nil,
                sourceKitchenTableId: "table1",
                recipesSharedCount: 0,
                recipesReceivedCount: 0,
                isFavorite: false,
                privateNote: "Met at cooking class",
                createdAt: Date(),
                updatedAt: Date()
            ),
            isProcessing: false,
            onAccept: {},
            onDecline: {}
        )
    }
    .padding()
    .background(HeirloomColors.appBackground)
}
