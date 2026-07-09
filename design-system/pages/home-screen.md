# Home Screen - Page Override

> Page-specific deviations from MASTER.md
> Product: Home Services Marketplace

## Page Identity

| Attribute | Value |
|-----------|-------|
| **Purpose** | Service discovery, category navigation, quick booking |
| **User Goal** | Find and book a service in under 30 seconds |
| **Mood** | Welcoming, efficient, trustworthy |
| **Content Density** | Medium-high |

## Layout Overrides

| Element | Rule |
|---------|------|
| Top Section | Search bar + greeting (no hero image — real estate is premium) |
| Categories | Horizontal scrollable 2-line grid categories with icons |
| Active Services | Vertical card list with distance + rating |
| Bottom Nav | Always visible with active state |

## Component Specs

| Component | Radius | Padding | Elevation |
|-----------|--------|---------|-----------|
| Category Card | 16 | 12 | 0 (flat with border) |
| Service Card | 20 | 16 | 2 |
| Search Bar | 24 | h:20, v:14 | 1 |

## Color

| Element | Light | Dark |
|---------|-------|------|
| Search Bg | `white @ 90%` | `darkSurface` |
| Category Icon Bg | `primary @ 8%` | `primary @ 15%` |
| Category Border | `outline` | `outline` |

## Priority Content Order

1. **Greeting + Location** (top bar, compact)
2. **Search Bar** (always visible)
3. **Active/Urgent Orders** (if any — compact banner)
4. **Categories Grid** (scrollable, 4 columns)
5. **Top Rated Providers** (horizontal scroll, 2 cards visible)
6. **Promotional Banner** (single carousel)
7. **How It Works** (3-step compact guide)

## Anti-Patterns for This Page

- Don't use a hero image (wastes vertical space on mobile)
- Don't hide the search bar
- Don't show empty states without helpful CTAs
- Don't auto-play carousel without controls
