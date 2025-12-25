/**
 * Design Tokens - Centralized design system constants
 *
 * Extracted from the polished landing page to ensure consistency
 * across the Learning Hub and other pages.
 *
 * Uses OKLCH color space for perceptually uniform colors.
 */

// =============================================================================
// COLOR TOKENS
// =============================================================================

/**
 * Semantic color tokens using OKLCH color space.
 * Format: oklch(lightness chroma hue)
 */
export const colors = {
  // Primary accent colors
  cyan: "oklch(0.75 0.18 195)",
  pink: "oklch(0.7 0.2 330)",
  purple: "oklch(0.65 0.18 290)",

  // Semantic colors
  success: "oklch(0.72 0.19 145)",
  warning: "oklch(0.78 0.16 75)",
  error: "oklch(0.65 0.22 25)",
  info: "oklch(0.75 0.18 195)",

  // Gradient tool colors (from flywheel tools)
  sky: "from-sky-400 to-blue-500",
  violet: "from-violet-400 to-purple-500",
  rose: "from-rose-400 to-red-500",
  emerald: "from-emerald-400 to-teal-500",
  amber: "from-amber-400 to-orange-500",
  yellow: "from-yellow-400 to-amber-500",
  fuchsia: "from-pink-400 to-fuchsia-500",
} as const;

/**
 * Gradient glow colors for hover effects
 */
export const glowColors = {
  cyan: "bg-[oklch(0.75_0.18_195)]",
  pink: "bg-[oklch(0.7_0.2_330)]",
  success: "bg-[oklch(0.72_0.19_145)]",
  warning: "bg-[oklch(0.78_0.16_75)]",
  error: "bg-[oklch(0.65_0.22_25)]",
  purple: "bg-[oklch(0.65_0.18_290)]",
} as const;

// =============================================================================
// SHADOW TOKENS
// =============================================================================

/**
 * Premium shadow presets
 */
export const shadows = {
  /** Card hover shadow - subtle cyan glow */
  cardHover: "0 20px 40px -12px oklch(0.75 0.18 195 / 0.15)",
  /** Lifted card shadow */
  cardLifted: "0 25px 50px -12px oklch(0.75 0.18 195 / 0.2)",
  /** Glow effect for primary elements */
  primaryGlow: "0 0 40px -8px oklch(0.75 0.18 195 / 0.3)",
  /** Subtle shadow for floating elements */
  float: "0 8px 24px -4px rgba(0, 0, 0, 0.15)",
} as const;

// =============================================================================
// SPACING TOKENS
// =============================================================================

/**
 * Section spacing presets
 */
export const sectionSpacing = {
  /** Standard section padding */
  py: "py-24",
  /** Compact section padding */
  pyCompact: "py-16",
  /** Large section padding */
  pyLarge: "py-32",
  /** Standard horizontal padding */
  px: "px-6",
  /** Max width container */
  maxWidth: "max-w-7xl",
  /** Narrow max width for text-heavy sections */
  maxWidthNarrow: "max-w-4xl",
} as const;

// =============================================================================
// BORDER RADIUS TOKENS
// =============================================================================

/**
 * Border radius presets
 */
export const radius = {
  /** Cards and containers */
  card: "rounded-2xl",
  /** Smaller cards */
  cardSm: "rounded-xl",
  /** Inner elements */
  inner: "rounded-lg",
  /** Badges and pills */
  full: "rounded-full",
} as const;

// =============================================================================
// TYPOGRAPHY TOKENS
// =============================================================================

/**
 * Section header typography
 */
export const typography = {
  /** Section label (uppercase, small) */
  sectionLabel: "text-[11px] font-bold uppercase tracking-[0.25em] text-primary",
  /** Section heading */
  sectionHeading: "font-mono text-3xl font-bold tracking-tight",
  /** Large section heading */
  sectionHeadingLg: "font-mono text-3xl sm:text-4xl font-bold tracking-tight",
  /** Section description */
  sectionDescription: "mx-auto max-w-2xl text-muted-foreground",
} as const;

