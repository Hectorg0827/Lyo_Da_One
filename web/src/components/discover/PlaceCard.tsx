'use client';

import { motion } from 'framer-motion';
import {
  School,
  Library,
  FlaskConical,
  Building2,
  Globe,
  Wrench,
  Star,
  MapPin,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import type { EducationalPlace } from '@/types/index';

// ---- Types ----------------------------------------------------------------

interface PlaceCardProps {
  place: EducationalPlace & {
    /** Optional URL for a cover image. Falls back to gradient. */
    imageUrl?: string;
    /** Single category label shown as the primary pill. */
    category?: string;
    /** Extra tag pills shown below the category. */
    tags?: string[];
    /** Display distance string, e.g. "0.4 mi". Overrides computed distance. */
    distanceLabel?: string;
  };
  /** When true renders a compact horizontal list-item style. */
  variant?: 'card' | 'list';
}

// ---- Helpers --------------------------------------------------------------

const typeConfig: Record<
  EducationalPlace['type'],
  { icon: React.ElementType; gradient: string; label: string }
> = {
  school: {
    icon: School,
    gradient: 'from-lyo-600 to-accent-purple',
    label: 'School',
  },
  library: {
    icon: Library,
    gradient: 'from-accent-teal to-lyo-500',
    label: 'Library',
  },
  workshop: {
    icon: Wrench,
    gradient: 'from-accent-orange to-accent-pink',
    label: 'Workshop',
  },
  lab: {
    icon: FlaskConical,
    gradient: 'from-accent-green to-accent-teal',
    label: 'Lab',
  },
  community_center: {
    icon: Building2,
    gradient: 'from-accent-pink to-lyo-400',
    label: 'Community Center',
  },
  online: {
    icon: Globe,
    gradient: 'from-lyo-500 to-accent-purple',
    label: 'Online',
  },
};

function StarRating({ rating }: { rating: number }) {
  return (
    <div className="flex items-center gap-0.5">
      {Array.from({ length: 5 }).map((_, i) => {
        const filled = rating >= i + 1;
        const half = !filled && rating >= i + 0.5;
        return (
          <span key={i} className="relative inline-block w-3.5 h-3.5">
            {/* background grey star */}
            <Star
              size={14}
              className="text-white/20"
              fill="currentColor"
              strokeWidth={0}
            />
            {/* overlay filled portion */}
            {(filled || half) && (
              <span
                className="absolute inset-0 overflow-hidden"
                style={{ width: half ? '50%' : '100%' }}
              >
                <Star
                  size={14}
                  className="text-yellow-400"
                  fill="currentColor"
                  strokeWidth={0}
                />
              </span>
            )}
          </span>
        );
      })}
      <span className="text-xs text-secondary ml-1">{rating.toFixed(1)}</span>
    </div>
  );
}

// ---- Component ------------------------------------------------------------

export function PlaceCard({ place, variant = 'card' }: PlaceCardProps) {
  const config = typeConfig[place.type] ?? typeConfig.school;
  const Icon = config.icon;

  const distanceText =
    place.distanceLabel ??
    (place.distance != null ? `${place.distance.toFixed(1)} mi` : null);

  const primaryCategory = place.category ?? place.categories?.[0];
  const extraTags = place.tags ?? place.categories?.slice(1) ?? [];

  // ----- List variant -----
  if (variant === 'list') {
    return (
      <motion.div
        whileHover={{ x: 4 }}
        transition={{ type: 'spring', stiffness: 300, damping: 25 }}
        className="glass-card flex items-center gap-3 p-3 rounded-xl cursor-pointer"
      >
        {/* Color swatch / image */}
        <div
          className={cn(
            'w-12 h-12 rounded-lg flex-shrink-0 flex items-center justify-center bg-gradient-to-br',
            config.gradient
          )}
        >
          {place.imageUrl ? (
            <img
              src={place.imageUrl}
              alt={place.name}
              className="w-full h-full object-cover rounded-lg"
            />
          ) : (
            <Icon size={20} className="text-white" />
          )}
        </div>

        {/* Text */}
        <div className="flex-1 min-w-0">
          <p className="text-primary font-semibold text-sm truncate">
            {place.name}
          </p>
          <div className="flex items-center gap-1.5 mt-0.5">
            <Icon size={11} className="text-lyo-500 flex-shrink-0" />
            <span className="text-secondary text-xs">{config.label}</span>
            {distanceText && (
              <>
                <span className="text-white/20 text-xs">·</span>
                <MapPin size={10} className="text-secondary flex-shrink-0" />
                <span className="text-secondary text-xs">{distanceText}</span>
              </>
            )}
          </div>
          <StarRating rating={place.rating} />
        </div>

        {/* Open/closed badge */}
        <span
          className={cn(
            'text-[10px] font-semibold px-2 py-0.5 rounded-full flex-shrink-0',
            place.isOpen
              ? 'bg-accent-green/20 text-accent-green'
              : 'bg-white/10 text-secondary'
          )}
        >
          {place.isOpen ? 'Open' : 'Closed'}
        </span>
      </motion.div>
    );
  }

  // ----- Card variant -----
  return (
    <motion.div
      whileHover={{ scale: 1.03, y: -4 }}
      transition={{ type: 'spring', stiffness: 300, damping: 22 }}
      className="glass-card rounded-2xl overflow-hidden cursor-pointer w-56 flex-shrink-0"
    >
      {/* Header image / gradient */}
      <div className="relative h-32 overflow-hidden">
        {place.imageUrl ? (
          <img
            src={place.imageUrl}
            alt={place.name}
            className="w-full h-full object-cover"
          />
        ) : (
          <div
            className={cn(
              'w-full h-full bg-gradient-to-br flex items-center justify-center',
              config.gradient
            )}
          >
            <Icon size={40} className="text-white/60" />
          </div>
        )}

        {/* Open/closed overlay badge */}
        <span
          className={cn(
            'absolute top-2 right-2 text-[10px] font-semibold px-2 py-0.5 rounded-full backdrop-blur-sm',
            place.isOpen
              ? 'bg-accent-green/30 text-accent-green border border-accent-green/40'
              : 'bg-black/40 text-secondary border border-white/10'
          )}
        >
          {place.isOpen ? 'Open Now' : 'Closed'}
        </span>
      </div>

      {/* Body */}
      <div className="p-3 space-y-2">
        {/* Name */}
        <p className="text-primary font-bold text-sm leading-tight line-clamp-1">
          {place.name}
        </p>

        {/* Type + distance */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1">
            <Icon size={12} className="text-lyo-500" />
            <span className="text-secondary text-xs">{config.label}</span>
          </div>
          {distanceText && (
            <div className="flex items-center gap-1">
              <MapPin size={11} className="text-secondary" />
              <span className="text-secondary text-xs">{distanceText}</span>
            </div>
          )}
        </div>

        {/* Star rating */}
        <StarRating rating={place.rating} />

        {/* Category + tags */}
        <div className="flex flex-wrap gap-1">
          {primaryCategory && (
            <span className="text-[10px] font-medium px-2 py-0.5 rounded-full bg-lyo-500/20 text-lyo-400">
              {primaryCategory}
            </span>
          )}
          {extraTags.slice(0, 2).map((tag) => (
            <span
              key={tag}
              className="text-[10px] px-2 py-0.5 rounded-full bg-white/5 text-secondary border border-subtle"
            >
              {tag}
            </span>
          ))}
        </div>
      </div>
    </motion.div>
  );
}

export default PlaceCard;
