# Family Docs 2.0 — Design System Specification
**Design Theme**: Family Vault Sanctuary  
**Stitch Project Reference**: `projects/1822699660294662437`  
**Target Platform**: Flutter (Android & iOS) with Material 3  

---

## 1. Brand Essence & Visual Direction

Family Docs 2.0 combines **Institutional Security (Zero-Knowledge Enclave)** with **Domestic Calm & Tactile Warmth**.
It avoids clinical coldness and dark hacker tropes, instead utilizing a serene, high-trust light-mode canvas with deep slate/navy anchors, electric sapphire/indigo security accents, and emerald trust indicators.

### Two Visual Explorations:
- **Direction A: Minimal Premium Sanctuary (Selected / Baseline)**: Crisp light-mode surface (`#F8FAFC`), pure white cards (`#FFFFFF`) with whisper-thin slate outlines (`#F1F5F9`), deep slate/navy gradient hero cards (`#1E293B` to `#0F172A`), electric indigo accents (`#4F46E5`), and emerald trust signals (`#10B981`).
- **Direction B: Expressive Modern Premium**: Layered glassmorphic frosted cards with luminous outer glow, radial vault telemetry dials, and high-contrast alert overlays.

---

## 2. Color Palette & Semantic Tokens

### Canvas & Surfaces
| Token Name | Hex Code | Flutter `ColorScheme` Mapping | Usage |
| :--- | :--- | :--- | :--- |
| `surfaceBackground` | `#F8FAFC` | `colorScheme.surface` | Primary scaffold background |
| `cardSurface` | `#FFFFFF` | `colorScheme.surfaceContainerLowest` | Primary card background |
| `surfaceMuted` | `#F1F5F9` | `colorScheme.surfaceContainerLow` | Secondary container, search field fill |
| `surfaceBorder` | `#E2E8F0` | `colorScheme.outlineVariant` | Subtle perimeter strokes and dividers |
| `surfaceBorderSubtle` | `#F1F5F9` | `colorScheme.outlineVariant.withOpacity(0.5)` | Card borders, list separators |

### Primary Enclave & Text
| Token Name | Hex Code | Flutter Mapping | Usage |
| :--- | :--- | :--- | :--- |
| `enclavePrimary` | `#0F172A` | `colorScheme.primary` | Headers, primary CTAs, active dock icons |
| `enclaveSecondary` | `#1E293B` | `colorScheme.onSurface` | Hero gradient start, strong body copy |
| `textMuted` | `#64748B` | `colorScheme.onSurfaceVariant` | Subtitles, metadata, file sizes, timestamps |
| `textSubtle` | `#94A3B8` | `colorScheme.outline` | Placeholder text, disabled labels |

### Security, Action & Trust Accents
| Token Name | Hex Code | Background Tint | Meaning & Usage |
| :--- | :--- | :--- | :--- |
| `securityIndigo` | `#4F46E5` | `#EEF2FF` | Active navigation pills, biometric scan rings, primary actions |
| `trustEmerald` | `#10B981` | `#ECFDF5` | Hardware Keystore active, cloud synced, valid certificates |
| `warningAmber` | `#F59E0B` | `#FFFBEB` | Expiring soon (<30 days), renewal notices, travel cautions |
| `alertRose` | `#EF4444` | `#FEF2F2` | Critical expired documents, deletion triggers, failed checks |
| `categorySky` | `#0284C7` | `#F0F9FF` | Health & medical documents |
| `categoryPurple` | `#8B5CF6` | `#F5F3FF` | Education & academic records |

---

## 3. Typography Hierarchy

Primary Headings: **Plus Jakarta Sans** (Structural clarity, modern geometric geometry)  
Body, Data & Metadata: **Inter** (High legibility, tabular numerals for file sizes/dates)

| Style | Font Family | Size | Weight | Line Height | Letter Spacing | Flutter `TextTheme` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Display Large** | Plus Jakarta Sans | 32sp | Bold (700) | 40sp | -0.02em | `textTheme.displayLarge` |
| **Headline Large** | Plus Jakarta Sans | 24sp | Bold (700) | 32sp | -0.02em | `textTheme.headlineLarge` |
| **Headline Medium**| Plus Jakarta Sans | 20sp | SemiBold (600) | 28sp | -0.015em | `textTheme.headlineMedium` |
| **Headline Small** | Plus Jakarta Sans | 18sp | SemiBold (600) | 24sp | -0.01em | `textTheme.headlineSmall` |
| **Title Medium** | Inter | 16sp | SemiBold (600) | 22sp | -0.01em | `textTheme.titleMedium` |
| **Body Large** | Inter | 16sp | Regular (400) | 24sp | 0.0em | `textTheme.bodyLarge` |
| **Body Medium** | Inter | 14sp | Regular (400) | 20sp | 0.0em | `textTheme.bodyMedium` |
| **Body Small** | Inter | 13sp | Regular (400) | 18sp | 0.005em | `textTheme.bodySmall` |
| **Label Medium** | Plus Jakarta Sans | 12sp | SemiBold (600) | 16sp | 0.02em | `textTheme.labelMedium` |
| **Label Small** | Plus Jakarta Sans | 11sp | Bold (700) | 14sp | 0.04em | `textTheme.labelSmall` |
| **Data Mono** | Inter (Tabular) | 13sp | Medium (500) | 18sp | 0.01em | Custom `TextStyle` |

