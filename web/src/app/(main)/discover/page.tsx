'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import {
  Search,
  SlidersHorizontal,
  Map,
  Wifi,
  Star,
  Clock,
  Users,
  Play,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { PlaceCard } from '@/components/discover/PlaceCard';
import { EventCard } from '@/components/discover/EventCard';
import type { EducationalPlace } from '@/types/index';

// ============================================================
// Mock Data
// ============================================================

type PlaceData = EducationalPlace & {
  imageUrl?: string;
  category: string;
  tags: string[];
  distanceLabel: string;
};

const MOCK_PLACES: PlaceData[] = [
  {
    id: 'p1',
    name: 'Central Science Library',
    type: 'library',
    description: 'A vast collection of scientific literature and digital resources.',
    address: '42 Knowledge Ave',
    coordinates: { lat: 40.712, lng: -74.006 },
    rating: 4.8,
    reviewCount: 312,
    images: [],
    categories: ['STEM', 'Research', 'Digital'],
    category: 'STEM',
    tags: ['Research', 'Digital'],
    distance: 0.4,
    distanceLabel: '0.4 mi',
    isOpen: true,
  },
  {
    id: 'p2',
    name: 'TechForge Makerspace',
    type: 'workshop',
    description: 'Hands-on tech workshops and a vibrant maker community.',
    address: '88 Circuit Blvd',
    coordinates: { lat: 40.715, lng: -74.009 },
    rating: 4.6,
    reviewCount: 189,
    images: [],
    categories: ['Technology', 'DIY', 'Robotics'],
    category: 'Technology',
    tags: ['DIY', 'Robotics'],
    distance: 1.2,
    distanceLabel: '1.2 mi',
    isOpen: true,
  },
  {
    id: 'p3',
    name: 'Northside Academy',
    type: 'school',
    description: 'K–12 institution with advanced STEM and arts programs.',
    address: '10 Elm Street',
    coordinates: { lat: 40.718, lng: -74.002 },
    rating: 4.5,
    reviewCount: 520,
    images: [],
    categories: ['Education', 'K-12', 'STEM'],
    category: 'Education',
    tags: ['K-12', 'STEM'],
    distance: 2.0,
    distanceLabel: '2.0 mi',
    isOpen: false,
  },
  {
    id: 'p4',
    name: 'BioLab Research Hub',
    type: 'lab',
    description: 'Open-access biology and chemistry lab for independent researchers.',
    address: '55 Science Park',
    coordinates: { lat: 40.720, lng: -74.010 },
    rating: 4.9,
    reviewCount: 98,
    images: [],
    categories: ['Biology', 'Chemistry', 'Research'],
    category: 'Biology',
    tags: ['Chemistry', 'Research'],
    distance: 0.8,
    distanceLabel: '0.8 mi',
    isOpen: true,
  },
  {
    id: 'p5',
    name: 'Harmony Community Center',
    type: 'community_center',
    description: 'Community-driven events, arts programs, and language classes.',
    address: '200 Unity Square',
    coordinates: { lat: 40.709, lng: -74.013 },
    rating: 4.3,
    reviewCount: 445,
    images: [],
    categories: ['Arts', 'Culture', 'Languages'],
    category: 'Arts',
    tags: ['Culture', 'Languages'],
    distance: 1.5,
    distanceLabel: '1.5 mi',
    isOpen: true,
  },
  {
    id: 'p6',
    name: 'LYO Online Campus',
    type: 'online',
    description: 'Fully virtual campus with live classes and expert mentorship.',
    address: 'Virtual',
    coordinates: { lat: 0, lng: 0 },
    rating: 4.7,
    reviewCount: 1204,
    images: [],
    categories: ['Online', 'All Subjects'],
    category: 'Online',
    tags: ['Live Classes', 'Mentorship'],
    distance: 0,
    distanceLabel: 'Online',
    isOpen: true,
  },
];

type EventData = {
  id: string;
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
  coverColor: string;
};

