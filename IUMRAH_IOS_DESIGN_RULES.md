# iumrah iOS Design Regulation
## Native iOS 26 Liquid Glass · Product UI Constitution

**File:** `IUMRAH_IOS_DESIGN_RULES.md`  
**Status:** REQUIRED / SOURCE OF TRUTH  
**Scope:** Entire iumrah iOS client application  
**Minimum deployment target:** iOS 17  
**Primary design target:** iOS 26+  
**Last revision:** 2026-09-05

---

# 0. Purpose

This document is the visual and interaction constitution of the iumrah iOS application.

Every existing screen, every new screen, every redesign, and every reusable component MUST follow this document unless a product requirement explicitly overrides it.

The goal is not to make individual screens “beautiful” in isolation. The goal is to make the entire application feel as if it was designed and shipped as **one native Apple product**.

The user must never feel that:

- one page belongs to another application;
- one screen was made by a different developer;
- one button uses a different design language;
- some screens use native iOS and others imitate iOS;
- Liquid Glass is manually recreated with blur, opacity, gradients, or custom materials;
- navigation behavior changes from screen to screen.

The application must feel:

> calm, premium, precise, native, fluid, trustworthy, caring, modern, restrained.

iumrah is not a decorative “religious app” UI. It is a premium travel/service product for pilgrims, designed with Apple-native interaction principles.

---

# 1. Non-negotiable rule

## Native first. Always.

When iOS already provides the required behavior or visual component, use the system implementation.

Do NOT recreate:

- navigation back buttons;
- swipe-to-go-back;
- tab bars;
- toolbars;
- menus;
- sheets;
- toggles;
- segmented controls;
- context menus;
- alerts;
- search behavior;
- navigation transitions;
- Liquid Glass;
- pressed-state physics;
- focus behavior;
- Dynamic Type behavior.

Custom UI is justified only when iumrah has a product-specific interaction that iOS does not provide.

---

# 2. Liquid Glass policy

## 2.1 iOS 26+

On iOS 26+, Liquid Glass MUST use native Apple SwiftUI APIs.

Canonical APIs include:

```swift
.glassEffect()
.glassEffect(_:in:)
GlassEffectContainer
.glassEffectID(_:in:)
.glassEffectTransition(_:)
.buttonStyle(.glass)
.buttonStyle(.glassProminent)
```

Interactive custom glass should use the native interactive Glass configuration when appropriate.

### Forbidden on iOS 26 for UI chrome

Do NOT imitate Liquid Glass using:

```swift
.ultraThinMaterial
.thinMaterial
.regularMaterial
.blur(...)
UIBlurEffect
UIVisualEffectView
custom gradient + opacity + stroke
custom translucent white overlays
```

These techniques must not be used as a substitute for native Liquid Glass.

A decorative blur in artwork, glow, voice visualization, background photography, or cinematic effect is allowed because it is **content**, not UI chrome.

## 2.2 iOS 17–25 fallback

Older iOS versions must receive a clean, functional fallback.

Fallback rules:

- standard SwiftUI surfaces;
- semantic system colors;
- system controls;
- normal opacity only when required for hierarchy;
- no fake Liquid Glass;
- no attempt to reproduce iOS 26 refraction manually.

Bad:

```swift
if #available(iOS 26, *) {
    content.glassEffect()
} else {
    content.background(.ultraThinMaterial)
}
```

Preferred principle:

```swift
if #available(iOS 26, *) {
    // Native Liquid Glass
} else {
    // Clean standard iOS surface
}
```

The fallback should look like a well-designed iOS 17–18 application, not like an imitation of iOS 26.

---

# 3. One design system only

There must be exactly **one canonical design system**.

Do not create screen-local versions of:

- GlassIconButton
- GlassCard
- GlassSearchField
- PrimaryButton
- SecondaryButton
- AppCard
- SectionHeader
- StatusPill
- FormField
- SheetHeader
- FloatingActionButton

If a screen needs a variant, extend the central component rather than cloning it.

