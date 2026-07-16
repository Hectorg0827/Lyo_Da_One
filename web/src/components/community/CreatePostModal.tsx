'use client'

import { useState } from 'react'
import { Loader2, X } from 'lucide-react'
import { cn } from '@/lib/utils'

export type CommunityPostKind = 'text' | 'question_discussion' | 'study_tip'

export interface PostFormData {
  type: CommunityPostKind
  content: string
  tags: string[]
}

interface CreatePostModalProps {
  onClose: () => void
  onSubmit: (data: PostFormData) => Promise<void>
}

const POST_TYPES: { type: CommunityPostKind; label: string; emoji: string }[] = [
  { type: 'text', label: 'Post', emoji: '📝' },
  { type: 'question_discussion', label: 'Question', emoji: '❓' },
  { type: 'study_tip', label: 'Study tip', emoji: '💡' },
]

export default function CreatePostModal({ onClose, onSubmit }: CreatePostModalProps) {
  const [type, setType] = useState<CommunityPostKind>('text')
  const [content, setContent] = useState('')
  const [tagInput, setTagInput] = useState('')
  const [tags, setTags] = useState<string[]>([])
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const addTag = () => {
    const next = tagInput.trim().replace(/^#/, '')
    if (next && !tags.includes(next)) setTags((current) => [...current, next])
    setTagInput('')
  }

  const submit = async () => {
    if (!content.trim() || submitting) return
    setSubmitting(true)
    setError(null)
    try {
      await onSubmit({ type, content: content.trim(), tags })
      onClose()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to create the post')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm"
      onMouseDown={(event) => event.target === event.currentTarget && onClose()}
    >
      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby="create-post-title"
        className="w-full max-w-2xl overflow-hidden rounded-2xl border border-white/10 bg-[var(--surface)] shadow-2xl"
      >
        <header className="flex items-center justify-between border-b border-white/10 px-5 py-4">
          <h2 id="create-post-title" className="text-lg font-semibold text-white">Create post</h2>
          <button onClick={onClose} aria-label="Close" className="rounded-lg p-2 text-white/50 hover:bg-white/10 hover:text-white">
            <X className="h-5 w-5" />
          </button>
        </header>

        <div className="space-y-5 p-5">
          <div className="grid grid-cols-3 gap-2 rounded-xl border border-white/10 bg-white/5 p-1">
            {POST_TYPES.map((option) => (
              <button
                key={option.type}
                type="button"
                onClick={() => setType(option.type)}
                className={cn(
                  'rounded-lg px-2 py-2.5 text-sm font-medium transition',
                  type === option.type ? 'bg-lyo-500 text-white' : 'text-white/60 hover:bg-white/10 hover:text-white',
                )}
              >
                <span aria-hidden="true">{option.emoji}</span> {option.label}
              </button>
            ))}
          </div>

          <textarea
            autoFocus
            rows={7}
            maxLength={5000}
            value={content}
            onChange={(event) => setContent(event.target.value)}
            placeholder={type === 'question_discussion' ? 'What would you like the community to help with?' : 'Share something with the community…'}
            className="w-full resize-y rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-white placeholder:text-white/30 focus:border-lyo-500 focus:outline-none"
          />

          <div>
            <div className="mb-2 flex flex-wrap gap-2">
              {tags.map((tag) => (
                <button key={tag} type="button" onClick={() => setTags((current) => current.filter((item) => item !== tag))} className="rounded-full border border-lyo-500/30 bg-lyo-500/15 px-3 py-1 text-xs text-lyo-300">
                  #{tag} <span aria-hidden="true">×</span>
                </button>
              ))}
            </div>
            <input
              value={tagInput}
              onChange={(event) => setTagInput(event.target.value)}
              onBlur={addTag}
              onKeyDown={(event) => { if (event.key === 'Enter') { event.preventDefault(); addTag() } }}
              placeholder="Add a tag and press Enter"
              className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2.5 text-sm text-white placeholder:text-white/30 focus:border-lyo-500 focus:outline-none"
            />
          </div>

          {error && <p role="alert" className="text-sm text-red-400">{error}</p>}
        </div>

        <footer className="flex justify-end gap-3 border-t border-white/10 px-5 py-4">
          <button onClick={onClose} disabled={submitting} className="rounded-xl border border-white/15 px-4 py-2.5 text-sm text-white/70 hover:bg-white/10">Cancel</button>
          <button onClick={submit} disabled={!content.trim() || submitting} className="flex min-w-28 items-center justify-center gap-2 rounded-xl bg-lyo-500 px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-50">
            {submitting && <Loader2 className="h-4 w-4 animate-spin" />}
            {submitting ? 'Posting…' : 'Post'}
          </button>
        </footer>
      </section>
    </div>
  )
}
