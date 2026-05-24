//
//  MainTabView.swift
//  YogaLaties
//
//  The root navigation container for the entire app.
//
//  CGI ANALOGY: Think of MainTabView as the multi-pass renderer compositor —
//  the master node that receives the output of every render pass (Library pass,
//  Routines pass) and lets the user switch between them. Each tab is a completely
//  independent render pipeline; switching tabs is like toggling layer visibility
//  in Nuke, not restarting the whole render.
//
//  SwiftUI keeps each tab's NavigationStack alive in memory while you're on a
//  different tab — just like a compositor caches each layer's rendered frames
//  so you don't have to re-render them every time you toggle visibility.

import SwiftUI

struct MainTabView: View {

    // @State tracks which tab is currently selected.
    // CGI ANALOGY: The "active layer" selector — one integer that tells the
    // compositor which pass to put on top. Change it and the viewport updates
    // instantly, just like clicking a different layer in After Effects.
    @State private var selectedTab: Tab = .library

    // A Swift enum makes the tab choices explicit and type-safe.
    // CGI ANALOGY: Named render passes ("beauty", "shadow", "AO") instead of
    // anonymous integers — self-documenting and impossible to typo.
    enum Tab {
        case library
        case routines
        case settings
    }

    var body: some View {

        // TabView is SwiftUI's built-in tab bar container.
        // CGI ANALOGY: The compositor's layer stack panel — each `.tabItem`
        // is a named layer button at the bottom of the panel.
        TabView(selection: $selectedTab) {

            // ── Tab 1: Exercise Library ──────────────────────────────────
            // ContentView already owns its own NavigationStack, so we drop
            // it in as-is. No re-wrapping needed.
            // CGI ANALOGY: The "Beauty Pass" layer — the main, fully-rendered
            // hero content the user sees first when the app opens.
            ContentView()
                .tabItem {
                    Label("Library", systemImage: "figure.mind.and.body")
                }
                .tag(Tab.library)

            // ── Tab 2: My Routines ───────────────────────────────────────
            // Placeholder for now — will be replaced in Step 11 (Routine Builder).
            // CGI ANALOGY: A "reserved layer" slot — the pass exists in the
            // compositor graph, outputs a grey card today, but the render node
            // behind it will be swapped in during the next production sprint.
            MyRoutinesView()
                .tabItem {
                    Label("My Routines", systemImage: "list.bullet.clipboard")
                }
                .tag(Tab.routines)

            // ── Tab 3: Settings ──────────────────────────────────────────────
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        // Match the tab bar accent to the app's indigo/teal palette.
        .tint(.indigo)
    }
}

#Preview {
    MainTabView()
}