Recommended architecture:

```text
Sources/
  Core/
    DesignSystem.swift
    Components/
      IumrahButton.swift
      IumrahGlass.swift
      IumrahCard.swift
      IumrahField.swift
      IumrahSection.swift
      IumrahStatus.swift
```

Screen files must consume these primitives. They should not invent a parallel style.

---

# 4. Product character

iumrah UI must communicate four ideas simultaneously.

### 1. Care
The product accompanies a pilgrim rather than merely selling a booking.

### 2. Control
The user always understands what is happening, what is next, and what action is available.

### 3. Premium restraint
Premium means precision and calm, not excessive gradients, shadows, glass, animation, or decoration.

### 4. Native confidence
The app should feel like it belongs on iPhone.

No visual gimmick should be stronger than the content.

---

# 5. Structural hierarchy

Every screen should be built from the same hierarchy:

```text
System background
    ↓
Page content
    ↓
Sections
    ↓
Content surfaces/cards
    ↓
Interactive controls
    ↓
System navigation / toolbar / sheet chrome
```

Do not randomly place translucent surfaces on top of other translucent surfaces.

Avoid “glass inside glass inside glass”.

Liquid Glass is primarily for:

- navigation;
- toolbars;
- floating controls;
- interactive controls;
- compact action groups;
- important overlay actions;
- Apple-style system chrome.

Regular content cards should usually remain calm solid/adaptive surfaces. This preserves hierarchy and prevents visual noise.

Implementation rule for the shared helper:

- `iumrahGlass(..., interactive: true)` is for actual controls;
- `allowsStaticGlass: true` is reserved for intentionally floating chrome/status surfaces;
- ordinary static content must not opt into `allowsStaticGlass`; it resolves to an adaptive solid content surface instead;
- never set `allowsStaticGlass: true` simply to make a card look more expensive.

---

# 6. Navigation — absolute rule

Navigation behavior must be native.

## 6.1 Push navigation

Use:

```swift
NavigationStack
NavigationLink
navigationDestination
```

A pushed page must preserve the system Back behavior.

### Forbidden

Do NOT use this pattern as a replacement for navigation:

```swift
Button {
    dismiss()
} label: {
    Image(systemName: "chevron.left")
}
```

Do NOT hide the native Back button on a normal pushed screen:

```swift
.navigationBarBackButtonHidden(true)
```

Do NOT hide the navigation bar on a pushed screen merely to draw a custom header.

The native back item also carries native interaction behavior, transition behavior, accessibility behavior, and the iOS edge swipe-to-pop gesture.

### Requirement

**Swipe from the left edge to go back must work on every normal pushed screen.**

## 6.2 Exception: previous step is not navigation back

A `chevron.left` is allowed when it means:

- previous ritual step;
- previous onboarding step;
- previous wizard page;
- previous media item.

In this case it is a domain action, not a navigation Back replacement. The difference must remain explicit in code.

---

# 7. Tab bar

The main app uses native `TabView`.

On iOS 26, allow Apple to render the system Liquid Glass tab bar.

Do not paint a custom opaque/translucent plate behind the tab bar.

Do not rebuild a system tab bar manually unless a product requirement makes native TabView impossible.

Tab icon rules:

- SF Symbols;
- consistent symbol family;
- concise labels;
- no custom circle behind every icon;
- selected state controlled by the system.

---

# 8. Toolbars

Toolbar actions must use native toolbar placement.

Prefer:

```swift
.toolbar {
    ToolbarItem(...)
}
```

Do not manually position top-right buttons using `ZStack` coordinates when a toolbar can do the job.

System toolbar grouping should be preserved on iOS 26.

Use glass tint/prominence only when action hierarchy requires it.

---

# 9. Icons

## Default icon source

Use **SF Symbols** for product/system actions.

Examples:

```text
xmark
ellipsis
square.and.arrow.up
heart
heart.fill
person
magnifyingglass
slider.horizontal.3
plus
checkmark
chevron.right
calendar
location
message
phone
doc
```

