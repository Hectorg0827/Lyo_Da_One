'use client';

import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { ChevronLeft } from 'lucide-react';
import { Course } from '@/types';
import CoursePlayer from '@/components/courses/CoursePlayer';

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
              { id: 'b10', type: 'quiz', content: JSON.stringify({
                id: 'q1', title: 'Linear Regression Quiz',
                questions: [
                  { id: 'qq1', question: 'What does linear regression predict?', type: 'multiple_choice', options: ['Categories', 'Continuous values', 'Clusters', 'Probabilities'], correctAnswer: 1, explanation: 'Linear regression predicts continuous numerical values, making it a regression algorithm.' },
                  { id: 'qq2', question: 'Linear regression can only model linear relationships.', type: 'true_false', options: ['True', 'False'], correctAnswer: 0, explanation: 'True - linear regression models linear relationships. For non-linear, we need polynomial regression or other methods.' },
                ],
              }) },
            ],
          },
          {
            id: 'l4', title: 'Decision Trees', type: 'quiz', duration: 20, order: 2, isCompleted: false,
            content: [
              { id: 'b11', type: 'heading', content: 'Decision Trees', metadata: { level: 1 } },
              { id: 'b12', type: 'text', content: 'Decision trees are a non-parametric supervised learning method used for classification and regression.' },
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
              { id: 'b13', type: 'heading', content: 'Neural Networks', metadata: { level: 1 } },
              { id: 'b14', type: 'text', content: 'Neural networks are computing systems inspired by biological neural networks in animal brains.' },
              { id: 'b15', type: 'flashcard', content: JSON.stringify({ front: 'What is a neuron in a neural network?', back: 'A mathematical function that receives inputs, applies weights, adds a bias, and passes the result through an activation function to produce an output.', category: 'Neural Networks', mastery: 0 }) },
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
          { id: 'l6', title: 'Components & JSX', type: 'text', duration: 20, order: 1, isCompleted: true, content: [{ id: 'b16', type: 'text', content: 'React components are the building blocks of any React application.' }] },
        ],
      },
      {
        id: 'm5', title: 'Next.js App Router', description: 'Modern routing', order: 2, isCompleted: false,
        lessons: [
          { id: 'l7', title: 'File-based Routing', type: 'text', duration: 25, order: 1, isCompleted: false, content: [{ id: 'b17', type: 'text', content: 'Next.js uses file-based routing in the app directory.' }] },
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
          { id: 'l8', title: 'Array Basics', type: 'text', duration: 15, order: 1, isCompleted: false, content: [{ id: 'b18', type: 'text', content: 'Arrays are the most fundamental data structure.' }] },
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
          { id: 'l9', title: 'Color Theory', type: 'text', duration: 20, order: 1, isCompleted: true, content: [{ id: 'b19', type: 'text', content: 'Color theory is essential for great design.' }] },
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
          { id: 'l10', title: 'Variables & Types', type: 'text', duration: 15, order: 1, isCompleted: false, content: [{ id: 'b20', type: 'text', content: 'Python is a dynamically typed language.' }] },
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
          { id: 'l11', title: 'What is Blockchain?', type: 'text', duration: 20, order: 1, isCompleted: false, content: [{ id: 'b21', type: 'text', content: 'Blockchain is a distributed ledger technology.' }] },
        ],
      },
    ],
  },
];

// ── Component ─────────────────────────────────────────────────────────────────

interface CourseDetailPageProps {
  params: { id: string };
}

export default function CourseDetailPage({ params }: CourseDetailPageProps) {
  const router = useRouter();
  const course = MOCK_COURSES.find((c) => c.id === params.id) ?? null;

  if (!course) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-950 via-gray-900 to-gray-950 flex items-center justify-center">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="flex flex-col items-center gap-5 text-center px-4"
        >
          <div className="w-20 h-20 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center">
            <ChevronLeft className="w-10 h-10 text-white/20" />
          </div>
          <div>
            <h2 className="text-white text-xl font-bold">Course not found</h2>
            <p className="text-white/40 text-sm mt-1">The course you&apos;re looking for doesn&apos;t exist or has been removed.</p>
          </div>
          <button
            onClick={() => router.push('/courses')}
            className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-lyo-600 hover:bg-lyo-500 text-white text-sm font-semibold transition-colors"
          >
            <ChevronLeft className="w-4 h-4" />
            Back to Courses
          </button>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="h-screen overflow-hidden">
      <CoursePlayer
        course={course}
        onBack={() => router.push('/courses')}
      />
    </div>
  );
}
