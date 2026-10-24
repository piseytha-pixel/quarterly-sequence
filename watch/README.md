# QS Arcana for Apple Watch

Watch app (7 Arcana dials, alerts) + complications for Apple's watch faces.

1. Open `ArcanaWatch.xcodeproj` in Xcode 15 or newer.
2. Select the **ArcanaWatch** target → Signing & Capabilities → choose your Team (your Apple ID). Do the same for **ArcanaWidgets**.
   If Xcode says the bundle ID is taken, change `com.quartersequence.arcana.watch` to something unique (keep `.widgets` on the widget).
3. Pick your Apple Watch as the run destination (iPhone paired, both in Developer Mode) and press Run.
4. On the watch: long-press the face → Edit → Complications → **Arcana**.

`Tests/` checks the prediction against Arcana: `swiftc Shared/Arc.swift Tests/main.swift -o arctest && ./arctest Tests/vectors.json`
