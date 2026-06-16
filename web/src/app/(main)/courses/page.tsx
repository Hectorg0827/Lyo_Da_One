'use client';

import { useState, useMemo } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, BookOpen, Sparkles, X } from 'lucide-react';
import { Course } from '@/types';
import { cn } from '@/lib/utils';
import CourseCard from '@/components/courses/CourseCard';

// ── Mock Data ─────────────────────────────────────────────────────────────────

const MOCK_COURSES: Course[] = [
  {
    id: '1',
    title: 'Machine Learning Fundamentals',
    description: 'Learn ML from scratch with hands-on projects and real-world examples.',
    thumbnail: undefined as unknown as string,
    author: { id: 'u1', displayName: 'Dr. Sarah Chen', username: 'sarahchen', avatar: undefined as unknown as string, email: '', bio: '', role: 'creator', interests: [], learningGoals: [], streak: 0, xp: 0, level: 0, coursesCompleted: 0, followersCount: 0, followingCount: 0, createdAt: '', isPremium: true },
    category: 'AI & ML',
    tags: ['python', 'ml', 'data-science'],
    difficulty: 'intermediate',
    estimatedDuration: 480,
    enrolledCount: 12400,
    rating: 4.8,
    reviewCount: 892,
    progress: 65,
    isAIGenerated: false,
    createdAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
    modules: [
      {
        id: 'm1', title: 'Introduction to ML', description: 'Core concepts', order: 1, isCompleted: true,
        lessons: [
          {
            id: 'l1', title: 'What is Machine Learning?', type: 'text', duration: 15, order: 1, isCompleted: true,
            content: [
              { id: 'b1', type: 'heading', content: 'What is Machine Learning?', metadata: { level: 1 } },
              { id: 'b2', type: 'text', content: 'Machine learning is a subset of artificial intelligence that enables systems to learn and improve from experience without being explicitly programmed. It focuses on developing computer programs that can access data and use it to learn for themselves.' },
              { id: 'b3', type: 'analogy', content: 'Think of ML like teaching a child to recognize cats. Instead of giving them a rulebook, you show them thousands of pictures of cats until they can identify one on their own.' },
              { id: 'b4', type: 'heading', content: 'Types of Machine Learning', metadata: { level: 2 } },
              { id: 'b5', type: 'summary', content: 'Supervised Learning: Training with labeled data\nUnsupervised Learning: Finding patterns in unlabeled data\nReinforcement Learning: Learning through rewards and penalties' },
            ],
          },
          {
            id: 'l2', title: 'Python for ML', type: 'text', duration: 20, order: 2, isCompleted: true,
            content: [
              { id: 'b6', type: 'heading', content: 'Python Setup', metadata: { level: 1 } },
              { id: 'b7', type: 'code', content: 'import numpy as np\nimport pandas as pd\nfrom sklearn.model_selection import train_test_split\n\n# Load dataset\ndata = pd.read_csv("data.csv")\nX = data.drop("target", axis=1)\ny = data["target"]\n\n# Split data\nX_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)', metadata: { language: 'python' } },
            ],
          },
        ],
      },
      {
        id: 'm2', title: 'Supervised Learning', description: 'Classification and regression', order: 2, isCompleted: false,
        lessons: [
          {
            id: 'l3', title: 'Linear Regression', type: 'text', duration: 25, order: 1, isCompleted: false,
            content: [
              { id: 'b8', type: 'heading', content: 'Linear Regression', metadata: { level: 1 } },
              { id: 'b9', type: 'text', content: 'Linear regression is one of the most fundamental algorithms in machine learning. It models the relationship between a dependent variable and one or more independent variables.' },
            ],
          },
          {
            id: 'l4', title: 'Decision Trees', type: 'quiz', duration: 20, order: 2, isCompleted: false,
            content: [
              { id: 'b10', type: 'heading', content: 'Decision Trees', metadata: { level: 1 } },
              { id: 'b11', type: 'text', content: 'Decision trees are a non-parametric supervised learning method used for classification and regression.' },
            ],
          },
        ],
      },
      {
        id: 'm3', title: 'Neural Networks', description: 'Deep learning basics', order: 3, isCompleted: false,
        lessons: [
          {
            id: 'l5', title: 'Introduction to Neural Nets', type: 'text', duration: 30, order: 1, isCompleted: false,
            content: [
              { id: 'b12', type: 'heading', content: 'Neural Networks', metadata: { level: 1 } },
              { id: 'b13', type: 'text', content: 'Neural networks are computing systems inspired by biological neural networks in animal brains.' },
            ],
          },
        ],
      },
    ],
  },
  {
    id: '2',
    title: 'React & Next.js Mastery',
    description: 'Build production-grade web apps with React 18 and Next.js 14.',
    thumbnail: undefined as unknown as string,
    author: { id: 'u2', displayName: 'Alex Rivera', username: 'alexrivera', avatar: undefined as unknown as string, email: '', bio: '', role: 'creator', interests: [], learningGoals: [], streak: 0, xp: 0, level: 0, coursesCompleted: 0, followersCount: 0, followingCount: 0, createdAt: '', isPremium: false },
    category: 'Web Dev',
    tags: ['react', 'nextjs', 'typescript'],
    difficulty: 'intermediate',
    estimatedDuration: 360,
    enrolledCount: 8900,
    rating: 4.9,
    reviewCount: 654,
    progress: 30,
    isAIGenerated: true,
    createdAt: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString(),
    modules: [
      {
        id: 'm4', title: 'React Fundamentals', description: 'Core React concepts', order: 1, isCompleted: true,
        lessons: [
          { id: 'l6', title: 'Components & JSX', type: 'text', duration: 20, order: 1, isCompleted: true, content: [{ id: 'b14', type: 'text', content: 'React components are the building blocks of any React application.' }] },
        ],
      },
      {
        id: 'm5', title: 'Next.js App Router', description: 'Modern routing', order: 2, isCompleted: false,
        lessons: [
          { id: 'l7', title: 'File-based Routing', type: 'text', duration: 25, order: 1, isCompleted: false, content: [{ id: 'b15', type: 'text', content: 'Next.js uses file-based routing in the app directory.' }] },
        ],
      },
    ],
  },
  {
    id: '3',
    title: 'Data Structures & Algorithms',
    description: 'Master DSA for coding interviews and competitive programming.',
    thumbnail: undefined as unknown as string,
    author: { id: 'u3', displayName: 'Prof. James Kim', username: 'jameskim', avatar: undefined as unknown as string, email: '', bio: '', role: 'creator', interests: [], learningGoals: [], streak: 0, xp: 0, level: 0, coursesCompleted: 0, followersCount: 0, followingCount: 0, createdAt: '', isPremium: true },
    category: 'Computer Science',
    tags: ['algorithms', 'dsa', 'interviews'],
    difficulty: 'advanced',
    estimatedDuration: 600,
    enrolledCount: 24000,
    rating: 4.7,
    reviewCount: 1890,
    progress: undefined,
    isAIGenerated: false,
    createdAt: new Date(Date.now() - 60 * 24 * 60 * 60 * 1000).toISOString(),
    modules: [
      {
        id: 'm6', title: 'Arrays & Strings', description: '', order: 1, isCompleted: false,
        lessons: [
          { id: 'l8', title: 'Array Basics', type: 'text', duration: 15, order: 1, isCompleted: false, content: [{ id: 'b16', type: 'text', content: 'Arrays are the most fundamental data structure.' }] },
        ],
      },
    ],
  },
  {
    id: '4',
    title: 'UI/UX Design Principles',
    description: 'Create beautiful, user-centered designs with Figma and modern principles.',
    thumbnail: undefined as unknown as string,
    author: { id: 'u4', displayName: 'Maya Johnson', username: 'mayaj', avatar: undefined as unknown as string, email: '', bio: '', role: 'creator', interests: [], learningGoals: [], streak: 0, xp: 0, level: 0, coursesCompleted: 0, followersCount: 0, followingCount: 0, createdAt: '', isPremium: false },
    category: 'Design',
    tags: ['design', 'figma', 'ux'],
    difficulty: 'beginner',
    estimatedDuration: 240,
    enrolledCount: 5600,
    rating: 4.6,
    reviewCount: 423,
    progress: 100,
    isAIGenerated: false,
    createdAt: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString(),
    modules: [
      {
        id: 'm7', title: 'Design Basics', description: '', order: 1, isCompleted: true,
        lessons: [
          { id: 'l9', title: 'Color Theory', type: 'text', duration: 20, order: 1, isCompleted: true, content: [{ id: 'b17', type: 'text', content: 'Color theory is essential for great design.' }] },
        ],
      },
    ],
  },
  {
    id: '5',
    title: 'Python Automation & Scripting',
    description: 'Automate repetitive tasks and build powerful scripts with Python.',
    thumbnail: undefined as unknown as string,
    author: { id: 'u5', displayName: 'Li Wei', username: 'liwei', avatar: undefined as unknown as string, email: '', bio: '', role: 'creator', interests: [], learningGoals: [], streak: 0, xp: 0, level: 0, coursesCompleted: 0, followersCount: 0, followingCount: 0, createdAt: '', isPremium: false },
    category: 'Programming',
    tags: ['python', 'automation', 'scripting'],
    difficulty: 'beginner',
    estimatedDuration: 180,
    enrolledCount: 7800,
    rating: 4.5,
    reviewCount: 567,
    progress: undefined,
    isAIGenerated: true,
    createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString(),
    modules: [
      {
        id: 'm8', title: 'Python Basics', description: '', order: 1, isCompleted: false,
        lessons: [
          { id: 'l10', title: 'Variables & Types', type: 'text', duration: 15, order: 1, isCompleted: false, content: [{ id: 'b18', type: 'text', content: 'Python is a dynamically typed language.' }] },
        ],
      },
    ],
  },
  {
    id: '6',
    title: 'Blockchain & Web3 Development',
    description: 'Build decentralized applications with Solidity and Ethereum.',
    thumbnail: undefined as unknown as string,
    author: { id: 'u6', displayName: 'Crypto Dev', username: 'cryptodev', avatar: undefined as unknown as string, email: '', bio: '', role: 'creator', interests: [], learningGoals: [], streak: 0, xp: 0, level: 0, coursesCompleted: 0, followersCount: 0, followingCount: 0, createdAt: '', isPremium: true },
    category: 'Blockchain',
    tags: ['web3', 'solidity', 'ethereum'],
    difficulty: 'advanced',
    estimatedDuration: 420,
    enrolledCount: 3200,
    rating: 4.4,
    reviewCount: 234,
    progress: undefined,
    isAIGenerated: false,
    createdAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
    modules: [
      {
        id: 'm9', title: 'Blockchain Basics', description: '', order: 1, isCompleted: false,
        lessons: [
          { id: 'l11', title: 'What is Blockchain?', type: 'text', duration: 20, order: 1, isCompleted: false, content: [{ id: 'b19', type: 'text', content: 'Blockchain is a distributed ledger technology.' }] },
        ],
      },
    ],
  },
];

