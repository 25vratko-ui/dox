# Dox – architektúra

Natívna macOS appka (macOS 14+, Swift 5.10, SwiftUI + AppKit), postavená ako Swift Package.
Nie je to kópia žiadnej existujúcej appky: vlastný názov, dizajn aj ikony (SF Symbols).

```
Sources/
  DoxCore/            čistý model a logika (bez AppKit) – testovateľné
    Primitives.swift  RGBAColor, DockEdge, EdgeAlignment, DisplayTarget, KeyShortcut, clamped()
    Appearance.swift  DockAppearance (všetky vizuálne parametre) + enumy
    Dock.swift        DockItem/DockItemKind, DockCategory, DockBehavior, DockLayoutStyle, DockConfig
    Config.swift      ThemePreset, BuiltInThemes (7 tém), AppConfig (+ starter config)
    Operations.swift  mutácie docku (add/move/remove item & category, duplicate, search)
    Geometry.swift    DockGeometry – magnifikácia, veľkosť docku, umiestnenie na obrazovke
    ConfigStore.swift JSON perzistencia, záloha, import/export
  Dox/
    App/              vstup appky, AppDelegate, menu bar, DoxStore (zdroj pravdy)
    Services/         AppKit služby: panely, hotkeys, ikony, bežiace appky, spúšťanie, login item
    Design/           design tokeny a znovupoužiteľné komponenty (ui-designer)
    DockUI/           SwiftUI view samotného docku (swiftui-developer)
    Settings/         okno nastavení (swiftui-developer)
Tests/DoxCoreTests/   XCTest pre DoxCore (xctest-pro)
scripts/bundle.sh     zabalí release binárku do Dox.app (LSUIElement, ad-hoc podpis)
```

## Kontrakty medzi vrstvami (MUSIA sa dodržať)

### DoxStore (`App/DoxStore.swift`) – hotové
`@MainActor @Observable final class DoxStore`, singleton `DoxStore.shared`.
- `config: AppConfig` (read-only), `hiddenDockIDs: Set<UUID>`, `selectedDockID: UUID?`
- `update { (inout AppConfig) }`, `updateDock(id) { (inout DockConfig) }`, `dock(id) -> DockConfig?`
- `binding(dock: id, \DockConfig.appearance.iconSize) -> Binding<T>`, `binding(\AppConfig.launchAtLogin)`
- `addDock(edge:)`, `duplicateDock(_:)`, `removeDock(_:)`, `toggleVisibility(of:)`, `toggleAllDocks()`
- `saveCurrentAppearanceAsTheme(dock:name:)`, `deleteTheme(_:)`, `replaceConfig(_:)`, `saveNow()`
- `onChange: [(AppConfig) -> Void]` – volá sa po každej zmene

### Services (swift-expert) – `Sources/Dox/Services/`
- `DockManager` (`@MainActor final class`, `static let shared`): `start()` – vytvorí jeden `DockPanelController`
  na dock (a na každý displej pri `DisplayTarget.all`), registruje sa do `DoxStore.onChange`, reaguje na zmenu
  displejov (`NSApplication.didChangeScreenParametersNotification`). `reveal(dockID:)`, `hide(dockID:)`.
- `DockPanelController`: vlastní `DockPanel: NSPanel` (borderless, nonactivating, `.floating`/`.normal` level podľa
  `alwaysOnTop`, `canJoinAllSpaces`/`fullScreenAuxiliary`, transparentné pozadie, bez tieňa okna). Hostí
  `NSHostingView(rootView: DockRootView(dockID:screenID:))`. Veľkosť a pozíciu počíta cez `DockGeometry`
  (resting size + headroom pre magnifikáciu na strane odvrátenej od hrany). Auto-hide: posun panelu mimo
  obrazovku s animáciou, odhalenie keď myš stojí `revealDelay` pri hrane (globálny + lokálny NSEvent monitor
  `.mouseMoved`). Skrytie pri fullscreen appke ak `hideInFullScreen`.
