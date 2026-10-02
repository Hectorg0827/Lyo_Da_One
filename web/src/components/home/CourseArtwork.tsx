'use client';

import { useId } from 'react';
import { motifFor } from '@/lib/focus-presentation.mjs';

/**
 * Cover art for a saved course, drawn from the course's own subject.
 *
 * A course can exist seconds after Lio makes it, so there is no moment at
 * which an uploaded cover image could have arrived. The alternatives were an
 * empty grey thumbnail or a stock picture with nothing to do with the
 * subject; this draws bonds for chemistry, speech arcs for a language, a
 * distribution for statistics, and so on.
 *
 * The motif and the palette both come from `focus-presentation.mjs`, which
 * shares its hash and motif order with iOS `FocusPresentation.swift` — so the
 * same course is drawn the same way on both platforms, and keeps the same art
 * on every visit.
 */

type Motif = 'lattice' | 'speech' | 'curve' | 'staff' | 'grid' | 'orbit';

const PALETTE: Record<Motif, { stops: [string, string, string]; ink: string; glow: string }> = {
  lattice: { stops: ['#3B2A7A', '#241A52', '#140F2E'], ink: '#C4AEFF', glow: '#A97BFF' },
  speech: { stops: ['#6B1F62', '#3C1550', '#1A0F2E'], ink: '#FFC9EC', glow: '#FF8FD4' },
  curve: { stops: ['#123C66', '#12274F', '#0D1430'], ink: '#9BD8FF', glow: '#5BB8F5' },
  staff: { stops: ['#5A3410', '#35210F', '#1C1226'], ink: '#FFE6B8', glow: '#FFC266' },
  grid: { stops: ['#1E2A6E', '#16205A', '#0E1230'], ink: '#A9BEFF', glow: '#7B93FF' },
  orbit: { stops: ['#13405A', '#14304A', '#0C1326'], ink: '#A8F2D4', glow: '#4FD6A8' },
};

const W = 320;
const H = 206;

