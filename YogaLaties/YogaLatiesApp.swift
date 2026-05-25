//
//  YogaLatiesApp.swift
//  YogaLaties
//
//  Created by Brandi Cantarel on 5/9/26.
//

import SwiftUI
import SwiftData
import AVFoundation

// CGI ANALOGY: `.modelContainer` is the **production vault** — the on-disk
// database file that stores every Routine and RoutineExercise the user creates.
// Attaching it to the WindowGroup is like mounting the shared NAS drive at
// startup: every view in the app can now read from and write to it via the
// environment, without needing a direct reference to the vault itself.
//
// SwiftData creates the SQLite file automatically the first time the app runs
// and migrates the schema when you add or change @Model properties later.

@main
struct YogaLatiesApp: App {

    // CoachSettings is owned here at the top of the app and injected into
    // the SwiftUI environment so every view can access it with:
    //   @Environment(CoachSettings.self) private var settings
    //
    // CGI ANALOGY: This is the "Project Preferences" object. It lives at the
    // root of the node graph (the App), and every downstream node (view) in
    // the pipeline can read from it via the environment — like global variables
    // in a Houdini .hip file that every node can read without a direct wire.
    //
    // Why @State here and not a plain `let`?
    // @State on an @Observable object tells SwiftUI "own this for the lifetime
    // of the App struct". A plain `let` would work too for a class (reference
    // type), but @State is the idiomatic iOS 17 pattern and makes the intent
    // explicit. Either way, only one instance is ever created.
    @State private var coachSettings = CoachSettings()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                // Inject CoachSettings into the environment tree.
                // Any view below MainTabView can now read it with
                // @Environment(CoachSettings.self).
                //
                // CGI ANALOGY: Publishing a global channel in Houdini — once
                // it's published at the scene root, any downstream node can
                // subscribe to it by name without a direct connection wire.
                .environment(coachSettings)
                .task {
                    // Request permission to use Personal Voice (iOS 17+).
                    // Personal Voice is the user-recorded synthetic voice from
                    // Settings → Accessibility → Personal Voice. Without this
                    // request, iOS hides personal voices from speechVoices()
                    // entirely — they simply don't appear in the list.
                    // The system shows a one-time permission prompt; after the
                    // user approves, personal voices become available immediately.
                    //
                    // CGI ANALOGY: Like requesting access to a locked asset
                    // library — until the studio grants permission, the render
                    // farm can't even see those files exist.
                    if #available(iOS 17, *) {
                        await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
                    }
                }
        }
        // Register both @Model types so SwiftData knows their full schema.
        .modelContainer(for: [Routine.self, RoutineExercise.self])
    }
}