Custom assets are reserved for:

- iumrah brand identity;
- airline logos;
- hotel logos;
- payment brands;
- partner/company identity;
- product illustrations.

## Icon consistency

Within one context:

- use one symbol weight;
- use comparable optical scale;
- do not mix thick custom icons with thin SF Symbols;
- do not mix filled and outlined variants randomly.

Recommended action icon size:

```text
17–20 pt visual glyph
44–48 pt minimum interaction surface
```

Touch targets must be at least approximately 44×44 pt.

## Semantic icon color

Content icons MUST use the shared semantic icon language from `DesignSystem.swift`; do not choose arbitrary colors screen by screen. Color is an information cue, not decoration.

Canonical families:

```text
travel / flights       system blue
hotels                 system indigo
booking                system orange
Umrah / guidance       system teal
Care                    system pink
profile / people       system cyan
phone / security       system green
mail / language        system blue
location / alerts      system red
appearance             system purple
documents              system cyan
payment / success      system green
warning                 system orange
destructive             system red
```

Rules:

- use `IumrahIconBadge` for informational icon containers inside cards, settings rows, headers and data rows;
- use `IumrahInlineIcon` for small metadata glyphs where color improves scanning;
- structural glyphs such as chevrons, disclosure arrows and close/back navigation remain neutral unless state requires otherwise;
- never make every icon a different arbitrary color merely for decoration;
- the same semantic meaning must keep the same color family throughout the app;
- informational icon badges are solid/adaptive content, **not Liquid Glass**.

---

# 10. Icon buttons

There is one canonical circular/compact icon button.

### iOS 26+
Use native glass interaction.

### Older iOS
Use a clean adaptive system surface.

Do not create a new custom `Circle().fill(...).overlay(...).shadow(...)` for every screen.

Icon button variants may be:

```text
standard
selected
prominent
destructive
disabled
```

but must originate from the same component.

---

# 11. Buttons

Only these semantic button levels are allowed.

## Primary

For the main action on a screen:

- Continue
- Confirm
- Book
- Pay
- Start Umrah
- Save

On iOS 26 prefer native prominent system treatment such as:

```swift
.buttonStyle(.glassProminent)
```

when appropriate to the context.

A primary CTA does NOT need to be transparent. Prominence is more important than “maximum glass”.

## Secondary

Supporting action:

```swift
.buttonStyle(.glass)
```

on iOS 26 where appropriate.

Examples: Edit, Filters, Details, Change, Add.

## Tertiary

Text/action with minimal chrome.

Examples: Skip, Learn more, Not now.

Do not wrap every tertiary action inside a large glass capsule.

## Destructive

Use semantic destructive roles:

```swift
Button(role: .destructive) { ... }
```

Do not invent random red gradients or oversized danger cards unless the destructive action itself requires a warning surface.

Destructive actions should usually require confirmation when irreversible.

---

# 12. Button geometry

Default values:

```text
Primary CTA height:        54–58 pt
Compact control height:    44–48 pt
Icon control:              44–48 pt
Horizontal button padding: 16–22 pt
```

Button labels:

- concise;
- one clear verb;
- preferably one line;
- no excessive ALL CAPS.

Corner geometry must be consistent.

---

# 13. Corner-radius system

Use only the approved geometry families.

```text
Small control:       14 pt
Regular control:     18 pt
Standard card:       24–28 pt
Large hero surface:  30–32 pt
Pill / status:       Capsule
```

Prefer continuous corners:

```swift
RoundedRectangle(cornerRadius: ..., style: .continuous)
```

Do not introduce radii such as 11, 17, 23, 27, 36, 42 randomly.

A screen should not contain five different corner languages.

---

# 14. Spacing system

Use a 4/8-point rhythm.

Approved common spacing:

```text
4
8
12
16
20
24
32
40
```

Preferred screen horizontal margin: **20 pt**.

Dense screens may use 16 pt when necessary.

Common internal card padding: **16–20 pt**.

