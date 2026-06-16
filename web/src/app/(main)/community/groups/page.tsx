'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { Search, Plus, Users, Lock, Globe, TrendingUp, Star } from 'lucide-react';
import { formatNumber } from '@/lib/utils';
import Link from 'next/link';

interface Group {
  id: string;
  name: string;
  description: string;
  memberCount: number;
  category: string;
  isPrivate: boolean;
  isJoined: boolean;
  gradient: string;
  icon: string;
  recentActivity: string;
}

const myGroups: Group[] = [
  {
    id: 'g1',
    name: 'Python Enthusiasts',
    description: 'A community for Python developers of all levels. Share code, ask questions, and learn together.',
    memberCount: 2340,
    category: 'Programming',
    isPrivate: false,
    isJoined: true,
    gradient: 'from-blue-600 to-cyan-500',
    icon: '🐍',
    recentActivity: 'New post 2 hours ago',
  },
  {
    id: 'g2',
    name: 'UI/UX Design Lab',
    description: 'Explore design principles, share your work, get feedback from fellow designers.',
    memberCount: 1890,
    category: 'Design',
    isPrivate: false,
    isJoined: true,
    gradient: 'from-pink-500 to-purple-600',
    icon: '🎨',
    recentActivity: 'New post 5 hours ago',
  },
];

const suggestedGroups: Group[] = [
  {
    id: 'g3',
    name: 'AI & Machine Learning',
    description: 'Deep dive into AI, ML, and deep learning. Research papers, tutorials, and project showcases.',
    memberCount: 5670,
    category: 'AI',
    isPrivate: false,
    isJoined: false,
    gradient: 'from-violet-600 to-indigo-500',
    icon: '🤖',
    recentActivity: 'New post 1 hour ago',
  },
  {
    id: 'g4',
    name: 'Creative Writing Circle',
    description: 'Share your stories, poems, and essays. Constructive feedback and writing prompts weekly.',
    memberCount: 890,
    category: 'Writing',
    isPrivate: false,
    isJoined: false,
    gradient: 'from-amber-500 to-orange-600',
    icon: '✍️',
    recentActivity: 'New post 3 hours ago',
  },
  {
    id: 'g5',
    name: 'Music Theory Study Group',
    description: 'Understanding harmony, melody, rhythm, and composition together.',
    memberCount: 1230,
    category: 'Music',
    isPrivate: false,
    isJoined: false,
    gradient: 'from-emerald-500 to-teal-600',
    icon: '🎵',
    recentActivity: 'New post 6 hours ago',
  },
];

const popularGroups: Group[] = [
  {
    id: 'g6',
    name: 'Math Olympiad Prep',
    description: 'Prepare for math competitions with challenging problems and solutions.',
    memberCount: 3450,
    category: 'Mathematics',
    isPrivate: false,
    isJoined: false,
    gradient: 'from-red-500 to-pink-600',
    icon: '📐',
    recentActivity: 'New challenge posted',
  },
  {
    id: 'g7',
    name: 'Photography Masterclass',
    description: 'Learn composition, lighting, editing. Weekly photo challenges and critique sessions.',
    memberCount: 4120,
    category: 'Photography',
    isPrivate: false,
    isJoined: false,
    gradient: 'from-yellow-500 to-amber-600',
    icon: '📸',
    recentActivity: 'Photo challenge live',
  },
  {
    id: 'g8',
    name: 'Web3 Builders',
    description: 'Building the decentralized web. Blockchain, smart contracts, and DApps.',
    memberCount: 2780,
    category: 'Blockchain',
    isPrivate: true,
    isJoined: false,
    gradient: 'from-gray-600 to-slate-700',
    icon: '⛓️',
    recentActivity: 'New tutorial posted',
  },
  {
    id: 'g9',
    name: 'Language Exchange',
    description: 'Practice any language with native speakers. Organized by language pairs.',
    memberCount: 6890,
    category: 'Languages',
    isPrivate: false,
    isJoined: false,
    gradient: 'from-sky-500 to-blue-600',
    icon: '🌎',
    recentActivity: 'New session scheduled',
  },
  {
    id: 'g10',
    name: 'Data Science Hub',
    description: 'Data analysis, visualization, statistics, and practical data projects.',
    memberCount: 3210,
    category: 'Data Science',
    isPrivate: false,
    isJoined: false,
    gradient: 'from-cyan-500 to-blue-600',
    icon: '📊',
    recentActivity: 'Dataset challenge live',
  },
  {
    id: 'g11',
    name: 'Startup Founders Circle',
    description: 'For aspiring and current founders. Business strategy, fundraising, and growth.',
    memberCount: 1560,
    category: 'Business',
    isPrivate: true,
    isJoined: false,
    gradient: 'from-emerald-600 to-green-500',
    icon: '🚀',
    recentActivity: 'AMA with founder today',
  },
];

