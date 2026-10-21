/**
 * The navigation icon set, drawn for Lyo.
 *
 * The sidebar ran on stock Lucide glyphs, which is what made it read as
 * generic: the same house, speech bubble and open book every AI product
 * ships. These are one family on one grid — 24px box, 1.8 stroke, round caps
 * — and each carries exactly one filled shape. That filled shape is the whole
 * device: it takes the brand orange when the item is active, which no stock
 * set does, and it is why these hang together.
 *
 * `Create` is the squircle the rest are built on, so the corner curve matches
 * the counters in the wordmark beside them.
 */

/**
 * The brand orange, painted on whichever shape each icon fills.
 *
 * It lives here rather than in a component because both navs need it, and a
 * constant copied into two files is how the two navs came to disagree about
 * everything else.
 */
export const NAV_ACCENT = '#ff8c00';

export type NavIconProps = {
  className?: string | undefined;
  /** Painted on the one filled shape. The rest of the icon stays stroke. */
  accent?: string | undefined;
};

const base = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.8,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  'aria-hidden': true,
};

/** An arc closing on a centre: attention, not a house. */
export function FocusIcon({ className, accent }: NavIconProps) {
  return (
    <svg {...base} className={className}>
      <path d="M12 3.2c4.9 0 8.8 3.9 8.8 8.8s-3.9 8.8-8.8 8.8S3.2 16.9 3.2 12 7.1 3.2 12 3.2Z" />
      <path d="M12 7.6c2.4 0 4.4 2 4.4 4.4" />
      <circle cx="12" cy="12" r="2.1" fill={accent ?? 'currentColor'} stroke="none" />
    </svg>
  );
}

/** A stack with one card on top — not another open book. */
export function CoursesIcon({ className, accent }: NavIconProps) {
  return (
    <svg {...base} className={className}>
      <rect x="3.2" y="7.5" width="17.6" height="12.3" rx="3" />
      <path d="M6.2 4.8h11.6" />
      <path d="M8.4 12.4h7.2" stroke={accent ?? 'currentColor'} />
    </svg>
  );
}

/** A pennant on a date. The target belongs to Focus now. */
export function TestPrepIcon({ className, accent }: NavIconProps) {
  return (
    <svg {...base} className={className}>
      <path d="M6 20.5V4.4" />
      <path d="M6 5.1h10.5l-2.3 3.4 2.3 3.4H6" fill={accent ?? 'none'} stroke="none" />
      <path d="M6 5.1h10.5l-2.3 3.4 2.3 3.4H6" />
    </svg>
  );
}

/** Two learners, one of them you. */
export function CommunityIcon({ className, accent }: NavIconProps) {
  return (
    <svg {...base} className={className}>
      <circle cx="8.6" cy="9.4" r="3.4" />
      <circle cx="16" cy="11.6" r="2.6" fill={accent ?? 'none'} stroke="none" />
      <circle cx="16" cy="11.6" r="2.6" />
      <path d="M3.4 19.4c0-2.7 2.3-4.6 5.2-4.6s5.2 1.9 5.2 4.6" />
      <path d="M15.4 16.1c2.7.2 4.6 1.8 4.6 3.9" />
    </svg>
  );
}

/** A play mark: Discover is the reel, on every platform. */
export function DiscoverIcon({ className, accent }: NavIconProps) {
  return (
    <svg {...base} className={className}>
      <path d="M12 3.2c4.9 0 8.8 3.9 8.8 8.8s-3.9 8.8-8.8 8.8S3.2 16.9 3.2 12 7.1 3.2 12 3.2Z" />
      <path d="M10.2 9.3v5.4l4.6-2.7Z" fill={accent ?? 'currentColor'} stroke="none" />
    </svg>
  );
}

/** The squircle the whole set is built on. */
export function CreateIcon({ className, accent }: NavIconProps) {
  return (
    <svg {...base} className={className}>
      <path d="M4.2 8.6c0-2.5 1.9-4.4 4.4-4.4h6.8c2.5 0 4.4 1.9 4.4 4.4v6.8c0 2.5-1.9 4.4-4.4 4.4H8.6c-2.5 0-4.4-1.9-4.4-4.4Z" />
      <path d="M12 9v6M9 12h6" stroke={accent ?? 'currentColor'} />
    </svg>
  );
}

/** The rail toggle: a panel with its edge column marked. */
export function RailToggleIcon({ className }: { className?: string | undefined }) {
  return (
    <svg {...base} strokeWidth={1.9} className={className}>
      <rect x="3" y="4" width="18" height="16" rx="3" />
      <path d="M9 4v16" />
    </svg>
  );
}

export const NAV_ICONS = {
  focus: FocusIcon,
  courses: CoursesIcon,
  testPrep: TestPrepIcon,
  community: CommunityIcon,
  discover: DiscoverIcon,
  create: CreateIcon,
} as const;