Section separation: **24–32 pt**.

Do not use arbitrary values unless optical alignment requires it.

---

# 15. Typography

Use Apple system typography.

Default:

```swift
Font.system(...)
```

For iumrah branded/content UI, rounded system design may be used consistently:

```swift
Font.system(size: ..., weight: ..., design: .rounded)
```

Do not import decorative fonts for normal UI.

Hierarchy:

- Large page title — strong but restrained.
- Section title — semibold/bold, visually below page title.
- Body — readable, regular.
- Secondary — semantic secondary foreground style.
- Caption — only for true metadata.

Do not solve hierarchy only by making everything bold.

---

# 16. Text colors

Use semantic colors.

Preferred:

```swift
.primary
.secondary
.tertiary
Color(uiColor: .systemBackground)
Color(uiColor: .secondarySystemBackground)
Color(uiColor: .tertiarySystemBackground)
```

Avoid fixed gray values for normal text.

Avoid hard-coded black/white where semantic colors can adapt to dark mode.

Brand color may be used to communicate identity, state, selected control, or a meaningful accent. It must not flood the interface.

---

# 17. Content cards

Content cards are not automatically glass.

A hotel card, traveler card, booking block, visa information card, or itinerary card should normally be a calm adaptive content surface.

Rules:

- one standard radius family;
- no strong border by default;
- very restrained shadow if any;
- no gradient merely to make a card “premium”;
- no arbitrary glass treatment on every card.

Use glass when the surface behaves as interactive chrome, floating control, or contextual action layer.

---

# 18. Forms and text fields

All input components must share one field system.

Applies to login, password, passport, phone, email, flight search, promo code, traveler details, payment details, booking details, and search.

Required properties:

- same height family;
- same corner family;
- same typography;
- same focus behavior;
- same error treatment;
- same disabled state;
- same spacing.

Do not let every feature build its own TextField container.

On iOS 26 an interactive glass surface may be used where it matches the native design.

Never fake an iOS 26 field using manual blur.

---

# 19. Search

Prefer native searchable behavior when possible:

```swift
.searchable(...)
```

If a custom search row is required, it must use the central field/search component.

Search icon: `magnifyingglass`.

Clear action should use the system convention.

Do not create a unique search bar on Hotels, Flights, Care, and Booking independently.

---

# 20. Toggles, sliders and pickers

Use system controls:

```swift
Toggle
Slider
Picker
DatePicker
```

unless the product interaction fundamentally requires a custom control.

Do not manually recreate an iOS switch.

---

# 21. Status pills

There must be one status component.

Examples: Pending, Confirmed, Paid, In review, Ready, Cancelled, Active.

Status is communicated by:

1. text;
2. semantic icon where helpful;
3. restrained tint.

Do not communicate state through color alone.

No glass + gradient + stroke + shadow stack.

---

# 22. Sheets and modal presentation

Use native presentation whenever possible:

```swift
.sheet
.fullScreenCover
.confirmationDialog
.alert
.popover
```

On iOS 26, let the system provide its native presentation behavior and Liquid Glass characteristics.

Do not place a fake modal card inside a full-screen `ZStack` when `.sheet` would provide the correct interaction.

Sheet rules:

- native drag behavior;
- native dismissal unless product logic prohibits it;
- clear title;
- one main action;
- safe bottom spacing;
- no custom fake grabber when the system already provides one.

---

# 23. Safe area

The background should visually fill the entire display.

Background layers may use:

```swift
.ignoresSafeArea()
```

when appropriate.

Content and controls must still respect safe areas.

Preferred bottom overlays:

```swift
.safeAreaInset(edge: .bottom) { ... }
```

Do not create visible white/gray “safe-area slabs”.

Do not position buttons with hard-coded device-specific bottom offsets.

Never assume a specific iPhone model.

---

# 24. Scroll behavior

Use `ScrollView`, `List`, or native containers appropriately.

Scroll content should be able to pass naturally beneath floating system chrome on iOS 26 where the system expects it.