export default function CourseArtwork({
  title,
  className = '',
}: {
  title: string;
  className?: string;
}) {
  const uid = useId().replace(/:/g, '');
  const motif = motifFor(title) as Motif;
  const { stops, ink, glow } = PALETTE[motif];

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      preserveAspectRatio="xMidYMid slice"
      className={className}
      aria-hidden="true"
      focusable="false"
    >
      <defs>
        <linearGradient id={`g${uid}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={stops[0]} />
          <stop offset="0.55" stopColor={stops[1]} />
          <stop offset="1" stopColor={stops[2]} />
        </linearGradient>
        <radialGradient id={`b${uid}`} cx="0.97" cy="0.1" r="0.95">
          <stop offset="0" stopColor={glow} stopOpacity="0.38" />
          <stop offset="1" stopColor={glow} stopOpacity="0" />
        </radialGradient>
      </defs>

      <rect width={W} height={H} fill={`url(#g${uid})`} />
      {/* One light source in the top-right for every motif, so the set reads
          as one system rather than six unrelated pictures. */}
      <rect width={W} height={H} fill={`url(#b${uid})`} />

      {motif === 'lattice' && <Lattice ink={ink} />}
      {motif === 'speech' && <Speech ink={ink} />}
      {motif === 'curve' && <Curve ink={ink} glow={glow} uid={uid} />}
      {motif === 'staff' && <Staff ink={ink} />}
      {motif === 'grid' && <Grid ink={ink} />}
      {motif === 'orbit' && <Orbit ink={ink} />}
    </svg>
  );
}

/** Fused six-rings, the way a mechanism is drawn on a board. */
function Lattice({ ink }: { ink: string }) {
  const radius = H * 0.17;
  const stepX = radius * 1.5;
  const stepY = radius * 0.866;
  const centres: Array<[number, number]> = [];

  let row = 0;
  for (let y = H * 0.26; y < H * 1.05; y += stepY * 2) {
    const offset = row % 2 === 0 ? W * 0.14 : W * 0.14 + stepX;
    for (let x = offset; x < W * 1.05; x += stepX * 2) centres.push([x, y]);
    row += 1;
  }

  return (
    <g fill="none" stroke={ink} strokeOpacity="0.34" strokeWidth="1.4" strokeLinejoin="round">
      {centres.map(([cx, cy], i) => {
        const d = Array.from({ length: 6 }, (_, corner) => {
          const angle = (corner * Math.PI) / 3 - Math.PI / 6;
          return `${corner ? 'L' : 'M'}${(cx + radius * Math.cos(angle)).toFixed(1)} ${(
            cy + radius * Math.sin(angle)
          ).toFixed(1)}`;
        }).join('');
        return (
          <g key={i}>
            <path d={`${d}Z`} />
            <circle cx={cx} cy={cy} r="2.6" fill={ink} fillOpacity="0.5" stroke="none" />
          </g>
        );
      })}
    </g>
  );
}

/** Speech radiating from the bottom-left, with a short waveform beside it. */
function Speech({ ink }: { ink: string }) {
  const rings: number[] = [];
  for (let r = H * 0.16; r < H * 1.5; r += H * 0.145) rings.push(r);
  const bars = [0.08, 0.2, 0.12, 0.3, 0.17, 0.38, 0.22, 0.14, 0.32, 0.18];

  return (
    <g>
      {rings.map((r, i) => (
        <circle
          key={i}
          cx={W * 0.1}
          cy={H * 0.94}
          r={r}
          fill="none"
          stroke={ink}
          strokeOpacity={Math.max(0.3 - r / (H * 6), 0.05)}
          strokeWidth="1.3"
        />
      ))}
      {bars.map((factor, i) => {
        const height = H * factor;
        return (
          <rect
            key={i}
            x={W * 0.54 + i * W * 0.042}
            y={H * 0.68 - height / 2}
            width="3.4"
            height={height}
            rx="1.7"
            fill={ink}
            fillOpacity="0.46"
          />
        );
      })}
    </g>
  );
}

/** A distribution with its scatter sitting on the curve, not beside it. */
function Curve({ ink, glow, uid }: { ink: string; glow: string; uid: string }) {
  const baseline = H * 0.8;
  const peak = H * 0.2;
  const left = W * 0.02;
  const right = W * 0.98;
  const mid = (left + right) / 2;

  const path =
    `M${left} ${baseline}` +
    `C${left + (mid - left) * 0.52} ${baseline} ${mid - (mid - left) * 0.42} ${peak} ${mid} ${peak}` +
    `C${mid + (right - mid) * 0.42} ${peak} ${right - (right - mid) * 0.52} ${baseline} ${right} ${baseline}`;

  const ticks: number[] = [];
  for (let x = left + W * 0.08; x < right; x += W * 0.09) ticks.push(x);

  const points = Array.from({ length: 9 }, (_, i) => {
    const t = (i + 1) / 10;
    const px = left + (right - left) * t;
    const normalised = (px - mid) / ((right - left) * 0.3);
    const py = baseline - (baseline - peak) * Math.exp(-0.5 * normalised * normalised);
    return [px, py] as const;
  });

  return (
    <g>
      <defs>
        <linearGradient id={`f${uid}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={glow} stopOpacity="0.42" />
          <stop offset="1" stopColor={glow} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={`${path}L${left} ${baseline}Z`} fill={`url(#f${uid})`} />
      <path d={path} fill="none" stroke={ink} strokeOpacity="0.75" strokeWidth="2" />
      <path
        d={`M${left} ${baseline}H${right}`}
        stroke={ink}
        strokeOpacity="0.3"
        strokeWidth="1.4"
      />
      {ticks.map((x, i) => (
        <path
          key={i}
          d={`M${x} ${baseline}v${H * 0.035}`}
          stroke={ink}
          strokeOpacity="0.28"
          strokeWidth="1.2"
          strokeLinecap="round"
        />
      ))}
      {points.map(([px, py], i) => (
        <circle key={i} cx={px} cy={py} r="2.6" fill={ink} fillOpacity="0.75" />
      ))}
    </g>
  );
}

/** Five staves with noteheads on lines and in spaces. */
function Staff({ ink }: { ink: string }) {
  const top = H * 0.3;
  const spacing = H * 0.1;
  const steps = [2, 0.5, 3, 1.5, 4, 2.5, 1, 3.5];

  return (
    <g>
      {[0, 1, 2, 3, 4].map((line) => (
        <path
          key={line}
          d={`M${W * 0.04} ${top + line * spacing}H${W * 0.96}`}
          stroke={ink}
          strokeOpacity="0.3"
          strokeWidth="1.3"
        />
      ))}
      {steps.map((step, i) => {
        const cx = W * 0.12 + i * W * 0.112;
        const cy = top + step * spacing;
        return (
          <ellipse
            key={i}
            cx={cx}
            cy={cy}
            rx="7.5"
            ry="5.2"
            fill={ink}
            fillOpacity="0.55"
            transform={`rotate(-18 ${cx} ${cy})`}
          />
        );
      })}
    </g>
  );
}

/** Axes with a vector triangle over them. */
function Grid({ ink }: { ink: string }) {
  const verticals: number[] = [];
  for (let x = W * 0.06; x < W; x += W * 0.1) verticals.push(x);
  const horizontals: number[] = [];
  for (let y = H * 0.08; y < H; y += H * 0.16) horizontals.push(y);

  const a = [W * 0.15, H * 0.82];
  const b = [W * 0.54, H * 0.26];
  const c = [W * 0.62, H * 0.9];

  return (
    <g>
      {verticals.map((x, i) => (
        <path key={`v${i}`} d={`M${x} 0V${H}`} stroke={ink} strokeOpacity="0.16" strokeWidth="1" />
      ))}
      {horizontals.map((y, i) => (
        <path key={`h${i}`} d={`M0 ${y}H${W}`} stroke={ink} strokeOpacity="0.16" strokeWidth="1" />
      ))}
      <path
        d={`M${a[0]} ${a[1]}L${b[0]} ${b[1]}L${c[0]} ${c[1]}Z`}
        fill={ink}
        fillOpacity="0.12"
        stroke={ink}
        strokeOpacity="0.58"
        strokeWidth="2"
        strokeLinejoin="round"
      />
      {[a, b, c].map(([x, y], i) => (
        <circle key={i} cx={x} cy={y} r="3" fill={ink} fillOpacity="0.8" />
      ))}
    </g>
  );
}

/** Concentric paths with a body on each — the general-purpose motif. */
function Orbit({ ink }: { ink: string }) {
  const rings: Array<{ r: number; i: number }> = [];
  let i = 0;
  for (let r = H * 0.16; r < H * 0.9; r += H * 0.19) rings.push({ r, i: i++ });
  const cx = W * 0.72;
  const cy = H * 0.52;

  return (
    <g>
      {rings.map(({ r, i: index }) => {
        const angle = index * 1.9;
        return (
          <g key={index}>
            <ellipse
              cx={cx}
              cy={cy}
              rx={r * 1.35}
              ry={r}
              fill="none"
              stroke={ink}
              strokeOpacity="0.26"
              strokeWidth="1.3"
            />
            <circle
              cx={cx + r * 1.35 * Math.cos(angle)}
              cy={cy + r * Math.sin(angle)}
              r="3.4"
              fill={ink}
              fillOpacity="0.7"
            />
          </g>
        );
      })}
    </g>
  );
}
