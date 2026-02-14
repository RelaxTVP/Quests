import SwiftUI

struct LaunchView: View {

    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("QuestsLogo") // usa o asset do logo
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
//
//  LaunchView.swift
//  QuestReminder
//
//  Created by Miguel Carretas on 10/02/2026.
//