Do not place unnecessary opaque backgrounds behind navigation/tab bars.

No nested scroll views unless there is a real interaction requirement.

---

# 25. Motion philosophy

Animation is not decoration.

Every animation must communicate one of:

```text
state changed
object moved
context opened
context closed
selection changed
progress occurred
relationship between two controls
```

The UI must feel fluid but never theatrical.

---

# 26. Animation vocabulary

Preferred SwiftUI curves:

```swift
.smooth
.snappy
.spring
```

### `.snappy`
Use for taps, selection, small control transitions, filters, compact expansions.

### `.smooth`
Use for card state changes, layout transitions, larger calm transitions.

### Spring
Use only when physical response adds meaning. Avoid exaggerated bounce.

---

# 27. Animation duration guidance

Typical interaction timing:

```text
Micro feedback:       ~0.15–0.20 s
Control transition:   ~0.20–0.30 s
Surface transition:   ~0.30–0.45 s
Hero/cinematic:       only when product-specific
```

These are guidance, not reasons to override native system transitions.

If iOS provides the transition, use the iOS transition.

---

# 28. Liquid Glass morphing

When multiple glass objects belong to the same interactive cluster, use:

```swift
GlassEffectContainer
```

When state changes should visually connect two glass surfaces, use native glass identity/transition APIs:

```swift
.glassEffectID(...)
.glassEffectTransition(...)
```

Do not manually fake glass morphing with scale + blur + opacity when native glass transitions can express the relationship.

---

# 29. Haptics

Haptics should confirm meaningful interaction, not every pixel movement.

Approved cases:

- selection change;
- successful confirmation;
- warning;
- error;
- important toggle;
- completion milestone.

Prefer system haptic APIs / `sensoryFeedback` where supported.

Do not fire strong impact feedback on every button.

---

# 30. Loading

Loading state must preserve layout stability.

Preferred order:

1. instant cached data;
2. skeleton/placeholder where useful;
3. compact progress indicator;
4. explicit failure state if needed.

Avoid blank screens with only a spinner.

Do not resize major layouts when loading completes unless necessary.

---

# 31. Empty states

Empty states should be calm and actionable.

Structure:

```text
SF Symbol / simple illustration
Title
One short explanation
Optional primary action
```

Do not fill empty states with marketing copy.

---

# 32. Error states

Errors should explain what the user can do next.

Prefer:

```text
What happened
What it affects
What action is available
```

Never expose raw server strings such as:

```text
UNAUTHORIZED
HTTP 401
INTERNAL_ERROR
JSON parsing failed
```

directly in production UI unless it is a developer/debug build.

Visual error treatment must use semantic iOS styling.

---

# 33. Authentication and backend errors

UI work must never modify authentication behavior merely to “fix appearance”.

Visual redesign and data logic are separate scopes.

A design patch must NOT change:

- token storage;
- Authorization headers;
- API routes;
- request bodies;
- HTTP methods;
- retries;
- session refresh;
- booking mutations;
- database calls;
- backend schemas.

If a UI change appears to require such a change, stop and create a separate engineering task.

---

# 34. UI-only scope firewall

When a task is explicitly cosmetic/design-only, allowed modifications are limited to:

```text
layout
spacing
font
foreground/background styling
system control style
shape
animation
transition
haptic presentation
toolbar presentation
safe-area presentation
DesignSystem components
```

The following are protected unless explicitly requested:

```text
Backend/
API/
Services/
Networking/
State mutation
Authentication
Pricing
Booking logic
PackageEngine
Database
Cloudflare
Payment logic
eSIM provisioning
Analytics contracts
.github/
Signing/
Entitlements
```

Before delivering a UI-only patch, verify the diff.

If protected code changed unintentionally, the patch is NOT ready.

---

# 35. Dark mode

Every reusable component must work in both appearances.

Do not treat dark mode as “black version of the light screen”.

Use semantic system colors and allow system glass to adapt.

Required checks:

- text contrast;
- status colors;
- disabled states;
- selected states;
- cards;
- fields;
- icons;
- image overlays;
- navigation chrome.

No hard-coded white card that becomes unreadable in dark mode unless it is a deliberate branded surface.

A fixed white or black content surface is allowed only when it is intentionally branded **and** every text/icon color inside it is explicitly paired for that surface. Normal content over photography must use the shared adaptive photo-card surfaces so `.primary` / `.secondary` remain readable in both appearances.

Dark-mode acceptance rule:

```text
semantic text + adaptive surface = preferred
fixed surface + semantic text     = forbidden when contrast can invert
fixed branded surface + explicit paired text = allowed
```

The booking home/status area, itinerary cards, account/settings rows, checkout cards and other reusable content must be visually checked in both appearances before release.

---

# 36. Accessibility

Native feel includes accessibility.

Every UI component must support:

- Dynamic Type where practical;
- VoiceOver labels;
- semantic button roles;
- sufficient contrast;
- minimum touch target;
- Reduce Motion;
- system font scaling.

Do not use an icon-only control without an accessibility label.

Avoid fixed-height text cards that clip larger type.

---

# 37. Reduce Motion

When Reduce Motion is enabled:

- remove unnecessary parallax;
- reduce scale transitions;
- avoid large spatial movement;
- preserve state communication through opacity/layout when appropriate.

Core navigation should remain system-managed.

---

# 38. Images and media

Photography can be expressive.

Controls over photography must remain legible.

Use system overlays and native glass controls where appropriate.

Do not add strong permanent dark gradients if placement/system treatment can solve readability more cleanly.

Image animation should never compete with booking/ritual actions.

---

# 39. iumrah brand usage

The brand should appear with restraint.

iumrah identity belongs in:

- logo;
- branded hero moments;
- Care;
- Advisor;
- booking confirmation;
- relevant service products.

Do not place the logo inside every card or every navigation surface.

The experience itself should communicate the brand.

---

# 40. Ritual / Umrah Flow

Umrah Flow can be more atmospheric than transactional booking screens, but it still obeys the same component system.

Allowed:

- cinematic gradient;
- voice visualization;
- controlled ambient motion;
- ritual progress;
- richer emotional presentation.

Still required:

- canonical glass controls;
- canonical typography;
- canonical icon family;
- native navigation behavior;
- consistent CTA hierarchy;
- accessibility;
- no fake Liquid Glass.

A “previous ritual step” button is not the system Back button and must not interfere with `NavigationStack` edge-swipe behavior.

---

# 41. Care / chat

Chat must feel like a native communication surface.

Principles:

- message content comes first;
- input area follows native iOS ergonomics;
- controls are compact;
- glass is used for interactive chrome, not every bubble;
- composer responds to keyboard naturally;
- keyboard safe area must be native;
- send/attachment controls should not drift or resize unpredictably.

Avoid oversized custom buttons around the composer.

---

# 42. Hotels / Flights / Package Generator

Transactional surfaces should prioritize scanning.

Hierarchy:

```text
Search / trip context
Results
Primary price / value
Secondary metadata
Selection
Primary action
```

Do not bury core price/action information under decorative glass.

Filters and selectors may use glass as controls.

Result content itself should remain readable, stable, and restrained.

---

# 43. Booking details

Booking detail screens must feel authoritative.

Priority:

1. status;
2. booking identity;
3. trip details;
4. required user actions;
5. contacts/support;
6. secondary services;
7. destructive actions.

Do not give destructive actions equal prominence to normal booking actions.

Do not expose backend error codes.

---

# 44. Motion in lists

Avoid individually animating every list row on every appearance.

Acceptable:

- subtle insertion;
- selection response;
- state update;
- expansion/collapse.

Avoid repeated staggered “showcase” animations in routine workflows.

Performance and calmness are more important.

---

# 45. Performance rule

Design effects must not degrade scrolling.

Do not stack:

```text
blur
shadow
mask
overlay
gradient
glass
another blur
```

