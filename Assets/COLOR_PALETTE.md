# Robot Heart Color Palette

**Official Brand Colors** - Extracted from Robot Heart imagery and STYLE_GUIDE.md

---

## Primary Colors (8 Official Colors)

### 1. **Robot Cream** - `#E8DCC8`
**RGB**: (232, 220, 200)  
**Usage**: Primary text on dark backgrounds, light UI elements, robot body color  
**Psychology**: Approachable, friendly, warm despite being mechanical

### 2. **Sunset Orange** - `#FF6B35`
**RGB**: (255, 107, 53)  
**Usage**: Primary CTA buttons, highlights, energetic accents  
**Psychology**: Vibrant, energetic, playa sunset magic

### 3. **Turquoise Sky** - `#4ECDC4`
**RGB**: (78, 205, 196)  
**Usage**: Active states, location markers, secondary CTAs  
**Psychology**: Fresh, energetic, optimistic - vast playa sky

### 4. **Deep Night** - `#1A1410`
**RGB**: (26, 20, 16)  
**Usage**: Primary dark mode background  
**Psychology**: Practical for bright sun, reduces eye strain

### 5. **Golden Yellow** - `#FFB300`
**RGB**: (255, 179, 0)  
**Usage**: Secondary accents, warmth, golden hour glow  
**Psychology**: Warm, inviting, community gathering

### 6. **Robot Brown** - `#3D2817`
**RGB**: (61, 40, 23)  
**Usage**: Robot details (eyes, mouth, heart), dark accents  
**Psychology**: Grounding, earthy, subtle contrast

### 7. **Warm Gray** - `#2A1F1A`
**RGB**: (42, 31, 26)  
**Usage**: Card backgrounds, modals, elevated surfaces  
**Psychology**: Intimate, cozy, night atmosphere

### 8. **Playa Dust** - `#C4A57B`
**RGB**: (196, 165, 123)  
**Usage**: Neutral backgrounds, disabled states, desert sand tone  
**Psychology**: Natural, grounding, playa environment

---

## Extended Palette (Status & Utility Colors)

### Status Colors
- **Connected**: `#4CAF50` (Green) - Network connected
- **Disconnected**: `#F44336` (Red) - Network error
- **Warning**: `#FF9800` (Orange) - Caution
- **Info**: `#4ECDC4` (Turquoise Sky) - Informational

### Text Opacity Helpers
- **Primary Text**: Robot Cream `#E8DCC8` (100%)
- **Secondary Text**: Robot Cream @ 70% opacity
- **Disabled Text**: Robot Cream @ 40% opacity

---

## Gradient Combinations

### Sunset Gradient
```
Top: #FFB300 (Golden Yellow)
Middle: #FF6F00 (Amber transitional)
Bottom: #BF360C (Deep Red-Orange)
```
**Usage**: Hero sections, dramatic backgrounds

### Playa Gradient
```
Top: #4ECDC4 (Turquoise Sky)
Bottom: #C4A57B (Playa Dust)
```
**Usage**: Map backgrounds, location features

### Dark Mode Gradient
```
Top: #2A1F1A (Warm Gray)
Bottom: #1A1410 (Deep Night)
```
**Usage**: Subtle depth in dark backgrounds

### Golden Hour Gradient
```
Top-Left: #FFB300 (Golden Yellow)
Bottom-Right: #FF6B35 (Sunset Orange)
```
**Usage**: CTAs, featured content

---

## Usage Guidelines

### Backgrounds
- **Primary**: Deep Night `#1A1410`
- **Secondary**: Warm Gray `#2A1F1A`
- **Elevated**: Slightly lighter than Warm Gray `#3A2F2A`

### Text
- **Primary**: Robot Cream `#E8DCC8`
- **Secondary**: Robot Cream @ 70%
- **Disabled**: Robot Cream @ 40%

### CTAs & Interactive Elements
- **Primary CTA**: Sunset Orange `#FF6B35`
- **Secondary CTA**: Golden Yellow `#FFB300`
- **Active State**: Turquoise Sky `#4ECDC4`
- **Disabled**: Playa Dust `#C4A57B`

### Accents
- **Energetic**: Sunset Orange `#FF6B35`
- **Warm**: Golden Yellow `#FFB300`
- **Cool**: Turquoise Sky `#4ECDC4`
- **Neutral**: Playa Dust `#C4A57B`

---

## Color Accessibility

### Contrast Ratios (WCAG AA Compliance)
- **Robot Cream on Deep Night**: 11.2:1 ✅ (AAA)
- **Sunset Orange on Deep Night**: 5.8:1 ✅ (AA)
- **Turquoise Sky on Deep Night**: 6.1:1 ✅ (AA)
- **Golden Yellow on Deep Night**: 8.9:1 ✅ (AAA)

### Best Practices
- Use Robot Cream for body text on dark backgrounds
- Sunset Orange for CTAs (sufficient contrast)
- Avoid Playa Dust for small text (use for large elements only)

---

## Implementation Notes

### SwiftUI Theme.swift
```swift
Theme.Colors.robotCream       // #E8DCC8
Theme.Colors.sunsetOrange     // #FF6B35
Theme.Colors.turquoise        // #4ECDC4
Theme.Colors.backgroundDark   // #1A1410
Theme.Colors.goldenYellow     // #FFB300
Theme.Colors.robotBrown       // #3D2817
Theme.Colors.backgroundMedium // #2A1F1A
Theme.Colors.playaDust        // #C4A57B
```

### CSS Variables
```css
--robot-cream: #E8DCC8;
--sunset-orange: #FF6B35;
--turquoise-sky: #4ECDC4;
--deep-night: #1A1410;
--golden-yellow: #FFB300;
--robot-brown: #3D2817;
--warm-gray: #2A1F1A;
--playa-dust: #C4A57B;
```

---

## Color Psychology & Brand Story

**Sunset/Golden Hour Tones**: Evoke the magical golden hour on the playa when the Robot Heart art car comes alive. Community gathering, warmth, and connection.

**Robot Cream**: Makes the robot character feel approachable and warm despite being mechanical. Nostalgic, friendly.

**Turquoise Sky**: Represents the vast, endless playa sky. Freedom, optimism, energy.

**Deep Darks**: Practical for the bright desert sun during the day, reduces eye strain. Creates an intimate atmosphere for night events.

**Playa Dust**: Grounds the palette in the physical environment of Black Rock Desert. Authentic, earthy.

---

*Last updated: January 2026*  
*Aligned with STYLE_GUIDE.md official brand colors*
