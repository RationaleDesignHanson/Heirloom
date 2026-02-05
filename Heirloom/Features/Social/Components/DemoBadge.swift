//
//  DemoBadge.swift
//  Heirloom
//
//  Small "DEMO" capsule badge for demo users.
//  Styled in sage color to match social features.
//

import SwiftUI

/// Small badge indicating a demo/test user
struct DemoBadge: View {
    var body: some View {
        Text("DEMO")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(HeirloomColors.sage)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        DemoBadge()

        HStack {
            Text("Grandmazing")
                .font(HeirloomFonts.bodyBold)
            DemoBadge()
        }
    }
    .padding()
}