on dozens of repeated cells.

If native `GlassEffectContainer` can group nearby glass elements, prefer it.

No expensive decorative animation should run indefinitely off-screen.

---

# 46. Shadows

Native Liquid Glass usually does not need an additional handmade shadow.

For normal content cards, if a shadow is necessary, keep it extremely restrained.

Do not use shadows to create hierarchy that spacing and surfaces should provide.

No black heavy drop shadows.

---

# 47. Borders

Avoid arbitrary 1 px gray borders around every surface.

Borders are allowed for:

- explicit selection;
- validation;
- accessibility distinction;
- non-glass fallback where required.

Glass surfaces should not receive an extra fake “glass border” unless the system design specifically requires it.

---

# 48. Gradients

Gradients are brand/content tools, not a default control treatment.

Allowed:

- hero;
- Advisor;
- Umrah Flow;
- Care branded surface;
- subtle background atmosphere.

Avoid gradients on:

- standard form fields;
- ordinary icon buttons;
- every card;
- destructive actions;
- navigation chrome.

---

# 49. Component states

Every reusable interactive component must define:

```text
normal
pressed
selected
disabled
loading
error (when relevant)
```

State differences should remain obvious without changing the entire visual language.

Do not invent a new component simply to represent a selected version.

---

# 50. Press feedback

Do not implement arbitrary manual scale effects on every button.

Prefer native system button behavior.

If a custom control requires press feedback:

- subtle;
- fast;
- no exaggerated shrink;
- no bouncing after release unless meaningful.

---

# 51. Copy density

UI language should be concise.

Avoid:

- long paragraphs inside action cards;
- technical server language;
- redundant titles;
- duplicated labels.

The screen should remain visually scannable at a glance.

---

# 52. Screen composition template

A standard screen should generally follow:

```text
Native navigation
↓
Page title / context
↓
Primary section
↓
Secondary sections
↓
Contextual actions
↓
Primary CTA / system toolbar / safe-area action
```

Not every screen needs every level.

But screens should not invent a completely different composition without a product reason.

---

# 53. Canonical SwiftUI patterns

## Native glass button

```swift
if #available(iOS 26.0, *) {
    Button("Continue", action: action)
        .buttonStyle(.glassProminent)
} else {
    Button("Continue", action: action)
        .buttonStyle(.borderedProminent)
}
```

## Custom glass surface

```swift
if #available(iOS 26.0, *) {
    content
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
} else {
    content
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
}
```

The fallback is intentionally not fake glass.

## Grouped glass

```swift
if #available(iOS 26.0, *) {
    GlassEffectContainer(spacing: 12) {
        controls
    }
} else {
    controls
}
```

---

# 54. Anti-pattern list

A pull request / patch must be rejected if it introduces any of these without explicit justification:

```text
custom navigation Back button replacing system Back
navigationBarBackButtonHidden(true) on ordinary pushed pages
manual swipe-to-back DragGesture
UIBlurEffect used to imitate Liquid Glass
ultraThinMaterial used as iOS 26 glass replacement
different icon-button implementations across features
different field styles across features
random corner radii
random page margins
custom Toggle implementation
custom tab bar where native TabView works
hard-coded status/server error strings in production UI
opaque plate behind native iOS 26 tab bar
glass stacked over glass stacked over glass
decorative gradient on routine controls
strong shadows on every card
fixed white/black UI colors without semantic reason
backend/network changes inside a design-only patch
```

---

# 55. Required UI review before merge

Every UI patch must answer YES to all relevant questions.

## Design consistency

- [ ] Uses central DesignSystem components.
- [ ] No new duplicate button component.
- [ ] No new duplicate field component.
- [ ] Uses approved radii.
- [ ] Uses approved spacing rhythm.
- [ ] Uses semantic colors.
- [ ] SF Symbols are consistent.

## iOS 26

