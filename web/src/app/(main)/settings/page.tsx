'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import {
  User,
  Mail,
  AtSign,
  Pencil,
  Check,
  X,
  BookOpen,
  Bell,
  Shield,
  Palette,
  Info,
  Trash2,
  ChevronRight,
  Moon,
  Sun,
  AlertTriangle,
  Lock,
  Globe,
  Eye,
  EyeOff,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { api } from '@/lib/api';
import { useAuthStore } from '@/stores/auth-store';

// ── Animation variants ─────────────────────────────────────────────────────────

const containerVariants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { staggerChildren: 0.06 } },
};

const itemVariants = {
  hidden: { opacity: 0, y: 16 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] } },
};

// ── Section card ───────────────────────────────────────────────────────────────

function SectionCard({
  title,
  icon: Icon,
  iconColor,
  children,
}: {
  title: string;
  icon: React.ComponentType<{ size?: number | string; className?: string; style?: React.CSSProperties }>;
  iconColor: string;
  children: React.ReactNode;
}) {
  return (
    <motion.div variants={itemVariants} className="glass-card overflow-hidden">
      <div
        className="flex items-center gap-3 px-5 py-4"
        style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}
      >
        <div
          className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0"
          style={{ backgroundColor: `${iconColor}20` }}
        >
          <Icon size={16} style={{ color: iconColor }} />
        </div>
        <h2 className="text-sm font-bold text-primary">{title}</h2>
      </div>
      <div className="divide-y divide-white/5">
        {children}
      </div>
    </motion.div>
  );
}

// ── Toggle switch ──────────────────────────────────────────────────────────────

function Toggle({ value, onChange }: { value: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      onClick={() => onChange(!value)}
      className="relative inline-flex w-11 h-6 items-center rounded-full transition-all duration-300 shrink-0"
      style={{ background: value ? '#6c63ff' : 'rgba(255,255,255,0.12)' }}
    >
      <span
        className="inline-block w-4 h-4 bg-white rounded-full shadow-sm transition-all duration-300"
        style={{ transform: value ? 'translateX(26px)' : 'translateX(4px)' }}
      />
    </button>
  );
}

// ── Settings row ───────────────────────────────────────────────────────────────

function SettingsRow({
  label,
  description,
  rightSlot,
}: {
  label: string;
  description?: string;
  rightSlot?: React.ReactNode;
}) {
  return (
    <div
      className="flex items-center justify-between gap-3 px-5 py-4"
      style={{ borderBottomWidth: 1, borderColor: 'rgba(255,255,255,0.04)' }}
    >
      <div className="min-w-0 flex-1">
        <p className="text-sm font-medium text-primary">{label}</p>
        {description && <p className="text-xs text-secondary mt-0.5">{description}</p>}
      </div>
      {rightSlot}
    </div>
  );
}

// ── Editable field ─────────────────────────────────────────────────────────────

function EditableField({
  label,
  value,
  onSave,
  icon: Icon,
  type = 'text',
}: {
  label: string;
  value: string;
  onSave: (v: string) => void;
  icon: React.ComponentType<{ size?: number | string; className?: string }>;
  type?: string;
}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(value);

  function save() {
    onSave(draft);
    setEditing(false);
  }

  function cancel() {
    setDraft(value);
    setEditing(false);
  }

  return (
    <div
      className="flex items-center gap-3 px-5 py-4"
      style={{ borderBottomWidth: 1, borderColor: 'rgba(255,255,255,0.04)' }}
    >
      <Icon size={15} className="text-secondary shrink-0" />
      <div className="flex-1 min-w-0">
        <p className="text-[10px] font-semibold text-secondary uppercase tracking-wide mb-0.5">{label}</p>
        {editing ? (
          <input
            autoFocus
            type={type}
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            className="w-full bg-transparent text-sm text-primary outline-none border-b border-[#6c63ff] pb-0.5"
            onKeyDown={(e) => {
              if (e.key === 'Enter') save();
              if (e.key === 'Escape') cancel();
            }}
          />
        ) : (
          <p className="text-sm text-primary truncate">{value}</p>
        )}
      </div>
      {editing ? (
        <div className="flex items-center gap-1.5 shrink-0">
          <button onClick={save} className="p-1.5 rounded-lg text-[#22c55e] hover:bg-[#22c55e]/10 transition-colors">
            <Check size={14} />
          </button>
          <button onClick={cancel} className="p-1.5 rounded-lg text-secondary hover:bg-white/[0.06] transition-colors">
            <X size={14} />
          </button>
        </div>
      ) : (
        <button
          onClick={() => setEditing(true)}
          className="p-1.5 rounded-lg text-secondary hover:text-primary hover:bg-white/[0.06] transition-all duration-150 shrink-0"
        >
          <Pencil size={13} />
        </button>
      )}
    </div>
  );
}