// =============================================================================
// ANIMATION CLASSES
// =============================================================================

/**
 * Tailwind animation classes
 */
export const animations = {
  /** Pulse glow for floating orbs */
  pulseGlow: "animate-pulse-glow",
  /** Shimmer effect for buttons */
  shimmer: "animate-shimmer",
} as const;

// =============================================================================
// CARD VARIANT CLASSES
// =============================================================================

/**
 * Card style variants
 */
export const cardStyles = {
  /** Base card with glass effect */
  base: "overflow-hidden rounded-2xl border border-border/50 bg-card/50 backdrop-blur-sm transition-all duration-300",
  /** Hoverable card */
  hoverable: "overflow-hidden rounded-2xl border border-border/50 bg-card/50 backdrop-blur-sm transition-all duration-300 hover:border-primary/30",
  /** Feature card with glow */
  feature: "group relative overflow-hidden rounded-2xl border border-border/50 bg-card/50 p-6 backdrop-blur-sm transition-all duration-300 hover:border-primary/30",
} as const;

// =============================================================================
// BACKGROUND EFFECT CLASSES
// =============================================================================

/**
 * Background effects
 */
export const backgrounds = {
  /** Floating orb - cyan (top-left) */
  orbCyan: "pointer-events-none absolute left-1/4 top-1/4 h-96 w-96 rounded-full bg-[oklch(0.75_0.18_195/0.1)] blur-[100px] hidden sm:block sm:animate-pulse-glow",
  /** Floating orb - pink (bottom-right) */
  orbPink: "pointer-events-none absolute right-1/4 bottom-1/4 h-80 w-80 rounded-full bg-[oklch(0.7_0.2_330/0.08)] blur-[80px] hidden sm:block sm:animate-pulse-glow",
  /** Section orb - left positioned */
  orbLeft: "pointer-events-none absolute -left-40 top-1/4 h-80 w-80 rounded-full bg-[oklch(0.75_0.18_195/0.08)] blur-[100px]",
  /** Section orb - right positioned */
  orbRight: "pointer-events-none absolute -right-40 bottom-1/4 h-80 w-80 rounded-full bg-[oklch(0.7_0.2_330/0.08)] blur-[100px]",
  /** Grid pattern overlay */
  gridPattern: "bg-grid-pattern opacity-30",
  /** Hero gradient */
  heroGradient: "bg-gradient-hero",
} as const;

// =============================================================================
// SECTION DIVIDER CLASSES
// =============================================================================

/**
 * Decorative divider elements
 */
export const dividers = {
  /** Gradient line - left side */
  gradientLeft: "h-px w-8 bg-gradient-to-r from-transparent via-primary/50 to-transparent",
  /** Gradient line - right side */
  gradientRight: "h-px w-8 bg-gradient-to-l from-transparent via-primary/50 to-transparent",
  /** Section border */
  sectionBorder: "border-t border-border/30",
} as const;

// =============================================================================
// ICON CONTAINER CLASSES
// =============================================================================

/**
 * Icon container presets
 */
export const iconContainers = {
  /** Primary icon container */
  primary: "inline-flex rounded-xl bg-primary/10 p-3 text-primary",
  /** Gradient icon container */
  gradient: (color: string) => `inline-flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br ${color}`,
} as const;

// =============================================================================
// BADGE CLASSES
// =============================================================================

/**
 * Badge style presets
 */
export const badges = {
  /** Primary badge (rounded-full) */
  primary: "inline-flex items-center gap-2 rounded-full border border-primary/30 bg-primary/10 px-4 py-1.5 text-sm text-primary",
  /** Subtle badge */
  subtle: "inline-flex items-center rounded-full border border-border/50 bg-card/50 px-3 py-1.5 text-sm font-medium transition-all hover:scale-105 hover:border-primary/30",
} as const;