---

## 4. Spacing, Radii & Elevation

### Spacing Scale (4pt/8pt Grid)
- `space2xs`: 4.0 dp (tight badge padding)
- `spaceXs`: 6.0 dp (chip internal vertical padding)
- `spaceSm`: 8.0 dp (list item spacing, icon gaps)
- `spaceMd`: 12.0 dp (card internal padding, horizontal chip gaps)
- `spaceLg`: 16.0 dp (screen margins, card content padding)
- `spaceXl`: 20.0 dp (section vertical separation)
- `space2xl`: 24.0 dp (hero card padding)
- `space3xl`: 32.0 dp (modal sheet padding)

### Corner Radii
- `radiusSm`: 8.0 dp (tags, badges, file-type icons)
- `radiusMd`: 12.0 dp (input fields, action tiles)
- `radiusLg`: 16.0 dp (document cards, category cards)
- `radiusXl`: 20.0 dp (hero vault cards, modal bottom sheets)
- `radiusFull`: 9999.0 dp (pills, floating action pills, avatar rings)

### Elevation & Layering
- **Level 0 (Base)**: Flat scaffold `#F8FAFC`.
- **Level 1 (Cards)**: White card `#FFFFFF`, 1px border `#F1F5F9`, subtle drop shadow:
  `BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2))`
- **Level 2 (Elevated Modals & Floating Pills)**:
  `BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, 6))`
- **Hero Card Glow**:
  Gradient `LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)])` with 20dp radii.

---

## 5. Component Specifications

### 1. Vault Hero Card
- Gradient: Deep slate `#1E293B` to `#0F172A`.
- Content: Greeting, total protected documents count, hardware encryption badge (`AES-256 Encrypted` with emerald pulsating dot), and category-segmented storage progress bar.

### 2. Document Card
- Surface: Clean white card, 16dp rounded corners, 1dp subtle border.
- Elements: File type badge (PDF crimson, Image sky, Doc indigo), filename, owner badge (`Rahul (Admin)`), file size, relative date, synced cloud indicator, and warning badge if expiring soon.

### 3. Family Member Card
- Format: Horizontal carousel and grid list.
- Avatar with role badge (Admin, Adult, Child), document counter pill, biometrics active indicator.

### 4. Search & Filter Bar
- Pill-shaped container (`48dp` height), `#F1F5F9` background, prefix search icon, clear button, and scope pills (Filename, OCR Content, Member, Date).

### 5. In-App Document Viewer & Preview
- Embedded PDF page rendering with page indicator (`Page 1 of 2`), zoom controls, metadata panel (detected document type, masked ID number with unmask toggle, issue & expiry dates).

### 6. App Lock Gate
- Elevated biometric medallion with dual-ring pulsing glow.
- 6-dot PIN indicator (filled vs empty).
- Tactile 3x4 circular ghost numeric keypad.
- Zero-knowledge security guarantee and emergency phrase recovery link.

---

## 6. Animation & Motion Design (Phase 1 Baseline)

- **Screen Transitions**: Subtle shared-axis slide and fade transitions (`CupertinoPageTransitionsBuilder` or `FadeThrough` curve with 250ms duration).
- **Card Tap Feedback**: Gentle micro-depression scale (`scale: 0.98`) with standard ink ripple.
- **List Entrance**: Subtle staggered fade-in + slide-up (`200ms` duration, `15ms` interval).
- **Status Pulsing**: Subtle periodic opacity tween (`0.6` to `1.0` over 1500ms) on security and recording status dots.

---

## 7. Accessibility Guidelines

- **Touch Targets**: All interactive elements maintain a minimum 48×48 dp clickable area.
- **Color Contrast**: All text tokens comply with WCAG AA (minimum 4.5:1 contrast against surfaces).
- **Screen Reader Support**: All icons and status pills include explicit `Semantics(label: ...)` wrappers.
- **Dynamic Type**: Text sizes respond to system font scaling gracefully without clipping.