// ── Interest tag ───────────────────────────────────────────────────────────────

const ALL_INTERESTS = ['AI', 'Machine Learning', 'Design', 'Music', 'Programming', 'Photography', 'Math', 'Physics', 'Biology', 'History', 'Languages', 'Finance'];

function InterestTag({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'text-xs font-semibold px-3 py-1.5 rounded-full transition-all duration-200',
        active
          ? 'text-white'
          : 'text-secondary hover:text-primary'
      )}
      style={
        active
          ? { background: 'linear-gradient(135deg, #6c63ff, #8b5cf6)' }
          : { background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.08)' }
      }
    >
      {label}
    </button>
  );
}

// ── Main page ──────────────────────────────────────────────────────────────────

export default function SettingsPage() {
  const { user, updateUser, logout } = useAuthStore();

  // Account
  const [displayName, setDisplayName] = useState(user?.displayName ?? '');
  const [email] = useState(user?.email ?? '');
  const [username] = useState(user?.username ?? '');

  // Learning preferences
  const [interests, setInterests] = useState<string[]>(user?.interests ?? []);
  const [difficulty, setDifficulty] = useState<'beginner' | 'intermediate' | 'advanced'>('intermediate');
  const [dailyGoal, setDailyGoal] = useState(30);

  // Notifications
  const [notifToggles, setNotifToggles] = useState({
    likes: true,
    comments: true,
    follows: true,
    achievements: true,
    courseUpdates: true,
    weeklyDigest: false,
    promotions: false,
  });

  // Privacy
  const [profilePublic, setProfilePublic] = useState(true);
  const [showOnlineStatus, setShowOnlineStatus] = useState(true);
  const [showLearningActivity, setShowLearningActivity] = useState(true);

  // Appearance
  const [darkMode, setDarkMode] = useState(true);
  const [fontSize, setFontSize] = useState<'small' | 'medium' | 'large'>('medium');

  // Delete modal
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState('');

  function toggleInterest(tag: string) {
    setInterests((prev) =>
      prev.includes(tag) ? prev.filter((t) => t !== tag) : [...prev, tag]
    );
  }

  function toggleNotif(key: keyof typeof notifToggles) {
    setNotifToggles((prev) => ({ ...prev, [key]: !prev[key] }));
  }

  async function saveDisplayName(v: string) {
    setDisplayName(v);
    updateUser({ displayName: v });
    try {
      await api.auth.updateProfile({ full_name: v });
    } catch {
      // profile update failed silently — local state already updated
    }
  }

  return (
    <>
      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="visible"
        className="max-w-2xl mx-auto px-4 sm:px-6 py-6 space-y-5"
      >
        {/* Page header */}
        <motion.div variants={itemVariants}>
          <h1 className="text-xl font-black text-primary">Settings</h1>
          <p className="text-sm text-secondary mt-0.5">Manage your account and preferences</p>
        </motion.div>

        {/* ── Account ──────────────────────────────────────── */}
        <SectionCard title="Account" icon={User} iconColor="#6c63ff">
          <EditableField
            label="Display Name"
            value={displayName}
            onSave={saveDisplayName}
            icon={User}
          />
          <EditableField
            label="Email"
            value={email}
            onSave={() => {}}
            icon={Mail}
            type="email"
          />
          <EditableField
            label="Username"
            value={`@${username}`}
            onSave={() => {}}
            icon={AtSign}
          />
          <SettingsRow
            label="Change Password"
            description="Update your account password"
            rightSlot={
              <button className="flex items-center gap-1 text-xs text-secondary hover:text-primary transition-colors">
                <Lock size={13} /> Change <ChevronRight size={13} />
              </button>
            }
          />
          {user?.isPremium && (
            <SettingsRow
              label="LYO Premium"
              description="Manage your premium subscription"
              rightSlot={
                <span
                  className="text-[10px] font-bold px-2.5 py-1 rounded-full"
                  style={{ background: 'linear-gradient(135deg, #f59e0b, #ef4444)', color: '#fff' }}
                >
                  ACTIVE
                </span>
              }
            />
          )}
        </SectionCard>

        {/* ── Learning Preferences ─────────────────────────── */}
        <SectionCard title="Learning Preferences" icon={BookOpen} iconColor="#22c55e">
          {/* Interests */}
          <div className="px-5 py-4" style={{ borderBottomWidth: 1, borderColor: 'rgba(255,255,255,0.04)' }}>
            <p className="text-sm font-medium text-primary mb-3">Interests</p>
            <div className="flex flex-wrap gap-2">
              {ALL_INTERESTS.map((tag) => (
                <InterestTag
                  key={tag}
                  label={tag}
                  active={interests.includes(tag)}
                  onClick={() => toggleInterest(tag)}
                />
              ))}
            </div>
          </div>

          {/* Difficulty */}
          <div className="px-5 py-4" style={{ borderBottomWidth: 1, borderColor: 'rgba(255,255,255,0.04)' }}>
            <p className="text-sm font-medium text-primary mb-3">Preferred Difficulty</p>
            <div className="flex gap-2">
              {(['beginner', 'intermediate', 'advanced'] as const).map((d) => {
                const colors = { beginner: '#22c55e', intermediate: '#6c63ff', advanced: '#ef4444' };
                const isActive = difficulty === d;
                return (
                  <button
                    key={d}
                    onClick={() => setDifficulty(d)}
                    className="flex-1 py-2 rounded-xl text-xs font-semibold capitalize transition-all duration-200"
                    style={
                      isActive
                        ? { background: `${colors[d]}20`, border: `1px solid ${colors[d]}40`, color: colors[d] }
                        : { background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', color: '#8888aa' }
                    }
                  >
                    {d}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Daily goal */}
          <div className="px-5 py-4">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm font-medium text-primary">Daily Learning Goal</p>
              <span className="text-sm font-bold" style={{ color: '#6c63ff' }}>{dailyGoal} min</span>
            </div>
            <input
              type="range"
              min={5}
              max={120}
              step={5}
              value={dailyGoal}
              onChange={(e) => setDailyGoal(Number(e.target.value))}
              className="w-full accent-[#6c63ff]"
            />
            <div className="flex justify-between text-[10px] text-secondary mt-1">
              <span>5 min</span>
              <span>120 min</span>
            </div>
          </div>
        </SectionCard>

        {/* ── Notifications ────────────────────────────────── */}
        <SectionCard title="Notifications" icon={Bell} iconColor="#f59e0b">
          {(Object.keys(notifToggles) as (keyof typeof notifToggles)[]).map((key) => {
            const labels: Record<keyof typeof notifToggles, { label: string; desc: string }> = {
              likes: { label: 'Likes', desc: 'When someone likes your posts or clips' },
              comments: { label: 'Comments', desc: 'When someone comments on your content' },
              follows: { label: 'New Followers', desc: 'When someone follows you' },
              achievements: { label: 'Achievements', desc: 'When you unlock a new achievement' },
              courseUpdates: { label: 'Course Updates', desc: 'Updates on courses you\'re enrolled in' },
              weeklyDigest: { label: 'Weekly Digest', desc: 'Summary of your learning week' },
              promotions: { label: 'Promotions', desc: 'Special offers and LYO news' },
            };
            return (
              <SettingsRow
                key={key}
                label={labels[key].label}
                description={labels[key].desc}
                rightSlot={
                  <Toggle value={notifToggles[key]} onChange={() => toggleNotif(key)} />
                }
              />
            );
          })}
        </SectionCard>

        {/* ── Privacy ──────────────────────────────────────── */}
        <SectionCard title="Privacy" icon={Shield} iconColor="#3b82f6">
          <SettingsRow
            label="Public Profile"
            description="Anyone can view your profile and content"
            rightSlot={
              <div className="flex items-center gap-2">
                {profilePublic ? <Globe size={14} className="text-secondary" /> : <Lock size={14} className="text-secondary" />}
                <Toggle value={profilePublic} onChange={setProfilePublic} />
              </div>
            }
          />
          <SettingsRow
            label="Online Status"
            description="Show when you're active on LYO"
            rightSlot={
              <div className="flex items-center gap-2">
                {showOnlineStatus ? <Eye size={14} className="text-secondary" /> : <EyeOff size={14} className="text-secondary" />}
                <Toggle value={showOnlineStatus} onChange={setShowOnlineStatus} />
              </div>
            }
          />
          <SettingsRow
            label="Learning Activity"
            description="Let others see your courses and progress"
            rightSlot={<Toggle value={showLearningActivity} onChange={setShowLearningActivity} />}
          />
          <SettingsRow
            label="Blocked Users"
            description="Manage users you've blocked"
            rightSlot={
              <button className="flex items-center gap-1 text-xs text-secondary hover:text-primary transition-colors">
                Manage <ChevronRight size={13} />
              </button>
            }
          />
        </SectionCard>

        {/* ── Appearance ───────────────────────────────────── */}
        <SectionCard title="Appearance" icon={Palette} iconColor="#ec4899">
          <SettingsRow
            label="Dark Mode"
            description="Use dark theme throughout the app"
            rightSlot={
              <div className="flex items-center gap-2">
                {darkMode ? <Moon size={14} className="text-secondary" /> : <Sun size={14} className="text-secondary" />}
                <Toggle value={darkMode} onChange={setDarkMode} />
              </div>
            }
          />
          <div className="px-5 py-4">
            <p className="text-sm font-medium text-primary mb-3">Font Size</p>
            <div className="flex gap-2">
              {(['small', 'medium', 'large'] as const).map((size) => (
                <button
                  key={size}
                  onClick={() => setFontSize(size)}
                  className="flex-1 py-2 rounded-xl text-xs font-semibold capitalize transition-all duration-200"
                  style={
                    fontSize === size
                      ? { background: 'rgba(236,72,153,0.15)', border: '1px solid rgba(236,72,153,0.3)', color: '#ec4899' }
                      : { background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', color: '#8888aa' }
                  }
                >
                  {size}
                </button>
              ))}
            </div>
          </div>
        </SectionCard>

        {/* ── About ────────────────────────────────────────── */}
        <SectionCard title="About" icon={Info} iconColor="#8888aa">
          <SettingsRow
            label="Version"
            rightSlot={<span className="text-xs text-secondary">1.0.0 (beta)</span>}
          />
          <SettingsRow
            label="Terms of Service"
            rightSlot={<ChevronRight size={15} className="text-secondary" />}
          />
          <SettingsRow
            label="Privacy Policy"
            rightSlot={<ChevronRight size={15} className="text-secondary" />}
          />
          <SettingsRow
            label="Contact Support"
            rightSlot={<ChevronRight size={15} className="text-secondary" />}
          />
        </SectionCard>

        {/* ── Danger zone ──────────────────────────────────── */}
        <motion.div
          variants={itemVariants}
          className="rounded-2xl overflow-hidden"
          style={{ border: '1px solid rgba(239,68,68,0.2)', background: 'rgba(239,68,68,0.04)' }}
        >
          <div
            className="flex items-center gap-3 px-5 py-4"
            style={{ borderBottom: '1px solid rgba(239,68,68,0.12)' }}
          >
            <div
              className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0"
              style={{ backgroundColor: 'rgba(239,68,68,0.15)' }}
            >
              <AlertTriangle size={16} style={{ color: '#ef4444' }} />
            </div>
            <h2 className="text-sm font-bold" style={{ color: '#ef4444' }}>Danger Zone</h2>
          </div>
          <div className="px-5 py-5">
            <p className="text-sm text-secondary mb-4 leading-relaxed">
              Deleting your account is permanent and cannot be undone. All your data, courses, and progress will be lost.
            </p>
            <button
              onClick={() => setShowDeleteModal(true)}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold transition-all duration-200 hover:opacity-90 active:scale-[0.97]"
              style={{ background: 'rgba(239,68,68,0.15)', border: '1px solid rgba(239,68,68,0.3)', color: '#ef4444' }}
            >
              <Trash2 size={15} />
              Delete Account
            </button>
          </div>
        </motion.div>

        <div className="h-4" />
      </motion.div>

      {/* ── Delete confirmation modal ─────────────────────── */}
      {showDeleteModal && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4"
          style={{ background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(8px)' }}
          onClick={() => setShowDeleteModal(false)}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            className="w-full max-w-sm rounded-2xl p-6 space-y-5"
            style={{ background: '#111118', border: '1px solid rgba(239,68,68,0.3)' }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="text-center space-y-2">
              <div
                className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto"
                style={{ background: 'rgba(239,68,68,0.15)' }}
              >
                <Trash2 size={24} style={{ color: '#ef4444' }} />
              </div>
              <h3 className="text-base font-black text-primary">Delete Account?</h3>
              <p className="text-sm text-secondary">
                This action is permanent. Type <strong className="text-primary">DELETE</strong> to confirm.
              </p>
            </div>
            <input
              value={deleteConfirm}
              onChange={(e) => setDeleteConfirm(e.target.value)}
              placeholder="Type DELETE"
              className="w-full px-4 py-3 rounded-xl bg-transparent text-sm text-primary placeholder:text-secondary outline-none"
              style={{ border: '1px solid rgba(255,255,255,0.1)' }}
            />
            <div className="flex gap-3">
              <button
                onClick={() => setShowDeleteModal(false)}
                className="flex-1 py-2.5 rounded-xl text-sm font-semibold text-secondary transition-colors hover:text-primary"
                style={{ background: 'rgba(255,255,255,0.06)' }}
              >
                Cancel
              </button>
              <button
                disabled={deleteConfirm !== 'DELETE'}
                onClick={() => { if (deleteConfirm === 'DELETE') logout(); }}
                className="flex-1 py-2.5 rounded-xl text-sm font-semibold text-white transition-all duration-200 disabled:opacity-40"
                style={{ background: '#ef4444' }}
              >
                Delete
              </button>
            </div>
          </motion.div>
        </div>
      )}
    </>
  );
}