const MOCK_EVENTS: EventData[] = [
  {
    id: 'e1',
    title: 'Intro to Machine Learning with Python',
    date: 'Jun 22, 2026',
    time: '2:00 PM',
    hostName: 'Dr. Sarah Chen',
    location: 'Online',
    isVirtual: true,
    attendeeCount: 142,
    maxAttendees: 200,
    price: 0,
    coverColor: 'from-purple-600 to-blue-500',
  },
  {
    id: 'e2',
    title: 'Urban Sketching & Architecture Walk',
    date: 'Jun 25, 2026',
    time: '10:00 AM',
    hostName: 'Marcus Reyes',
    location: 'Downtown Arts District',
    isVirtual: false,
    attendeeCount: 18,
    maxAttendees: 25,
    price: 15,
    coverColor: 'from-orange-500 to-pink-500',
  },
  {
    id: 'e3',
    title: 'Philosophy Book Club: Existentialism',
    date: 'Jun 28, 2026',
    time: '7:00 PM',
    hostName: 'Harmony Community Center',
    location: '200 Unity Square',
    isVirtual: false,
    attendeeCount: 30,
    maxAttendees: 30,
    price: 0,
    coverColor: 'from-teal-600 to-emerald-500',
  },
  {
    id: 'e4',
    title: 'Web3 & Blockchain for Developers',
    date: 'Jul 1, 2026',
    time: '6:00 PM',
    hostName: 'TechForge Makerspace',
    location: '88 Circuit Blvd',
    isVirtual: false,
    attendeeCount: 55,
    maxAttendees: 80,
    price: 25,
    coverColor: 'from-violet-600 to-purple-500',
  },
  {
    id: 'e5',
    title: 'Live Spanish Conversation Practice',
    date: 'Jul 3, 2026',
    time: '9:00 AM',
    hostName: 'Lingua Global',
    location: 'Online',
    isVirtual: true,
    attendeeCount: 60,
    maxAttendees: 100,
    price: 0,
    coverColor: 'from-yellow-500 to-orange-500',
  },
  {
    id: 'e6',
    title: 'DIY Electronics & Arduino Workshop',
    date: 'Jul 5, 2026',
    time: '1:00 PM',
    hostName: 'BioLab Research Hub',
    location: '55 Science Park',
    isVirtual: false,
    attendeeCount: 12,
    maxAttendees: 20,
    price: 40,
    coverColor: 'from-cyan-600 to-blue-600',
  },
];

const ONLINE_CLASSES = [
  {
    id: 'oc1',
    title: 'Advanced Calculus',
    instructor: 'Prof. R. Newton',
    duration: '6 hrs',
    rating: 4.9,
    tag: 'Mathematics',
    isLive: false,
    attendees: 241,
    gradient: 'from-blue-600 to-cyan-500',
  },
  {
    id: 'oc2',
    title: 'Creative Writing 101',
    instructor: 'Ana Ferreiro',
    duration: '4 hrs',
    rating: 4.7,
    tag: 'Literature',
    isLive: true,
    attendees: 89,
    gradient: 'from-pink-500 to-rose-400',
  },
  {
    id: 'oc3',
    title: 'Music Theory Fundamentals',
    instructor: 'James Kwon',
    duration: '5 hrs',
    rating: 4.8,
    tag: 'Music',
    isLive: false,
    attendees: 56,
    gradient: 'from-amber-500 to-orange-400',
  },
  {
    id: 'oc4',
    title: 'React & Next.js Mastery',
    instructor: 'Leila Nouri',
    duration: '10 hrs',
    rating: 4.9,
    tag: 'Programming',
    isLive: true,
    attendees: 312,
    gradient: 'from-violet-600 to-indigo-500',
  },
  {
    id: 'oc5',
    title: 'Ancient Civilizations',
    instructor: 'Dr. P. Okafor',
    duration: '8 hrs',
    rating: 4.6,
    tag: 'History',
    isLive: false,
    attendees: 178,
    gradient: 'from-emerald-600 to-teal-500',
  },
];

const CATEGORIES = [
  'Science',
  'Technology',
  'Art & Design',
  'Music',
  'Languages',
  'History',
  'Mathematics',
  'Literature',
  'Programming',
  'Philosophy',
];

const TABS = ['All', 'Places', 'Events', 'Online'] as const;
type Tab = (typeof TABS)[number];

// ============================================================
// Framer Motion variants
// ============================================================

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.09, delayChildren: 0.05 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 22 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { type: 'spring' as const, stiffness: 260, damping: 22 },
  },
};

// ============================================================
// Sub-components
// ============================================================

function SectionHeader({ title }: { title: string }) {
  return (
    <motion.h2 variants={itemVariants} className="text-xl font-bold gradient-text mb-4">
      {title}
    </motion.h2>
  );
}

