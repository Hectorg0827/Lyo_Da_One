'use client';

import { motion } from 'framer-motion';
import {
  Calendar,
  Clock,
  MapPin,
  Users,
  Wifi,
} from 'lucide-react';
import { cn } from '@/lib/utils';

// ---- Types ----------------------------------------------------------------

export interface EventCardProps {
  event: {
    id?: string;
    title: string;
    date: string;
    time: string;
    hostName: string;
    hostAvatar?: string;
    location: string;
    isVirtual: boolean;
    attendeeCount: number;
    maxAttendees: number;
    price: number;
    /** Tailwind gradient string, e.g. "from-purple-600 to-blue-500" */
    coverColor: string;
  };
}

// ---- Helpers --------------------------------------------------------------

function formatPrice(price: number): React.ReactNode {
  if (price === 0) {
    return <span className="text-accent-green font-semibold">Free</span>;
  }
  return (
    <span className="text-primary font-semibold">
      ${price.toFixed(2)}
    </span>
  );
}

function AvatarFallback({ name, src }: { name: string; src?: string }) {
  if (src) {
    return (
      <img
        src={src}
        alt={name}
        className="w-6 h-6 rounded-full object-cover"
      />
    );
  }
  return (
    <div className="w-6 h-6 rounded-full bg-lyo-gradient flex items-center justify-center text-white text-[10px] font-bold flex-shrink-0">
      {name.charAt(0).toUpperCase()}
    </div>
  );
}

// ---- Component ------------------------------------------------------------

export function EventCard({ event }: EventCardProps) {
  const {
    title,
    date,
    time,
    hostName,
    hostAvatar,
    location,
    isVirtual,
    attendeeCount,
    maxAttendees,
    price,
    coverColor,
  } = event;

  const spotsLeft = maxAttendees - attendeeCount;
  const isFull = spotsLeft <= 0;

  return (
    <motion.div
      whileHover={{ scale: 1.02, y: -4 }}
      transition={{ type: 'spring', stiffness: 280, damping: 22 }}
      className="glass-card rounded-2xl overflow-hidden cursor-pointer flex flex-col"
    >
      {/* ---- Gradient header ---- */}
      <div
        className={cn(
          'h-24 bg-gradient-to-r relative flex items-end p-3',
          coverColor
        )}
      >
        {/* Virtual / In Person badge */}
        <span
          className={cn(
            'absolute top-2 left-3 text-[10px] font-semibold px-2 py-0.5 rounded-full backdrop-blur-sm border',
            isVirtual
              ? 'bg-accent-purple/30 text-lyo-400 border-lyo-500/40'
              : 'bg-accent-teal/30 text-accent-teal border-accent-teal/40'
          )}
        >
          {isVirtual ? 'Virtual' : 'In Person'}
        </span>

        {/* Price badge top-right */}
        <span className="absolute top-2 right-3 text-[10px] font-semibold px-2 py-0.5 rounded-full bg-black/40 backdrop-blur-sm text-white border border-white/10">
          {price === 0 ? 'Free' : `$${price.toFixed(2)}`}
        </span>
      </div>

      {/* ---- Body ---- */}
      <div className="p-4 flex flex-col gap-2.5 flex-1">
        {/* Title */}
        <h3 className="text-primary font-bold text-sm leading-snug line-clamp-2">
          {title}
        </h3>

        {/* Date + time */}
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1">
            <Calendar size={12} className="text-lyo-500 flex-shrink-0" />
            <span className="text-secondary text-xs">{date}</span>
          </div>
          <div className="flex items-center gap-1">
            <Clock size={12} className="text-lyo-500 flex-shrink-0" />
            <span className="text-secondary text-xs">{time}</span>
          </div>
        </div>

        {/* Host */}
        <div className="flex items-center gap-1.5">
          <AvatarFallback name={hostName} src={hostAvatar} />
          <span className="text-secondary text-xs truncate">{hostName}</span>
        </div>

        {/* Location */}
        <div className="flex items-center gap-1.5">
          {isVirtual ? (
            <>
              <Wifi size={12} className="text-lyo-500 flex-shrink-0" />
              <span className="text-secondary text-xs">Online</span>
            </>
          ) : (
            <>
              <MapPin size={12} className="text-secondary flex-shrink-0" />
              <span className="text-secondary text-xs truncate">{location}</span>
            </>
          )}
        </div>

        {/* Attendees + price row */}
        <div className="flex items-center justify-between mt-auto">
          <div className="flex items-center gap-1">
            <Users size={12} className="text-secondary flex-shrink-0" />
            <span className="text-secondary text-xs">
              {attendeeCount.toLocaleString()}/{maxAttendees.toLocaleString()}
            </span>
            {isFull && (
              <span className="text-[10px] text-accent-orange ml-1">Full</span>
            )}
          </div>
          <div className="text-xs">{formatPrice(price)}</div>
        </div>

        {/* Register button */}
        <motion.button
          whileHover={{ scale: isFull ? 1 : 1.02 }}
          whileTap={{ scale: isFull ? 1 : 0.97 }}
          disabled={isFull}
          className={cn(
            'w-full py-2 rounded-xl text-xs font-semibold transition-opacity',
            isFull
              ? 'bg-white/10 text-secondary cursor-not-allowed'
              : 'bg-lyo-gradient text-white'
          )}
        >
          {isFull ? 'Event Full' : 'Register'}
        </motion.button>
      </div>
    </motion.div>
  );
}

export default EventCard;
