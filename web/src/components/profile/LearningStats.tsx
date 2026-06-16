'use client';

import { motion } from 'framer-motion';
import { Clock, BookOpen, Flame, CheckCircle, Trophy, Star, Target, Zap, Lock } from 'lucide-react';
import { LearningStats } from '@/types';
import { cn } from '@/lib/utils';

interface LearningStatsProps {
  stats: LearningStats;
}

// ── Mock calendar data (28 days, 4 rows x 7 cols) ───────────────────────────

function generateCalendarData() {
  return Array.from({ length: 28 }, (_, i) => ({
    day: i,
    level: Math.floor(Math.random() * 5), // 0=none, 1=low, 2=med, 3=high, 4=max
  }));
}

const calendarData = generateCalendarData();

const activityColors = [
  'rgba(255,255,255,0.06)', // none
  'rgba(108,99,255,0.25)',  // low
  'rgba(108,99,255,0.45)',  // medium
  'rgba(108,99,255,0.7)',   // high
  '#6c63ff',                // max
];

// ── Achievements mock ────────────────────────────────────────────────────────

const achievements = [
  { id: '1', label: 'First Step', icon: '🎯', unlocked: true },
  { id: '2', label: 'Week Warrior', icon: '🔥', unlocked: true },
  { id: '3', label: 'Quiz Master', icon: '🧠', unlocked: true },
  { id: '4', label: 'Speed Learner', icon: '⚡', unlocked: false },
  { id: '5', label: 'Social Butterfly', icon: '🦋', unlocked: false },
  { id: '6', label: 'Course Creator', icon: '✨', unlocked: false },
];

// ── Animation ────────────────────────────────────────────────────────────────

const itemVariants = {
  hidden: { opacity: 0, y: 16 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.4, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] } },
};

const containerVariants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { staggerChildren: 0.1 } },
};

// ── Sub-components ───────────────────────────────────────────────────────────

function StatCard({
  icon: Icon,
  label,
  value,
  color,
  sub,
}: {
  icon: React.ComponentType<{ size?: number | string; className?: string; style?: React.CSSProperties }>;
  label: string;
  value: string | number;
  color: string;
  sub?: string;
}) {
  return (
    <motion.div variants={itemVariants} className="glass-card p-4 space-y-3">
      <div
        className="w-10 h-10 rounded-xl flex items-center justify-center"
        style={{ background: `${color}20` }}
      >
        <Icon size={20} style={{ color }} />
      </div>
      <div>
        <p className="text-2xl font-black text-primary leading-none">{value}</p>
        {sub && <p className="text-xs text-secondary mt-0.5">{sub}</p>}
      </div>
      <p className="text-xs font-medium text-secondary">{label}</p>
    </motion.div>
  );
}

// ── Main Component ───────────────────────────────────────────────────────────

export default function LearningStatsPanel({ stats }: LearningStatsProps) {
  const maxTopicHours = Math.max(...stats.topTopics.map((t) => t.hours), 1);

  return (
    <motion.div
      className="space-y-6"
      variants={containerVariants}
      initial="hidden"
      animate="visible"
    >
      {/* Stat Cards Grid */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <StatCard
          icon={Clock}
          label="Hours Learned"
          value={stats.totalHoursLearned}
          color="#6c63ff"
          sub="total"
        />
        <StatCard
          icon={BookOpen}
          label="Courses Completed"
          value={stats.coursesCompleted}
          color="#22c55e"
          sub={`${stats.coursesInProgress} in progress`}
        />
        <StatCard
          icon={Flame}
          label="Current Streak"
          value={`${stats.currentStreak}d`}
          color="#f59e0b"
          sub={`Best: ${stats.longestStreak}d`}
        />
        <StatCard
          icon={CheckCircle}
          label="Quizzes Passed"
          value={stats.quizzesPassed}
          color="#3b82f6"
          sub={`${stats.xpThisWeek} XP this week`}
        />
      </div>

      {/* Streak Calendar */}
      <motion.div variants={itemVariants} className="glass-card p-5">
        <h3 className="text-sm font-bold text-primary mb-1">Activity Calendar</h3>
        <p className="text-xs text-secondary mb-4">Last 28 days</p>
        <div className="grid grid-cols-7 gap-1.5">
          {calendarData.map((day) => (
            <div
              key={day.day}
              className="aspect-square rounded-md transition-all duration-200 hover:scale-110 cursor-pointer"
              style={{ background: activityColors[day.level] }}
              title={`Day ${day.day + 1}: Level ${day.level}`}
            />
          ))}
        </div>
        <div className="flex items-center gap-2 mt-3 justify-end">
          <span className="text-[10px] text-secondary">Less</span>
          {activityColors.map((color, i) => (
            <div
              key={i}
              className="w-3 h-3 rounded-sm"
              style={{ background: color }}
            />
          ))}
          <span className="text-[10px] text-secondary">More</span>
        </div>
      </motion.div>

      {/* Top Topics — Bar Chart */}
      <motion.div variants={itemVariants} className="glass-card p-5">
        <h3 className="text-sm font-bold text-primary mb-4">Top Topics</h3>
        <div className="space-y-3">
          {stats.topTopics.map((topic, i) => {
            const pct = Math.round((topic.hours / maxTopicHours) * 100);
            const colors = ['#6c63ff', '#22c55e', '#f59e0b', '#3b82f6', '#ec4899'];
            const color = colors[i % colors.length];
            return (
              <div key={topic.topic} className="space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span className="font-medium text-primary">{topic.topic}</span>
                  <span className="text-secondary">{topic.hours}h</span>
                </div>
                <div className="h-2 w-full rounded-full overflow-hidden" style={{ background: 'rgba(255,255,255,0.08)' }}>
                  <motion.div
                    className="h-full rounded-full"
                    style={{ background: color }}
                    initial={{ width: 0 }}
                    animate={{ width: `${pct}%` }}
                    transition={{ duration: 0.8, ease: 'easeOut', delay: i * 0.1 }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </motion.div>

      {/* Recent Achievements */}
      <motion.div variants={itemVariants} className="glass-card p-5">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-bold text-primary">Recent Achievements</h3>
          <button className="text-xs text-secondary hover:text-primary transition-colors flex items-center gap-1">
            <Trophy size={12} /> View all
          </button>
        </div>
        <div className="grid grid-cols-3 sm:grid-cols-6 gap-3">
          {achievements.map((ach) => (
            <div
              key={ach.id}
              className={cn(
                'flex flex-col items-center gap-2 p-3 rounded-xl transition-all duration-200',
                ach.unlocked ? 'hover:scale-105 cursor-pointer' : 'opacity-40 cursor-not-allowed'
              )}
              style={{
                background: ach.unlocked ? 'rgba(108,99,255,0.1)' : 'rgba(255,255,255,0.04)',
                border: ach.unlocked ? '1px solid rgba(108,99,255,0.25)' : '1px solid rgba(255,255,255,0.06)',
              }}
            >
              <div
                className="w-10 h-10 rounded-full flex items-center justify-center text-xl relative"
                style={
                  ach.unlocked
                    ? { background: 'linear-gradient(135deg, #6c63ff, #a78bfa)' }
                    : { background: 'rgba(255,255,255,0.08)' }
                }
              >
                {ach.unlocked ? ach.icon : <Lock size={14} className="text-white/40" />}
              </div>
              <span className="text-[10px] text-center font-medium leading-tight"
                style={{ color: ach.unlocked ? 'var(--text-primary)' : 'var(--text-secondary)' }}>
                {ach.label}
              </span>
            </div>
          ))}
        </div>
      </motion.div>
    </motion.div>
  );
}