- `HotkeyCenter` (`@MainActor`, `shared`): Carbon `RegisterEventHotKey`. `register(_ shortcut: KeyShortcut, id: String, action: @escaping () -> Void)`,
  `unregisterAll()`. Pri zmene configu sa preregistruje: toggleAll, settings, per-dock skratky.
- `IconProvider` (`@MainActor`, `shared`): `icon(for item: DockItem, size: CGFloat) -> NSImage` s NSCache;
  app/file/folder cez `NSWorkspace.shared.icon(forFile:)`; link → favicon nie, použije SF Symbol (`customSymbol` alebo `globe`).
- `RunningAppsMonitor` (`@MainActor @Observable`, `shared`): `runningBundleIDs: Set<String>`, `activeBundleID: String?`
  z `NSWorkspace` notifikácií.
- `ItemLauncher` (`@MainActor enum`): `open(_ item: DockItem, behavior: DockBehavior, alternate: Bool)`,
  `revealInFinder(_:)`, `openWith...` nie. Pre app použije `NSWorkspace.openApplication(at:configuration:)`.
- `FolderContents` (`enum`): `items(in path: String, sort: FolderSort, limit: Int) -> [URL]` (bez skrytých súborov).
- `LoginItem` (`enum`): `isEnabled`, `setEnabled(_:)` cez `SMAppService.mainApp`.
- `ShortcutRecorderView` je v Settings, ale prekladová tabuľka keyCode→label je v `Services/KeyCodes.swift`.

### Design (ui-designer) – `Sources/Dox/Design/`
- `extension Color { init(_ rgba: RGBAColor) }`, `extension RGBAColor { init(_ color: Color) }` (cez NSColor sRGB)
- `VisualEffectBackground: NSViewRepresentable` (material: DockMaterial, appearance mode) – pre `.solid`/`.clear` bez blur
- `DockBackground: View` – kompletné pozadie docku z `DockAppearance` (materiál, tint, gradient, border, corner radius, tieň)
- `DS` – design tokeny okna nastavení (spacing, radius, typografia, farby) a komponenty:
  `SettingsSection(title:symbol:content)`, `SliderRow(title:value:range:step:unit:)`, `ColorRow(title:color: Binding<RGBAColor>)`,
  `PickerRow`, `ToggleRow`, `SymbolPicker(selection: Binding<String>)`, `ThemeCard(theme:isSelected:)`.
- `DESIGN.md` v roote – vizuálny jazyk.

### DockUI + Settings (swiftui-developer)
- `DockRootView(dockID: UUID, screenID: String?)` – číta `DoxStore.shared`, vykreslí `DockBackground` + obsah podľa
  `layout` (line / grid / shelves), kategórie podľa `categoryHeaderStyle`, `display == .stack` → jedna dlaždica
  s popoverom. Magnifikácia cez `DockGeometry.magnificationScale` z pozície myši (`onContinuousHover`).
  Indikátor bežiacej appky, labely podľa `labelMode`, kontextové menu (Otvoriť, Ukázať vo Finderi, Upraviť, Odstrániť,
  Presunúť do kategórie ▸), drag & drop súborov/appiek/URL z Findera do kategórie (`.onDrop`), preusporiadanie ťahaním.
  Priečinok → popover so `FolderStackView` (grid/list/fan).
- Settings okno (`SettingsRootView`): `NavigationSplitView` – sidebar so zoznamom dockov (+ pridať / duplikovať / zmazať)
  a sekcie Všeobecné, Skratky, Témy. Detail docku má taby: **Obsah** (kategórie + položky, editor položky),
  **Vzhľad** (všetky parametre `DockAppearance` + témy), **Rozloženie** (hrana, layout, zarovnanie, offset, displej),
  **Správanie** (auto-hide, oneskorenia, klik, spaces, fullscreen), **Skratka**. Živý náhľad docku hore.
