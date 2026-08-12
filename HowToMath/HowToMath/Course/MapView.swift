//
//  MapView.swift
//  HowToMath
//

import SwiftUI

/// The home screen: the course as a path you walk down.
///
/// Stages alternate left and right rather than sitting in a column, which is the
/// whole reason a trail reads as a journey instead of a list — the eye has to
/// travel to find the next one. Only one stage is ever open, so there is never a
/// decision to make, only a next thing to do.
struct MapView: View {

    @State private var progress = CourseProgress()
    @State private var playing: Stage?
    @State private var showingLab = LabLaunch.requested

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header

                    ForEach(Array(Curriculum.stages.enumerated()), id: \.element.id) { index, stage in
                        if index == 0 || Curriculum.stages[index - 1].section != stage.section {
                            sectionHeader(stage.section)
                        }

                        node(stage, index: index)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .fullScreenCover(isPresented: $showingLab) { CharacterLab() }
        .fullScreenCover(item: $playing) { stage in
            LessonView(stage: stage) { completed in
                if completed { progress.complete(stage) }
                playing = nil
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("HowToMath")
                .font(Theme.label(28, .heavy))
                .foregroundStyle(Theme.text)

            Text("\(progress.completed.count) de \(Curriculum.stages.count) fases")
                .font(Theme.label(15, .bold))
                .foregroundStyle(Theme.dim)

            // Scratch door for looking at the character on its own.
            Button("VER PERSONAGEM") { showingLab = true }
                .font(Theme.label(12, .heavy))
                .foregroundStyle(Theme.dim)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.line).frame(height: 2)
            Text(title.uppercased())
                .font(Theme.label(13, .heavy))
                .tracking(1.2)
                .foregroundStyle(Theme.dim)
            Rectangle().fill(Theme.line).frame(height: 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 14)
    }

    private func node(_ stage: Stage, index: Int) -> some View {
        let unlocked = progress.isUnlocked(stage)
        let done = progress.isCompleted(stage)
        // A gentle zig-zag, tighter than a full-width swing so the trail still
        // reads as one path rather than two columns.
        let lean: CGFloat = [0, 64, 0, -64][index % 4]

        return Button {
            playing = stage
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(done ? Theme.green : (unlocked ? Theme.pale : Theme.track))
                        .frame(width: 74, height: 74)
                        .overlay(
                            Circle().strokeBorder(
                                done ? Theme.greenEdge : (unlocked ? Theme.green : .clear),
                                lineWidth: 4
                            )
                        )
                        .shadow(color: .black.opacity(unlocked ? 0.10 : 0), radius: 6, y: 4)

                    Image(systemName: done ? "star.fill" : (unlocked ? "play.fill" : "lock.fill"))
                        .font(.system(size: done ? 28 : 24, weight: .black))
                        .foregroundStyle(done ? .white : (unlocked ? Theme.greenEdge : Theme.dim))
                }

                Text(stage.title)
                    .font(Theme.label(14, .bold))
                    .foregroundStyle(unlocked ? Theme.text : Theme.dim)
            }
            .offset(x: lean)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .padding(.vertical, 12)
    }
}

#Preview {
    MapView()
}