const categories = ['All', 'Programming', 'Design', 'AI', 'Science', 'Math', 'Languages', 'Music', 'Business', 'Writing'];

function GroupCard({ group }: { group: Group }) {
  const [joined, setJoined] = useState(group.isJoined);

  return (
    <motion.div
      whileHover={{ y: -4 }}
      className="overflow-hidden rounded-2xl border border-white/5 bg-white/5 backdrop-blur-sm"
    >
      <div className={`h-24 bg-gradient-to-br ${group.gradient} relative`}>
        <div className="absolute -bottom-5 left-4 flex h-12 w-12 items-center justify-center rounded-xl bg-gray-900 text-2xl shadow-lg ring-2 ring-gray-900">
          {group.icon}
        </div>
        {group.isPrivate && (
          <div className="absolute right-3 top-3 flex items-center gap-1 rounded-full bg-black/30 px-2 py-0.5 text-xs text-white/80 backdrop-blur-sm">
            <Lock className="h-3 w-3" /> Private
          </div>
        )}
      </div>
      <div className="p-4 pt-8">
        <h3 className="text-base font-semibold text-white">{group.name}</h3>
        <p className="mt-1 line-clamp-2 text-sm text-gray-400">{group.description}</p>
        <div className="mt-3 flex items-center justify-between">
          <div className="flex items-center gap-3 text-xs text-gray-500">
            <span className="flex items-center gap-1">
              <Users className="h-3 w-3" />
              {formatNumber(group.memberCount)}
            </span>
            <span>{group.recentActivity}</span>
          </div>
        </div>
        <button
          onClick={() => setJoined(!joined)}
          className={`mt-3 w-full rounded-xl py-2 text-sm font-medium transition ${
            joined
              ? 'border border-green-500/30 bg-green-500/10 text-green-400 hover:bg-green-500/20'
              : 'bg-gradient-to-r from-lyo-600 to-accent-purple text-white hover:shadow-lg hover:shadow-lyo-500/20'
          }`}
        >
          {joined ? '✓ Joined' : 'Join Group'}
        </button>
      </div>
    </motion.div>
  );
}

export default function GroupsPage() {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeCategory, setActiveCategory] = useState('All');

  const filterGroups = (groups: Group[]) =>
    groups.filter(
      (g) =>
        (activeCategory === 'All' || g.category === activeCategory) &&
        (searchQuery === '' || g.name.toLowerCase().includes(searchQuery.toLowerCase()))
    );

  return (
    <div className="min-h-screen p-6">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Groups</h1>
          <p className="text-sm text-gray-400">Find your learning community</p>
        </div>
        <button className="flex items-center gap-2 rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple px-4 py-2.5 text-sm font-medium text-white shadow-lg shadow-lyo-500/20">
          <Plus className="h-4 w-4" />
          Create Group
        </button>
      </div>

      <div className="relative mb-4">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500" />
        <input
          type="text"
          placeholder="Search groups..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full rounded-xl border border-white/10 bg-white/5 py-2.5 pl-10 pr-4 text-sm text-white placeholder-gray-500 outline-none focus:border-lyo-500/50"
        />
      </div>

      <div className="mb-6 flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
        {categories.map((cat) => (
          <button
            key={cat}
            onClick={() => setActiveCategory(cat)}
            className={`whitespace-nowrap rounded-full px-4 py-1.5 text-sm transition ${
              activeCategory === cat
                ? 'bg-lyo-600 text-white'
                : 'border border-white/10 bg-white/5 text-gray-400 hover:text-white'
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      {filterGroups(myGroups).length > 0 && (
        <section className="mb-8">
          <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold text-white">
            <Star className="h-5 w-5 text-yellow-400" />
            My Groups
          </h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {filterGroups(myGroups).map((group) => (
              <GroupCard key={group.id} group={group} />
            ))}
          </div>
        </section>
      )}

      <section className="mb-8">
        <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold text-white">
          <TrendingUp className="h-5 w-5 text-lyo-400" />
          Suggested For You
        </h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filterGroups(suggestedGroups).map((group) => (
            <GroupCard key={group.id} group={group} />
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold text-white">
          <Globe className="h-5 w-5 text-green-400" />
          Popular Groups
        </h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filterGroups(popularGroups).map((group) => (
            <GroupCard key={group.id} group={group} />
          ))}
        </div>
      </section>
    </div>
  );
}
