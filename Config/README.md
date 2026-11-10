# Config

Build configuration files referenced by `Unhook.xcodeproj` (kept out of the synchronized `Unhook/` and
`UnhookWidgets/` folders so Xcode doesn't copy them into the app as resources).

- `Unhook.entitlements`, `UnhookWidgets.entitlements`: the App Group (`group.$(UNHOOK_BUNDLE_PREFIX)`) that lets
  the widgets read the app's data. Applied to Simulator builds and Release builds. Debug builds for a real
  device leave it out, because a free Apple ID (Personal Team) can't use App Groups; widgets then show a
  "start your first streak" placeholder.
- `Unhook-Info.plist`: extra Info.plist keys merged with the generated ones (the `unhook://` URL scheme used by
  widget taps).
- `UnhookWidgets-Info.plist`: the widget extension point.
