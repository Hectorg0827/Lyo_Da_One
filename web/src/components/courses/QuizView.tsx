'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle, XCircle, ChevronRight, RotateCcw, Trophy } from 'lucide-react';
import { Quiz, QuizQuestion } from '@/types';
import { cn } from '@/lib/utils';

interface QuizViewProps {
  quiz: Quiz;
  onComplete?: (score: number) => void;
  inline?: boolean;
}

export default function QuizView({ quiz, onComplete, inline = false }: QuizViewProps) {
  const [currentQuestion, setCurrentQuestion] = useState(0);
  const [selectedAnswers, setSelectedAnswers] = useState<Record<number, string | number>>({});
  const [showFeedback, setShowFeedback] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [score, setScore] = useState(0);

  const question = quiz.questions[currentQuestion];
  const totalQuestions = quiz.questions.length;
  const progress = ((currentQuestion + (showFeedback ? 1 : 0)) / totalQuestions) * 100;
  const hasSelected = selectedAnswers[currentQuestion] !== undefined;

  function handleSelect(value: string | number) {
    if (showFeedback) return;
    setSelectedAnswers((prev) => ({ ...prev, [currentQuestion]: value }));
  }

  function handleSubmit() {
    setShowFeedback(true);
  }

  function handleNext() {
    const isCorrect = selectedAnswers[currentQuestion] === question.correctAnswer;
    const newScore = score + (isCorrect ? 1 : 0);

    if (currentQuestion + 1 >= totalQuestions) {
      setScore(newScore);
      setIsComplete(true);
    } else {
      setScore(newScore);
      setCurrentQuestion((prev) => prev + 1);
      setShowFeedback(false);
    }
  }

  function handleRetry() {
    setCurrentQuestion(0);
    setSelectedAnswers({});
    setShowFeedback(false);
    setIsComplete(false);
    setScore(0);
  }

  function getOptionStyle(option: string, index: number) {
    const selected = selectedAnswers[currentQuestion];
    const isSelected = selected === option || selected === index;
    const isCorrect = question.correctAnswer === option || question.correctAnswer === index;

    if (!showFeedback) {
      return isSelected
        ? 'bg-lyo-500/20 border-lyo-500 text-white'
        : 'bg-white/5 border-white/10 text-white/80 hover:bg-white/10 hover:border-white/20';
    }

    if (isCorrect) {
      return 'bg-green-500/20 border-green-500 text-green-400';
    }
    if (isSelected && !isCorrect) {
      return 'bg-red-500/20 border-red-500 text-red-400';
    }
    return 'bg-white/5 border-white/10 text-white/40';
  }

  function getTrueFalseStyle(value: string) {
    const selected = selectedAnswers[currentQuestion];
    const isSelected = selected === value;
    const isCorrect = question.correctAnswer === value;

    if (!showFeedback) {
      return isSelected
        ? 'bg-lyo-500/20 border-lyo-500 text-white'
        : 'bg-white/5 border-white/10 text-white/80 hover:bg-white/10 hover:border-white/20';
    }

    if (isCorrect) {
      return 'bg-green-500/20 border-green-500 text-green-400';
    }
    if (isSelected && !isCorrect) {
      return 'bg-red-500/20 border-red-500 text-red-400';
    }
    return 'bg-white/5 border-white/10 text-white/40';
  }

  const scorePercent = totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;
  const circumference = 2 * Math.PI * 40;
  const strokeDashoffset = circumference - (scorePercent / 100) * circumference;

  if (isComplete) {
    return (
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className={cn(
          'flex flex-col items-center gap-6 p-8',
          !inline && 'min-h-screen justify-center'
        )}
      >
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ type: 'spring', damping: 15, stiffness: 200, delay: 0.1 }}
          className="relative"
        >
          <svg width="120" height="120" className="-rotate-90">
            <circle
              cx="60"
              cy="60"
              r="40"
              fill="none"
              stroke="rgba(255,255,255,0.1)"
              strokeWidth="8"
            />
            <circle
              cx="60"
              cy="60"
              r="40"
              fill="none"
              stroke="url(#scoreGradient)"
              strokeWidth="8"
              strokeLinecap="round"
              strokeDasharray={circumference}
              strokeDashoffset={strokeDashoffset}
              className="transition-all duration-1000"
            />
            <defs>
              <linearGradient id="scoreGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stopColor="#5c7cfa" />
                <stop offset="100%" stopColor="#7c3aed" />
              </linearGradient>
            </defs>
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-2xl font-bold text-white">
              {score}/{totalQuestions}
            </span>
          </div>
        </motion.div>

        <div className="flex items-center gap-3">
          <Trophy className="w-6 h-6 text-yellow-400" />
          <h3 className="text-2xl font-bold text-white">
            {scorePercent >= 70 ? 'Great job!' : 'Keep practicing!'}
          </h3>
        </div>

        <p className="text-white/60 text-center max-w-xs">
          {scorePercent >= 70
            ? `You answered ${score} out of ${totalQuestions} questions correctly.`
            : `You answered ${score} out of ${totalQuestions} correctly. Review the material and try again!`}
        </p>

        <div className="flex gap-3">
          <button
            onClick={handleRetry}
            className="flex items-center gap-2 px-5 py-3 rounded-xl bg-white/10 border border-white/10 text-white font-semibold hover:bg-white/15 transition-colors"
          >
            <RotateCcw className="w-4 h-4" />
            Retry Quiz
          </button>
          <button
            onClick={() => onComplete?.(score)}
            className="flex items-center gap-2 px-5 py-3 rounded-xl bg-gradient-to-r from-lyo-500 to-lyo-600 text-white font-semibold hover:opacity-90 transition-opacity"
          >
            Continue
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      </motion.div>
    );
  }

  return (
    <div className={cn('flex flex-col gap-5', !inline && 'min-h-screen p-6')}>
      {/* Progress bar */}
      <div className="space-y-2">
        <div className="flex justify-between items-center">
          <span className="text-sm text-white/60 font-medium">
            Question {currentQuestion + 1} of {totalQuestions}
          </span>
          <span className="text-sm text-white/40">
            {quiz.title}
          </span>
        </div>
        <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
          <motion.div
            className="h-full bg-gradient-to-r from-lyo-500 to-lyo-600 rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${((currentQuestion) / totalQuestions) * 100}%` }}
            transition={{ duration: 0.4, ease: 'easeOut' }}
          />
        </div>
      </div>

      {/* Question card */}
      <AnimatePresence mode="wait">
        <motion.div
          key={currentQuestion}
          initial={{ opacity: 0, x: 30 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -30 }}
          transition={{ duration: 0.25 }}
          className="flex flex-col gap-5"
        >
          <div className="bg-white/5 border border-white/10 rounded-2xl p-6">
            <p className="text-white text-lg font-semibold leading-relaxed">
              {question.question}
            </p>
          </div>

          {/* Multiple choice options */}
          {question.type === 'multiple_choice' && question.options && (
            <div className="flex flex-col gap-3">
              {question.options.map((option, index) => {
                const isSelected =
                  selectedAnswers[currentQuestion] === option ||
                  selectedAnswers[currentQuestion] === index;
                const isCorrect =
                  question.correctAnswer === option || question.correctAnswer === index;

                return (
                  <button
                    key={index}
                    onClick={() => handleSelect(option)}
                    disabled={showFeedback}
                    className={cn(
                      'flex items-center gap-3 w-full text-left px-4 py-3.5 rounded-xl border transition-all duration-200 cursor-pointer',
                      getOptionStyle(option, index)
                    )}
                  >
                    <span className="flex-shrink-0 w-7 h-7 rounded-full border border-current flex items-center justify-center text-xs font-bold">
                      {String.fromCharCode(65 + index)}
                    </span>
                    <span className="flex-1 text-sm font-medium">{option}</span>
                    {showFeedback && isCorrect && (
                      <CheckCircle className="w-5 h-5 text-green-400 flex-shrink-0" />
                    )}
                    {showFeedback && isSelected && !isCorrect && (
                      <XCircle className="w-5 h-5 text-red-400 flex-shrink-0" />
                    )}
                  </button>
                );
              })}
            </div>
          )}

          {/* True/False */}
          {question.type === 'true_false' && (
            <div className="flex gap-3">
              {['True', 'False'].map((value) => {
                const isSelected = selectedAnswers[currentQuestion] === value;
                const isCorrect = question.correctAnswer === value;

                return (
                  <button
                    key={value}
                    onClick={() => handleSelect(value)}
                    disabled={showFeedback}
                    className={cn(
                      'flex-1 flex items-center justify-center gap-2 py-4 rounded-xl border font-semibold text-base transition-all duration-200 cursor-pointer',
                      getTrueFalseStyle(value)
                    )}
                  >
                    {showFeedback && isCorrect && <CheckCircle className="w-5 h-5" />}
                    {showFeedback && isSelected && !isCorrect && <XCircle className="w-5 h-5" />}
                    {value}
                  </button>
                );
              })}
            </div>
          )}

          {/* Feedback / explanation */}
          <AnimatePresence>
            {showFeedback && question.explanation && (
              <motion.div
                initial={{ opacity: 0, y: -8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.2 }}
                className={cn(
                  'rounded-xl p-4 border text-sm leading-relaxed',
                  selectedAnswers[currentQuestion] === question.correctAnswer ||
                    selectedAnswers[currentQuestion] === question.correctAnswer
                    ? 'bg-green-500/10 border-green-500/30 text-green-300'
                    : 'bg-red-500/10 border-red-500/30 text-red-300'
                )}
              >
                <span className="font-semibold">Explanation: </span>
                {question.explanation}
              </motion.div>
            )}
          </AnimatePresence>

          {/* Action buttons */}
          <div className="flex justify-end">
            {!showFeedback ? (
              <button
                onClick={handleSubmit}
                disabled={!hasSelected}
                className={cn(
                  'flex items-center gap-2 px-6 py-3 rounded-xl font-semibold transition-all duration-200',
                  hasSelected
                    ? 'bg-gradient-to-r from-lyo-500 to-lyo-600 text-white hover:opacity-90'
                    : 'bg-white/5 text-white/30 cursor-not-allowed border border-white/10'
                )}
              >
                Submit Answer
                <ChevronRight className="w-4 h-4" />
              </button>
            ) : (
              <button
                onClick={handleNext}
                className="flex items-center gap-2 px-6 py-3 rounded-xl bg-gradient-to-r from-lyo-500 to-lyo-600 text-white font-semibold hover:opacity-90 transition-opacity"
              >
                {currentQuestion + 1 >= totalQuestions ? 'See Results' : 'Next Question'}
                <ChevronRight className="w-4 h-4" />
              </button>
            )}
          </div>
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
