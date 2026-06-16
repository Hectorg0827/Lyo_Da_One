'use client';

import { useState, useCallback } from 'react';
import { motion } from 'framer-motion';
import { Search, Plus, Users, Lock, Globe, TrendingUp, Star, Loader2 } from 'lucide-react';
import { formatNumber } from '@/lib/utils';
import Link from 'next/link';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';

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

const GRADIENT_OPTIONS = [
  'from-blue-600 to-cyan-500',
  'from-pink-500 to-purple-600',
  'from-violet-600 to-indigo-500',
  'from-amber-500 to-orange-600',
  'from-emerald-500 to-teal-600',
  'from-red-500 to-pink-600',
  'from-yellow-500 to-amber-600',
  'from-gray-600 to-slate-700',
  'from-sky-500 to-blue-600',
  'from-cyan-500 to-blue-600',
  'from-emerald-600 to-green-500',
];

function mapBackendGroup(raw: Record<string, unknown>, index: number): Group {
  return {
    id: String(raw.id ?? ''),
    name: (raw.name as string) || '',
    description: (raw.description as string) || '',
    memberCount: (raw.member_count as number) ?? (raw.memberCount as number) ?? 0,
    category: (raw.category as string) || 'General',
    isPrivate: (raw.is_private as boolean) ?? false,
    isJoined: (raw.is_joined as boolean) ?? false,
    gradient: GRADIENT_OPTIONS[index % GRADIENT_OPTIONS.length],
    icon: (raw.icon as string) || '👥',
    recentActivity: (raw.recent_activity as string) || '',
  };
}

const categories = ['All', 'Programming', 'Design', 'AI', 'Science', 'Math', 'Languages', 'Music', 'Business', 'Writing'];

function GroupCard({ group, onJoinToggle }: { group: Group; onJoinToggle: (groupId: string, currentlyJoined: boolean) => void }) {
  const [joined, setJoined] = useState(group.isJoined);
  const [joining, setJoining] = useState(false);

  const handleJoinToggle = useCallback(async () => {
    setJoining(true);
    const wasJoined = joined;
    setJoined(!wasJoined);
    try {
      onJoinToggle(group.id, wasJoined);
    } catch {
      setJoined(wasJoined);
    } finally {
      setJoining(false);
    }
  }, [joined, group.id, onJoinToggle]);

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
          onClick={handleJoinToggle}
          disabled={joining}
          className={`mt-3 w-full rounded-xl py-2 text-sm font-medium transition ${
            joined
              ? 'border border-green-500/30 bg-green-500/10 text-green-400 hover:bg-green-500/20'
              : 'bg-gradient-to-r from-lyo-600 to-accent-purple text-white hover:shadow-lg hover:shadow-lyo-500/20'
          }`}
        >
          {joining ? 'Loading...' : joined ? '✓ Joined' : 'Join Group'}
        </button>
      </div>
    </motion.div>
  );
}

export default function GroupsPage() {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeCategory, setActiveCategory] = useState('All');

  // ── Fetch groups from API ──
  const {
    data: rawGroups,
    isLoading,
    error,
    refetch,
  } = useApi(
    () => api.community.groups(),
    []
  );

  const allGroups: Group[] = (rawGroups ?? []).map((raw: Record<string, unknown>, i: number) =>
    mapBackendGroup(raw, i)
  );

  // Split into categories based on isJoined
  const myGroups = allGroups.filter((g) => g.isJoined);
  const notJoinedGroups = allGroups.filter((g) => !g.isJoined);
  // Suggested = first 3 not-joined, popular = rest
  const suggestedGroups = notJoinedGroups.slice(0, 3);
  const popularGroups = notJoinedGroups.slice(3);

  const filterGroups = (groups: Group[]) =>
    groups.filter(
      (g) =>
        (activeCategory === 'All' || g.category === activeCategory) &&
        (searchQuery === '' || g.name.toLowerCase().includes(searchQuery.toLowerCase()))
    );

  const handleJoinToggle = useCallback(async (groupId: string, currentlyJoined: boolean) => {
    try {
      if (currentlyJoined) {
        await api.community.leaveGroup(groupId);
      } else {
        await api.community.joinGroup(groupId);
      }
      refetch();
    } catch (err) {
      console.error('Failed to toggle group membership:', err);
    }
  }, [refetch]);

  if (isLoading) {
    return (
      <div className="min-h-screen p-6 flex items-center justify-center">
        <Loader2 className="w-8 h-8 text-lyo-400 animate-spin" />
        <span className="ml-3 text-white/50">Loading groups...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen p-6 flex flex-col items-center justify-center gap-4">
        <p className="text-red-400">{error}</p>
        <button onClick={refetch} className="text-sm text-lyo-400 hover:text-lyo-300">
          Try again
        </button>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-6">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Groups</h1>
          <p className="text-sm text-gray-400">Find your learning community</p>
        </div>
        <button
          onClick={() => alert('Create Group coming soon!')}
          className="flex items-center gap-2 rounded-xl bg-gradient-to-r from-lyo-600 to-accent-purple px-4 py-2.5 text-sm font-medium text-white shadow-lg shadow-lyo-500/20"
        >
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
              <GroupCard key={group.id} group={group} onJoinToggle={handleJoinToggle} />
            ))}
          </div>
        </section>
      )}

      {filterGroups(suggestedGroups).length > 0 && (
        <section className="mb-8">
          <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold text-white">
            <TrendingUp className="h-5 w-5 text-lyo-400" />
            Suggested For You
          </h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {filterGroups(suggestedGroups).map((group) => (
              <GroupCard key={group.id} group={group} onJoinToggle={handleJoinToggle} />
            ))}
          </div>
        </section>
      )}

      {filterGroups(popularGroups).length > 0 && (
        <section>
          <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold text-white">
            <Globe className="h-5 w-5 text-green-400" />
            Popular Groups
          </h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {filterGroups(popularGroups).map((group) => (
              <GroupCard key={group.id} group={group} onJoinToggle={handleJoinToggle} />
            ))}
          </div>
        </section>
      )}

      {allGroups.length === 0 && (
        <div className="flex flex-col items-center justify-center py-16">
          <Users className="w-12 h-12 text-white/20 mb-4" />
          <p className="text-white/40 text-sm">No groups found</p>
        </div>
      )}
    </div>
  );
}
