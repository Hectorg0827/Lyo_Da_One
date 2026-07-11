'use client'

import { useState, useRef, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X, Image, Plus, Trash2, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'

interface CreatePostModalProps {
  onClose: () => void
  onSubmit: (data: PostFormData) => void
}

export interface PostFormData {
  type: PostType
  title: string
  content: string
  tags: string[]
  category: string
  pollOptions?: string[]
  image?: string | null
}

type PostType = 'post' | 'question' | 'poll' | 'event'

const POST_TYPES: { type: PostType; label: string; emoji: string }[] = [
  { type: 'post', label: 'Post', emoji: '📝' },
  { type: 'question', label: 'Question', emoji: '❓' },
  { type: 'poll', label: 'Poll', emoji: '📊' },
  { type: 'event', label: 'Event', emoji: '📅' },
]

const CATEGORIES = ['General', 'Guides', 'Events', 'Questions', 'Showcase']

export default function CreatePostModal({ onClose, onSubmit }: CreatePostModalProps) {
  const [postType, setPostType] = useState<PostType>('post')
  const [title, setTitle] = useState('')
  const [content, setContent] = useState('')
  const [tagInput, setTagInput] = useState('')
  const [tags, setTags] = useState<string[]>([])
  const [category, setCategory] = useState('General')
  const [categoryOpen, setCategoryOpen] = useState(false)
  const [pollOptions, setPollOptions] = useState<string[]>(['', ''])
  const [hasImage, setHasImage] = useState(false)
  const [errors, setErrors] = useState<{ title?: string; content?: string }>({})
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    const ta = textareaRef.current
    if (!ta) return
    ta.style.height = 'auto'
    ta.style.height = `${ta.scrollHeight}px`
  }, [content])

  const addTag = () => {
    const t = tagInput.trim().replace(/^#/, '')
    if (t && !tags.includes(t)) setTags(prev => [...prev, t])
    setTagInput('')
  }

  const removeTag = (tag: string) => setTags(prev => prev.filter(t => t !== tag))

  const handleTagKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') { e.preventDefault(); addTag() }
  }

  const addPollOption = () => setPollOptions(prev => [...prev, ''])
  const removePollOption = (i: number) => setPollOptions(prev => prev.filter((_, idx) => idx !== i))
  const updatePollOption = (i: number, val: string) =>
    setPollOptions(prev => prev.map((o, idx) => (idx === i ? val : o)))

  const validate = () => {
    const e: typeof errors = {}
    if (!title.trim()) e.title = 'Title is required'
    if (!content.trim()) e.content = 'Content is required'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  const handleSubmit = () => {
    if (!validate()) return
    onSubmit({
      type: postType,
      title,
      content,
      tags,
      category,
      pollOptions: postType === 'poll' ? pollOptions.filter(Boolean) : undefined,
      image: hasImage ? '/mock-image.jpg' : null,
    })
    onClose()
  }

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-50 flex items-center justify-center p-4"
        onClick={e => { if (e.target === e.currentTarget) onClose() }}
      >
        {/* Backdrop */}
        <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />

        {/* Modal Card */}
        <motion.div
          initial={{ scale: 0.92, opacity: 0, y: 20 }}
          animate={{ scale: 1, opacity: 1, y: 0 }}
          exit={{ scale: 0.92, opacity: 0, y: 20 }}
          transition={{ type: 'spring', damping: 22, stiffness: 300 }}
          className="relative z-10 w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-2xl border border-white/10 bg-[#0f0f1a]/95 backdrop-blur-xl shadow-2xl"
        >
          {/* Header */}
          <div className="flex items-center justify-between px-6 pt-5 pb-4 border-b border-white/10">
            <h2 className="text-lg font-semibold text-white">Create Post</h2>
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-white/50 hover:text-white hover:bg-white/10 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          <div className="px-6 py-5 space-y-5">
            {/* Post Type Tabs */}
            <div className="flex gap-2 p-1 rounded-xl bg-white/5 border border-white/10">
              {POST_TYPES.map(({ type, label, emoji }) => (
                <button
                  key={type}
                  onClick={() => setPostType(type)}
                  className={cn(
                    'flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-lg text-sm font-medium transition-all duration-200',
                    postType === type
                      ? 'bg-gradient-to-r from-lyo-500 to-accent-purple text-white shadow-lg'
                      : 'text-white/60 hover:text-white hover:bg-white/10'
                  )}
                >
                  <span>{emoji}</span>
                  <span className="hidden sm:inline">{label}</span>
                </button>
              ))}
            </div>

            {/* Title */}
            <div>
              <input
                type="text"
                placeholder="Post title..."
                value={title}
                onChange={e => { setTitle(e.target.value); if (errors.title) setErrors(p => ({ ...p, title: undefined })) }}
                className={cn(
                  'w-full px-4 py-3 rounded-xl bg-white/5 border text-white placeholder-white/30 focus:outline-none focus:ring-1 transition-colors',
                  errors.title
                    ? 'border-red-500/60 focus:ring-red-500/40'
                    : 'border-white/10 focus:border-lyo-500/60 focus:ring-lyo-500/30'
                )}
              />
              {errors.title && <p className="mt-1 text-xs text-red-400">{errors.title}</p>}
            </div>

            {/* Content */}
            <div>
              <textarea
                ref={textareaRef}
                placeholder="What's on your mind? Share your thoughts, insights, or questions..."
                value={content}
                onChange={e => { setContent(e.target.value); if (errors.content) setErrors(p => ({ ...p, content: undefined })) }}
                rows={4}
                className={cn(
                  'w-full px-4 py-3 rounded-xl bg-white/5 border text-white placeholder-white/30 focus:outline-none focus:ring-1 transition-colors resize-none overflow-hidden',
                  errors.content
                    ? 'border-red-500/60 focus:ring-red-500/40'
                    : 'border-white/10 focus:border-lyo-500/60 focus:ring-lyo-500/30'
                )}
              />
              {errors.content && <p className="mt-1 text-xs text-red-400">{errors.content}</p>}
            </div>

            {/* Poll Options */}
            <AnimatePresence>
              {postType === 'poll' && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  className="space-y-2"
                >
                  <p className="text-sm font-medium text-white/70">Poll Options</p>
                  {pollOptions.map((opt, i) => (
                    <div key={i} className="flex gap-2">
                      <input
                        type="text"
                        placeholder={`Option ${i + 1}`}
                        value={opt}
                        onChange={e => updatePollOption(i, e.target.value)}
                        className="flex-1 px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-white/30 focus:outline-none focus:border-lyo-500/60 focus:ring-1 focus:ring-lyo-500/30 transition-colors"
                      />
                      {pollOptions.length > 2 && (
                        <button
                          onClick={() => removePollOption(i)}
                          className="p-2.5 rounded-xl text-red-400/70 hover:text-red-400 hover:bg-red-400/10 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  ))}
                  {pollOptions.length < 6 && (
                    <button
                      onClick={addPollOption}
                      className="flex items-center gap-2 px-4 py-2 text-sm text-lyo-400 hover:text-lyo-300 transition-colors"
                    >
                      <Plus className="w-4 h-4" />
                      Add option
                    </button>
                  )}
                </motion.div>
              )}
            </AnimatePresence>

            {/* Tags */}
            <div>
              <p className="text-sm font-medium text-white/70 mb-2">Tags</p>
              <div className="flex flex-wrap gap-2 mb-2">
                <AnimatePresence>
                  {tags.map(tag => (
                    <motion.span
                      key={tag}
                      initial={{ scale: 0.8, opacity: 0 }}
                      animate={{ scale: 1, opacity: 1 }}
                      exit={{ scale: 0.8, opacity: 0 }}
                      className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-lyo-500/20 border border-lyo-500/30 text-lyo-300 text-sm"
                    >
                      #{tag}
                      <button onClick={() => removeTag(tag)} className="hover:text-white transition-colors">
                        <X className="w-3 h-3" />
                      </button>
                    </motion.span>
                  ))}
                </AnimatePresence>
              </div>
              <input
                type="text"
                placeholder="Add a tag and press Enter..."
                value={tagInput}
                onChange={e => setTagInput(e.target.value)}
                onKeyDown={handleTagKeyDown}
                onBlur={addTag}
                className="w-full px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-white/30 focus:outline-none focus:border-lyo-500/60 focus:ring-1 focus:ring-lyo-500/30 transition-colors"
              />
            </div>

            {/* Category */}
            <div className="relative">
              <p className="text-sm font-medium text-white/70 mb-2">Category</p>
              <button
                onClick={() => setCategoryOpen(p => !p)}
                className="w-full flex items-center justify-between px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white hover:border-white/20 transition-colors"
              >
                <span>{category}</span>
                <motion.span animate={{ rotate: categoryOpen ? 180 : 0 }} transition={{ duration: 0.2 }}>
                  <ChevronDown className="w-4 h-4 text-white/50" />
                </motion.span>
              </button>
              <AnimatePresence>
                {categoryOpen && (
                  <motion.div
                    initial={{ opacity: 0, y: -8 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -8 }}
                    className="absolute top-full mt-1 left-0 right-0 z-20 rounded-xl border border-white/10 bg-[#0f0f1a]/98 backdrop-blur-xl shadow-xl overflow-hidden"
                  >
                    {CATEGORIES.map(cat => (
                      <button
                        key={cat}
                        onClick={() => { setCategory(cat); setCategoryOpen(false) }}
                        className={cn(
                          'w-full text-left px-4 py-3 text-sm transition-colors hover:bg-white/10',
                          category === cat ? 'text-lyo-400' : 'text-white/70'
                        )}
                      >
                        {cat}
                      </button>
                    ))}
                  </motion.div>
                )}
              </AnimatePresence>
            </div>

            {/* Image Upload */}
            <div>
              <p className="text-sm font-medium text-white/70 mb-2">Image</p>
              <button
                onClick={() => setHasImage(p => !p)}
                className={cn(
                  'w-full py-8 rounded-xl border-2 border-dashed flex flex-col items-center gap-2 transition-all duration-200',
                  hasImage
                    ? 'border-lyo-500/50 bg-lyo-500/10'
                    : 'border-white/20 hover:border-white/40 hover:bg-white/5'
                )}
              >
                <Image className={cn('w-8 h-8', hasImage ? 'text-lyo-400' : 'text-white/30')} />
                <span className={cn('text-sm', hasImage ? 'text-lyo-400' : 'text-white/40')}>
                  {hasImage ? 'Image attached (click to remove)' : 'Click to upload an image'}
                </span>
              </button>
            </div>
          </div>

          {/* Footer */}
          <div className="flex items-center gap-3 px-6 py-4 border-t border-white/10">
            <button
              onClick={onClose}
              className="flex-1 py-3 rounded-xl border border-white/20 text-white/70 hover:text-white hover:bg-white/10 font-medium transition-all"
            >
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              className="flex-1 py-3 rounded-xl bg-gradient-to-r from-lyo-500 to-accent-purple text-white font-semibold shadow-lg hover:shadow-lyo-500/30 hover:opacity-90 transition-all"
            >
              Post
            </button>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