function OnlineClassCard({ cls }: { cls: (typeof ONLINE_CLASSES)[number] }) {
  return (
    <motion.div
      variants={itemVariants}
      whileHover={{ scale: 1.03, y: -3 }}
      transition={{ type: 'spring', stiffness: 300, damping: 22 }}
      className="glass-card rounded-2xl p-4 w-48 flex-shrink-0 flex flex-col gap-2.5 cursor-pointer"
    >
      {/* Gradient swatch with live indicator */}
      <div
        className={cn(
          'w-10 h-10 rounded-xl flex items-center justify-center bg-gradient-to-br flex-shrink-0',
          cls.gradient
        )}
      >
        <Play size={16} className="text-white" fill="white" />
      </div>

      {/* Tag + live badge */}
      <div className="flex items-center gap-1.5 flex-wrap">
        <span className="text-[10px] font-medium px-2 py-0.5 rounded-full bg-lyo-500/20 text-lyo-400">
          {cls.tag}
        </span>
        {cls.isLive && (
          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 flex items-center gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-red-400 animate-pulse inline-block" />
            LIVE
          </span>
        )}
      </div>

      {/* Title */}
      <p className="text-primary font-semibold text-xs leading-snug line-clamp-2">{cls.title}</p>

      {/* Instructor */}
      <p className="text-secondary text-[11px] truncate">{cls.instructor}</p>

      {/* Rating + duration */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-1">
          <Star size={11} className="text-yellow-400" fill="currentColor" strokeWidth={0} />
          <span className="text-secondary text-[11px]">{cls.rating}</span>
        </div>
        <div className="flex items-center gap-1">
          <Clock size={11} className="text-secondary" />
          <span className="text-secondary text-[11px]">{cls.duration}</span>
        </div>
      </div>

      {/* Attendees */}
      <div className="flex items-center gap-1">
        <Users size={11} className="text-secondary" />
        <span className="text-secondary text-[11px]">{cls.attendees.toLocaleString()} enrolled</span>
      </div>

      {/* Join button */}
      <motion.button
        whileHover={{ scale: 1.04 }}
        whileTap={{ scale: 0.96 }}
        className="w-full py-1.5 rounded-xl bg-lyo-gradient text-white text-[11px] font-semibold flex items-center justify-center gap-1.5 mt-auto"
      >
        <Wifi size={11} />
        Join Now
      </motion.button>
    </motion.div>
  );
}

// ============================================================
// Main Page
// ============================================================

export default function DiscoverPage() {
  const [activeTab, setActiveTab] = useState<Tab>('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [activeCategories, setActiveCategories] = useState<Set<string>>(new Set());

  const toggleCategory = (cat: string) => {
    setActiveCategories((prev) => {
      const next = new Set(prev);
      if (next.has(cat)) {
        next.delete(cat);
      } else {
        next.add(cat);
      }
      return next;
    });
  };

  const showPlaces = activeTab === 'All' || activeTab === 'Places';
  const showEvents = activeTab === 'All' || activeTab === 'Events';
  const showOnline = activeTab === 'All' || activeTab === 'Online';

  return (
    <div className="min-h-screen bg-background pb-24">
      <div className="max-w-5xl mx-auto px-4 sm:px-6 pt-6 space-y-8">

        {/* ---- Page header ---- */}
        <motion.div
          initial={{ opacity: 0, y: -12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
        >
          <h1 className="text-3xl font-black gradient-text mb-1">Discover</h1>
          <p className="text-secondary text-sm">Find places, events, and classes near you</p>
        </motion.div>

        {/* ---- Search bar ---- */}
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1, duration: 0.35 }}
          className="flex gap-2"
        >
          <div className="flex-1 relative">
            <Search
              size={16}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-secondary pointer-events-none"
            />
            <input
              type="text"
              placeholder="Search places, events, classes…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className={cn(
                'w-full pl-9 pr-4 py-2.5 rounded-xl text-sm text-primary placeholder:text-secondary',
                'bg-surface-2 border border-subtle focus:outline-none focus:border-lyo-500 transition-colors'
              )}
            />
          </div>
          <button className="glass-card px-3 py-2.5 rounded-xl flex items-center gap-1.5 text-secondary hover:text-primary transition-colors">
            <SlidersHorizontal size={16} />
            <span className="text-xs font-medium hidden sm:inline">Filters</span>
          </button>
        </motion.div>

        {/* ---- Tab navigation ---- */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.15 }}
          className="flex gap-2 overflow-x-auto no-scrollbar"
        >
          {TABS.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={cn(
                'flex-shrink-0 px-4 py-2 rounded-xl text-sm font-semibold transition-all',
                activeTab === tab
                  ? 'bg-lyo-gradient text-white shadow-lg shadow-lyo-500/30'
                  : 'bg-surface-2 text-secondary hover:text-primary border border-subtle'
              )}
            >
              {tab}
            </button>
          ))}
        </motion.div>

        {/* ============================================================
            NEAR YOU
        ============================================================ */}
        {showPlaces && (
          <motion.section
            key="near-you"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
          >
            <SectionHeader title="Near You" />

            {/* Map placeholder */}
            <motion.div
              variants={itemVariants}
              className="glass-card rounded-2xl h-40 mb-4 flex items-center justify-center relative overflow-hidden"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-lyo-500/10 to-accent-purple/10" />
              {/* Grid lines for map texture */}
              <div
                className="absolute inset-0 opacity-10"
                style={{
                  backgroundImage:
                    'linear-gradient(rgba(255,255,255,0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.3) 1px, transparent 1px)',
                  backgroundSize: '32px 32px',
                }}
              />
              <div className="relative flex flex-col items-center gap-2">
                <div className="w-12 h-12 rounded-full bg-lyo-500/20 border border-lyo-500/40 flex items-center justify-center">
                  <Map size={22} className="text-lyo-400" />
                </div>
                <p className="text-sm font-semibold text-primary">Map View</p>
                <p className="text-xs text-secondary">Enable location to see nearby spots</p>
              </div>
            </motion.div>

            {/* Horizontal scroll of place cards */}
            <motion.div
              variants={itemVariants}
              className="flex gap-3 overflow-x-auto no-scrollbar pb-2 -mx-4 px-4 sm:mx-0 sm:px-0"
            >
              {MOCK_PLACES.map((place) => (
                <PlaceCard key={place.id} place={place} variant="card" />
              ))}
            </motion.div>
          </motion.section>
        )}

        {/* ============================================================
            UPCOMING EVENTS
        ============================================================ */}
        {showEvents && (
          <motion.section
            key="events"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
          >
            <SectionHeader title="Upcoming Events" />
            <motion.div
              variants={containerVariants}
              className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
            >
              {MOCK_EVENTS.map((event) => (
                <motion.div key={event.id} variants={itemVariants}>
                  <EventCard event={event} />
                </motion.div>
              ))}
            </motion.div>
          </motion.section>
        )}

        {/* ============================================================
            ONLINE CLASSES
        ============================================================ */}
        {showOnline && (
          <motion.section
            key="online"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
          >
            <SectionHeader title="Online Classes" />
            <motion.div
              variants={itemVariants}
              className="flex gap-3 overflow-x-auto no-scrollbar pb-2 -mx-4 px-4 sm:mx-0 sm:px-0"
            >
              {ONLINE_CLASSES.map((cls) => (
                <OnlineClassCard key={cls.id} cls={cls} />
              ))}
            </motion.div>
          </motion.section>
        )}

        {/* ============================================================
            POPULAR CATEGORIES
        ============================================================ */}
        {(activeTab === 'All' || activeTab === 'Places') && (
          <motion.section
            key="categories"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
          >
            <SectionHeader title="Popular Categories" />
            <motion.div variants={itemVariants} className="flex flex-wrap gap-2">
              {CATEGORIES.map((cat) => {
                const isActive = activeCategories.has(cat);
                return (
                  <motion.button
                    key={cat}
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                    onClick={() => toggleCategory(cat)}
                    className={cn(
                      'px-4 py-2 rounded-full text-sm font-medium transition-all border',
                      isActive
                        ? 'bg-lyo-gradient text-white border-transparent shadow-md shadow-lyo-500/30'
                        : 'bg-surface-2 text-secondary border-subtle hover:text-primary hover:border-lyo-500/40'
                    )}
                  >
                    {cat}
                  </motion.button>
                );
              })}
            </motion.div>
          </motion.section>
        )}

        {/* ============================================================
            TOP RATED
        ============================================================ */}
        {showPlaces && (
          <motion.section
            key="top-rated"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
          >
            <SectionHeader title="Top Rated" />
            <motion.div
              variants={containerVariants}
              className="flex flex-col gap-3"
            >
              {[...MOCK_PLACES]
                .sort((a, b) => b.rating - a.rating)
                .map((place) => (
                  <motion.div key={place.id} variants={itemVariants}>
                    <PlaceCard place={place} variant="list" />
                  </motion.div>
                ))}
            </motion.div>
          </motion.section>
        )}

        <div className="h-4" />
      </div>
    </div>
  );
}