// Hardcoded bookmarked IDs
const BOOKMARKED_IDS = new Set(['2', '5']);

// ── Types ─────────────────────────────────────────────────────────────────────

type TabId = 'inProgress' | 'completed' | 'bookmarked' | 'browse';
type DifficultyFilter = 'all' | 'beginner' | 'intermediate' | 'advanced';

const TABS: { id: TabId; label: string }[] = [
  { id: 'inProgress', label: 'In Progress' },
  { id: 'completed', label: 'Completed' },
  { id: 'bookmarked', label: 'Bookmarked' },
  { id: 'browse', label: 'Browse' },
];

const DIFFICULTY_FILTERS: { id: DifficultyFilter; label: string }[] = [
  { id: 'all', label: 'All Levels' },
  { id: 'beginner', label: 'Beginner' },
  { id: 'intermediate', label: 'Intermediate' },
  { id: 'advanced', label: 'Advanced' },
];

// ── Component ─────────────────────────────────────────────────────────────────

export default function CoursesPage() {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<TabId>('inProgress');
  const [searchQuery, setSearchQuery] = useState('');
  const [difficultyFilter, setDifficultyFilter] = useState<DifficultyFilter>('all');

  // Derive tab-specific lists
  const tabCourses = useMemo<Course[]>(() => {
    switch (activeTab) {
      case 'inProgress':
        return MOCK_COURSES.filter((c) => c.progress !== undefined && c.progress > 0 && c.progress < 100);
      case 'completed':
        return MOCK_COURSES.filter((c) => c.progress === 100);
      case 'bookmarked':
        return MOCK_COURSES.filter((c) => BOOKMARKED_IDS.has(c.id));
      case 'browse':
      default:
        return MOCK_COURSES;
    }
  }, [activeTab]);

  // Apply search + difficulty filter
  const filteredCourses = useMemo<Course[]>(() => {
    return tabCourses.filter((c) => {
      const matchesSearch =
        searchQuery.trim() === '' ||
        c.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.tags.some((t) => t.toLowerCase().includes(searchQuery.toLowerCase()));
      const matchesDifficulty = difficultyFilter === 'all' || c.difficulty === difficultyFilter;
      return matchesSearch && matchesDifficulty;
    });
  }, [tabCourses, searchQuery, difficultyFilter]);

  const handleCourseClick = (course: Course) => {
    router.push(`/courses/${course.id}`);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-gray-950">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8">

        {/* ── Page Header ── */}
        <motion.div
          initial={{ opacity: 0, y: -12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="flex items-center justify-between mb-8"
        >
          <div>
            <h1 className="text-3xl font-bold text-white tracking-tight">My Courses</h1>
            <p className="text-white/40 text-sm mt-1">
              {MOCK_COURSES.filter((c) => c.progress !== undefined && c.progress > 0 && c.progress < 100).length} in progress
              &nbsp;·&nbsp;
              {MOCK_COURSES.filter((c) => c.progress === 100).length} completed
            </p>
          </div>
          <Link href="/chat">
            <motion.button
              whileHover={{ scale: 1.03 }}
              whileTap={{ scale: 0.97 }}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-gradient-to-r from-lyo-600 to-lyo-500 text-white text-sm font-semibold shadow-lg shadow-lyo-600/25 hover:shadow-lyo-500/40 transition-shadow"
            >
              <Sparkles className="w-4 h-4" />
              Create with AI
            </motion.button>
          </Link>
        </motion.div>

        {/* ── Tab Row ── */}
        <motion.div
          initial={{ opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3, delay: 0.05 }}
          className="flex items-center gap-2 mb-6"
        >
          {TABS.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={cn(
                'px-4 py-2 rounded-full text-sm font-medium transition-all duration-200',
                activeTab === tab.id
                  ? 'bg-lyo-500 text-white shadow-md shadow-lyo-500/30'
                  : 'bg-white/5 text-white/50 hover:bg-white/10 hover:text-white/80 border border-white/10',
              )}
            >
              {tab.label}
            </button>
          ))}
        </motion.div>

        {/* ── Search + Difficulty Filters ── */}
        <motion.div
          initial={{ opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3, delay: 0.1 }}
          className="mb-6 space-y-3"
        >
          {/* Search bar */}
          <div className="relative">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30 pointer-events-none" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search courses..."
              className={cn(
                'w-full bg-white/5 border border-white/10 rounded-xl',
                'pl-10 pr-10 py-2.5 text-sm text-white placeholder:text-white/30',
                'focus:outline-none focus:border-lyo-500/50 focus:bg-white/8 transition-all',
              )}
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-3.5 top-1/2 -translate-y-1/2 text-white/30 hover:text-white/60 transition-colors"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>

          {/* Difficulty filters */}
          <div className="flex items-center gap-2 flex-wrap">
            {DIFFICULTY_FILTERS.map((f) => (
              <button
                key={f.id}
                onClick={() => setDifficultyFilter(f.id)}
                className={cn(
                  'px-3 py-1.5 rounded-lg text-xs font-medium transition-all duration-200',
                  difficultyFilter === f.id
                    ? 'bg-lyo-500/20 text-lyo-400 border border-lyo-500/40'
                    : 'bg-white/5 text-white/40 border border-white/10 hover:bg-white/10 hover:text-white/60',
                )}
              >
                {f.label}
              </button>
            ))}
          </div>
        </motion.div>

        {/* ── Course Grid ── */}
        <AnimatePresence mode="wait">
          {filteredCourses.length > 0 ? (
            <motion.div
              key={`${activeTab}-${searchQuery}-${difficultyFilter}`}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.25 }}
              className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6"
            >
              {filteredCourses.map((course, i) => (
                <motion.div
                  key={course.id}
                  initial={{ opacity: 0, y: 16 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.25, delay: i * 0.04 }}
                >
                  <CourseCard
                    course={course}
                    onClick={() => handleCourseClick(course)}
                  />
                </motion.div>
              ))}
            </motion.div>
          ) : (
            <motion.div
              key="empty"
              initial={{ opacity: 0, scale: 0.96 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.96 }}
              transition={{ duration: 0.2 }}
              className="flex flex-col items-center justify-center py-24 gap-4"
            >
              <div className="w-16 h-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center">
                <BookOpen className="w-8 h-8 text-white/20" />
              </div>
              <div className="text-center">
                <p className="text-white/60 font-medium">No courses found</p>
                <p className="text-white/30 text-sm mt-1">
                  {searchQuery
                    ? `No results for "${searchQuery}"`
                    : activeTab === 'inProgress'
                    ? 'You have no courses in progress yet.'
                    : activeTab === 'completed'
                    ? 'You have not completed any courses yet.'
                    : activeTab === 'bookmarked'
                    ? 'You have no bookmarked courses.'
                    : 'No courses match the selected filters.'}
                </p>
              </div>
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery('')}
                  className="text-lyo-400 text-sm hover:text-lyo-300 transition-colors"
                >
                  Clear search
                </button>
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