- [ ] Native Liquid Glass is used for glass UI.
- [ ] No fake Liquid Glass.
- [ ] Nearby glass controls use GlassEffectContainer where beneficial.
- [ ] System navigation/tab/toolbars are allowed to render natively.

## Navigation

- [ ] System Back button preserved.
- [ ] Edge swipe-to-back works.
- [ ] No custom dismiss chevron replacing Back.
- [ ] NavigationStack history remains intact.

## Behavior

- [ ] Touch targets are large enough.
- [ ] Keyboard does not cover controls.
- [ ] Safe areas are correct.
- [ ] Loading state is stable.
- [ ] Error state is human-readable.
- [ ] Dark mode works.
- [ ] Dynamic Type does not catastrophically break layout.

## Scope

- [ ] UI-only task contains no backend changes.
- [ ] No auth/network route/header changes.
- [ ] No pricing/booking mutation changes.
- [ ] Git diff reviewed before release.

---

# 56. New screen acceptance checklist

A new screen is not complete until:

1. It looks native on iOS 26.
2. It remains clean on iOS 17–25.
3. It uses the same components as the rest of iumrah.
4. Back/swipe behavior is native.
5. Its toolbar is native.
6. Its icons use the same visual grammar.
7. Button hierarchy is obvious.
8. Fields match all other fields.
9. Spacing and radius values come from the approved system.
10. Dark mode works.
11. Large text does not destroy usability.
12. Reduce Motion remains usable.
13. There is no fake glass.
14. There is no backend modification hidden inside visual work.
15. The screen feels like iumrah before any logo is visible.

---

# 57. The final visual test

Before shipping a page, hide the page name, feature name, logo, and navigation title.

Then ask:

> “Could this screen visually and behaviorally belong to the same app as every other iumrah screen?”

If the answer is not immediately yes, the screen is not finished.

---

# 58. Reference philosophy

The visual benchmark is modern native Apple application behavior introduced with iOS 26:

- system-driven structure;
- Liquid Glass on interactive/navigation chrome;
- content remaining readable and restrained;
- fluid context transitions;
- native navigation;
- careful visual hierarchy.

iumrah adapts those principles to its own character:

> **Apple-native precision + premium travel clarity + care for the pilgrim.**

Do not copy another app screen pixel-for-pixel.

Copy the discipline.

---

# 59. Source-of-truth priority

When implementation decisions conflict, use this order:

1. **Apple platform behavior and accessibility**
2. **This iumrah Design Regulation**
3. **Central iumrah DesignSystem implementation**
4. **Feature-specific requirements**
5. **Individual screen preference**

A local screen style must never silently override the app-wide system.

---

# 60. Instruction for AI / developer

Before modifying any iumrah UI:

1. Read this file.
2. Inspect the existing central DesignSystem.
3. Reuse existing primitives.
4. Preserve native navigation.
5. Preserve business logic.
6. Make the smallest architectural change necessary.
7. Review the complete diff.
8. Verify the screen in light/dark mode.
9. Verify iOS 26 native behavior.
10. Verify iOS 17–25 fallback.
11. Verify swipe-to-back.
12. Do not declare the redesign “complete” until all affected screens have been audited.

If a request conflicts with this document, explicitly identify the conflict before implementing it.

---

# 61. Apple references

This regulation is aligned with Apple’s iOS 26 SwiftUI design direction and native Liquid Glass APIs, including:

- Apple Developer — Build a SwiftUI app with the new design (WWDC25)
- Apple Developer — What’s new in SwiftUI (WWDC25)
- Apple Developer — `GlassEffectContainer`
- Apple Developer — `glassEffect`
- Apple Developer — `glassEffectID`
- Apple Developer — `.buttonStyle(.glass)` / `.glassProminent`

Apple platform behavior takes precedence over visual imitation.

---

# End state

The iumrah application should never again become a collection of individually styled screens.

It is one product.

**One navigation language.**  
**One geometry language.**  
**One icon language.**  
**One motion language.**  
**One interaction language.**  
**One Liquid Glass implementation.**  
**One level of quality.**
