'use client';

import { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, ChevronLeft, ChevronRight, Heart, Send } from 'lucide-react';
import { useRouter } from 'next/navigation';

interface StorySlide {
  id: string;
  type: 'text' | 'course_completion' | 'achievement';
  gradient: string;
  text?: string;
  emoji?: string;
  subtitle?: string;
  duration: number;
}

interface StoryData {
  id: string;
  author: { name: string; avatar: string; username: string };
  slides: StorySlide[];
  timeAgo: string;
}

const mockStories: StoryData[] = [
  {
    id: 's1',
    author: { name: 'Sarah Chen', avatar: '', username: 'sarahcodes' },
    slides: [
      {
        id: 'sl1',
        type: 'course_completion',
        gradient: 'from-violet-600 via-purple-600 to-pink-500',
        emoji: '🎉',
        text: 'Just completed "Advanced Python Patterns"!',
        subtitle: '12 modules • 24 lessons • 8 quizzes passed',
        duration: 5,
      },
      {
        id: 'sl2',
        type: 'text',
        gradient: 'from-blue-600 via-indigo-600 to-violet-600',
        text: 'The decorator patterns section was mind-blowing. Totally changed how I think about code structure.',
        duration: 5,
      },
      {
        id: 'sl3',
        type: 'achievement',
        gradient: 'from-amber-500 via-orange-500 to-red-500',
        emoji: '🏆',
        text: 'Achievement Unlocked: Code Master',
        subtitle: 'Complete 10 programming courses • +500 XP',
        duration: 5,
      },
    ],
    timeAgo: '2h ago',
  },
  {
    id: 's2',
    author: { name: 'Alex Rivera', avatar: '', username: 'alexrivera' },
    slides: [
      {
        id: 'sl4',
        type: 'text',
        gradient: 'from-emerald-500 via-teal-500 to-cyan-500',
        text: 'Day 30 of my learning streak! 🔥\n\nConsistency is everything. Even 15 minutes a day adds up.',
        duration: 5,
      },
      {
        id: 'sl5',
        type: 'course_completion',
        gradient: 'from-pink-500 via-rose-500 to-red-500',
        emoji: '✅',
        text: 'Finished "UI/UX Fundamentals"',
        subtitle: '8 modules • 16 lessons • Certificate earned',
        duration: 5,
      },
    ],
    timeAgo: '4h ago',
  },
  {
    id: 's3',
    author: { name: 'Maya Patel', avatar: '', username: 'mayapaints' },
    slides: [
      {
        id: 'sl6',
        type: 'achievement',
        gradient: 'from-yellow-500 via-amber-500 to-orange-500',
        emoji: '⭐',
        text: 'Achievement Unlocked: Social Butterfly',
        subtitle: 'Help 50 community members • +300 XP',
        duration: 5,
      },
      {
        id: 'sl7',
        type: 'text',
        gradient: 'from-indigo-600 via-blue-600 to-sky-500',
        text: 'Pro tip: Teaching others is the fastest way to learn. Start sharing what you know!',
        duration: 5,
      },
      {
        id: 'sl8',
        type: 'text',
        gradient: 'from-fuchsia-600 via-pink-600 to-rose-500',
        text: 'Looking for study partners for the Data Science track. Drop a comment if interested! 📊',
        duration: 5,
      },
    ],
    timeAgo: '6h ago',
  },
];

function SlideContent({ slide }: { slide: StorySlide }) {
  if (slide.type === 'course_completion') {
    return (
      <div className="flex flex-col items-center justify-center text-center">
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ type: 'spring', bounce: 0.5, delay: 0.2 }}
          className="mb-6 text-7xl"
        >
          {slide.emoji}
        </motion.div>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="text-2xl font-bold text-white"
        >
          {slide.text}
        </motion.h2>
        {slide.subtitle && (
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6 }}
            className="mt-3 text-sm text-white/70"
          >
            {slide.subtitle}
          </motion.p>
        )}
        <motion.div
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.8 }}
          className="mt-8 rounded-full bg-white/20 px-6 py-2 text-sm font-medium text-white backdrop-blur-sm"
        >
          Course Completed ✨
        </motion.div>
      </div>
    );
  }

  if (slide.type === 'achievement') {
    return (
      <div className="flex flex-col items-center justify-center text-center">
        <motion.div
          initial={{ rotate: -180, scale: 0 }}
          animate={{ rotate: 0, scale: 1 }}
          transition={{ type: 'spring', bounce: 0.4, delay: 0.2 }}
          className="mb-6 flex h-24 w-24 items-center justify-center rounded-full bg-white/10 text-5xl backdrop-blur-sm ring-4 ring-white/20"
        >
          {slide.emoji}
        </motion.div>
        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
          className="text-2xl font-bold text-white"
        >
          {slide.text}
        </motion.h2>
        {slide.subtitle && (
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.7 }}
            className="mt-3 text-sm text-white/70"
          >
            {slide.subtitle}
          </motion.p>
        )}
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center px-8">
      <motion.p
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="whitespace-pre-line text-center text-xl font-medium leading-relaxed text-white"
      >
        {slide.text}
      </motion.p>
    </div>
  );
}

