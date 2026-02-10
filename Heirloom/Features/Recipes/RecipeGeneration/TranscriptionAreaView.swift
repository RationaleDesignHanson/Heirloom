//
//  TranscriptionAreaView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-10.
//

import SwiftUI

/// Full-height scrolling transcription display — the visual centerpiece of the voice dictation screen
struct TranscriptionAreaView: View {
    let text: String
    let isRecording: Bool

    @State private var cursorVisible: Bool = true

    private var wordCount: Int {
        text.split(separator: " ").count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if text.isEmpty {
                emptyState
            } else {
                transcriptionContent
            }

            // Word count overlay
            if !text.isEmpty {
                Text("\(wordCount) words")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.warmGray)
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HeirloomSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(HeirloomColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 0)
        )
        .heirloomShadow(HeirloomShadows.card)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Tap the mic and start reading your recipe aloud...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.warmGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Transcription Content

    private var transcriptionContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                HStack(spacing: 0) {
                    Text(text)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Blinking cursor when recording
                    if isRecording {
                        Text("|")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.tomato)
                            .opacity(cursorVisible ? 1 : 0)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                    cursorVisible = false
                                }
                            }
                            .onDisappear {
                                cursorVisible = true
                            }
                    }

                    Spacer(minLength: 0)
                }

                // Bottom anchor for auto-scroll
                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .onChange(of: text) {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