export default function StoriesPage() {
  const router = useRouter();
  const [storyIndex, setStoryIndex] = useState(0);
  const [slideIndex, setSlideIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [replyText, setReplyText] = useState('');

  const currentStory = mockStories[storyIndex];
  const currentSlide = currentStory?.slides[slideIndex];
  const slideDuration = (currentSlide?.duration || 5) * 1000;

  const goNext = useCallback(() => {
    if (slideIndex < currentStory.slides.length - 1) {
      setSlideIndex((i) => i + 1);
      setProgress(0);
    } else if (storyIndex < mockStories.length - 1) {
      setStoryIndex((i) => i + 1);
      setSlideIndex(0);
      setProgress(0);
    } else {
      router.back();
    }
  }, [slideIndex, storyIndex, currentStory, router]);

  const goPrev = useCallback(() => {
    if (slideIndex > 0) {
      setSlideIndex((i) => i - 1);
      setProgress(0);
    } else if (storyIndex > 0) {
      setStoryIndex((i) => i - 1);
      setSlideIndex(0);
      setProgress(0);
    }
  }, [slideIndex, storyIndex]);

  useEffect(() => {
    const interval = setInterval(() => {
      setProgress((p) => {
        if (p >= 100) {
          goNext();
          return 0;
        }
        return p + 100 / (slideDuration / 50);
      });
    }, 50);
    return () => clearInterval(interval);
  }, [slideDuration, goNext]);

  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight' || e.key === ' ') goNext();
      if (e.key === 'ArrowLeft') goPrev();
      if (e.key === 'Escape') router.back();
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [goNext, goPrev, router]);

  if (!currentStory || !currentSlide) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black">
      <div className="relative h-full w-full max-w-md">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentSlide.id}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
            className={`absolute inset-0 bg-gradient-to-br ${currentSlide.gradient}`}
          >
            <div className="flex h-full items-center justify-center p-6">
              <SlideContent slide={currentSlide} />
            </div>
          </motion.div>
        </AnimatePresence>

        {/* Progress bars */}
        <div className="absolute left-0 right-0 top-0 z-10 flex gap-1 p-3">
          {currentStory.slides.map((slide, i) => (
            <div key={slide.id} className="h-0.5 flex-1 rounded-full bg-white/30">
              <div
                className="h-full rounded-full bg-white transition-all duration-100"
                style={{
                  width: i < slideIndex ? '100%' : i === slideIndex ? `${progress}%` : '0%',
                }}
              />
            </div>
          ))}
        </div>

        {/* Author info */}
        <div className="absolute left-0 right-0 top-6 z-10 flex items-center gap-3 px-4">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-white/20 text-sm font-bold text-white backdrop-blur-sm">
            {currentStory.author.name[0]}
          </div>
          <div>
            <p className="text-sm font-semibold text-white">{currentStory.author.name}</p>
            <p className="text-xs text-white/60">{currentStory.timeAgo}</p>
          </div>
        </div>

        {/* Close button */}
        <button
          onClick={() => router.back()}
          className="absolute right-4 top-6 z-10 rounded-full bg-black/20 p-2 text-white backdrop-blur-sm transition hover:bg-black/40"
        >
          <X className="h-5 w-5" />
        </button>

        {/* Navigation zones */}
        <button
          onClick={goPrev}
          className="absolute bottom-20 left-0 top-20 z-10 w-1/3"
          aria-label="Previous"
        />
        <button
          onClick={goNext}
          className="absolute bottom-20 right-0 top-20 z-10 w-1/3"
          aria-label="Next"
        />

        {/* Navigation arrows (desktop) */}
        {(slideIndex > 0 || storyIndex > 0) && (
          <button
            onClick={goPrev}
            className="absolute left-2 top-1/2 z-10 hidden -translate-y-1/2 rounded-full bg-black/30 p-2 text-white backdrop-blur-sm hover:bg-black/50 md:block"
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
        )}
        <button
          onClick={goNext}
          className="absolute right-2 top-1/2 z-10 hidden -translate-y-1/2 rounded-full bg-black/30 p-2 text-white backdrop-blur-sm hover:bg-black/50 md:block"
        >
          <ChevronRight className="h-5 w-5" />
        </button>

        {/* Reply bar */}
        <div className="absolute bottom-4 left-4 right-4 z-10 flex items-center gap-2">
          <input
            type="text"
            value={replyText}
            onChange={(e) => setReplyText(e.target.value)}
            placeholder="Reply to story..."
            className="flex-1 rounded-full bg-white/10 px-4 py-2.5 text-sm text-white placeholder-white/40 backdrop-blur-sm outline-none focus:bg-white/20"
          />
          <button className="rounded-full bg-white/10 p-2.5 text-white backdrop-blur-sm hover:bg-white/20">
            <Heart className="h-5 w-5" />
          </button>
          {replyText && (
            <button className="rounded-full bg-lyo-600 p-2.5 text-white">
              <Send className="h-5 w-5" />
            </button>
          )}
        </div>
      </div>

      {/* Story indicators */}
      <div className="absolute bottom-4 flex gap-1.5">
        {mockStories.map((_, i) => (
          <button
            key={i}
            onClick={() => {
              setStoryIndex(i);
              setSlideIndex(0);
              setProgress(0);
            }}
            className={`h-1.5 rounded-full transition-all ${
              i === storyIndex ? 'w-6 bg-white' : 'w-1.5 bg-white/40'
            }`}
          />
        ))}
      </div>
    </div>
  );
}
