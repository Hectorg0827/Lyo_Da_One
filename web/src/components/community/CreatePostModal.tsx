'use client'

import { useEffect, useRef, useState } from 'react'
import { Camera, ImagePlus, Loader2, Send, Sparkles, X } from 'lucide-react'
import { api } from '@/lib/api'
import { cn } from '@/lib/utils'

export type CommunityPostKind = 'text' | 'question_discussion' | 'study_tip'

export interface PostFormData {
  type: CommunityPostKind
  content: string
  tags: string[]
  mediaUrls: string[]
}

interface PostComposerProps {
  onSubmit: (data: PostFormData) => Promise<void>
  onCancel?: () => void
}

const MAX_IMAGES = 10
const MAX_IMAGE_BYTES = 10 * 1024 * 1024
const POST_TYPES: { type: CommunityPostKind; label: string }[] = [
  { type: 'text', label: 'Post' },
  { type: 'question_discussion', label: 'Question' },
  { type: 'study_tip', label: 'Study tip' },
]

/** One composer for + Create and Community, backed by the same real upload API. */
export function PostComposer({ onSubmit, onCancel }: PostComposerProps) {
  const [type, setType] = useState<CommunityPostKind>('text')
  const [content, setContent] = useState('')
  const [tagInput, setTagInput] = useState('')
  const [tags, setTags] = useState<string[]>([])
  const [images, setImages] = useState<File[]>([])
  const [previewUrls, setPreviewUrls] = useState<string[]>([])
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const galleryRef = useRef<HTMLInputElement>(null)
  const cameraRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const urls = images.map((file) => URL.createObjectURL(file))
    setPreviewUrls(urls)
    return () => urls.forEach((url) => URL.revokeObjectURL(url))
  }, [images])

  const addTag = () => {
    const next = tagInput.trim().replace(/^#/, '')
    if (next && !tags.includes(next) && tags.length < 20) setTags((current) => [...current, next])
    setTagInput('')
  }

  const selectImages = (files: FileList | null) => {
    if (!files?.length) return
    setError(null)
    const candidates = Array.from(files)
    if (candidates.some((file) => !file.type.startsWith('image/') || file.size === 0 || file.size > MAX_IMAGE_BYTES)) {
      setError('Choose image files up to 10 MB each.')
      return
    }
    if (images.length + candidates.length > MAX_IMAGES) {
      setError(`You can attach up to ${MAX_IMAGES} photos per post.`)
      return
    }
    setImages((current) => [...current, ...candidates])
  }

  const submit = async () => {
    if (!content.trim() || submitting) return
    setSubmitting(true)
    setError(null)
    try {
      // Upload only on Publish; cancelling a draft doesn't create orphaned media.
      const mediaUrls: string[] = []
      for (const image of images) {
        const uploaded = await api.media.upload(image, 'community')
        if (!uploaded.success || !uploaded.url) throw new Error('The photo upload did not complete.')
        mediaUrls.push(uploaded.url)
      }
      await onSubmit({ type, content: content.trim(), tags, mediaUrls })
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Unable to publish your post.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="space-y-4 text-white">
      <div className="flex gap-2 rounded-2xl border border-white/10 bg-white/[0.04] p-1" role="group" aria-label="Post type">
        {POST_TYPES.map((option) => (
          <button
            key={option.type}
            type="button"
            onClick={() => setType(option.type)}
            aria-pressed={type === option.type}
            disabled={submitting}
            className={cn('min-h-11 flex-1 rounded-xl px-2 text-sm font-semibold transition-colors', type === option.type ? 'bg-lyo-500 text-white' : 'text-white/60 hover:bg-white/10 hover:text-white')}
          >
            {option.label}
          </button>
        ))}
      </div>

      <label className="block">
        <span className="sr-only">Post caption</span>
        <textarea
          autoFocus
          rows={5}
          maxLength={5000}
          value={content}
          onChange={(event) => setContent(event.target.value)}
          placeholder={type === 'question_discussion' ? 'What would you like the community to help with?' : 'What would you like to share with LYO?'}
          className="min-h-36 w-full resize-y rounded-2xl border border-white/10 bg-white/[0.05] p-4 text-base text-white placeholder:text-white/35 focus:border-cyan-400 focus:outline-none"
        />
        <span className="mt-1 block text-right text-xs text-white/40">{content.length}/5000</span>
      </label>

      {images.length > 0 && (
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3" aria-label="Selected photos">
          {previewUrls.map((url, index) => (
            <div key={url} className="relative aspect-square overflow-hidden rounded-2xl border border-white/10 bg-white/5">
              <img src={url} alt={`Photo ${index + 1} preview`} className="h-full w-full object-cover" />
              <button type="button" aria-label={`Remove photo ${index + 1}`} disabled={submitting} onClick={() => setImages((current) => current.filter((_, i) => i !== index))} className="absolute right-2 top-2 rounded-full bg-black/75 p-1.5 text-white">
                <X className="h-4 w-4" />
              </button>
            </div>
          ))}
        </div>
      )}

      <div className="flex flex-wrap gap-2">
        <button type="button" onClick={() => cameraRef.current?.click()} disabled={submitting || images.length >= MAX_IMAGES} className="flex min-h-11 items-center gap-2 rounded-xl border border-white/15 bg-white/[0.06] px-4 text-sm font-medium text-white hover:bg-white/10 disabled:opacity-40">
          <Camera className="h-5 w-5 text-cyan-300" aria-hidden="true" /> Camera
        </button>
        <button type="button" onClick={() => galleryRef.current?.click()} disabled={submitting || images.length >= MAX_IMAGES} className="flex min-h-11 items-center gap-2 rounded-xl border border-white/15 bg-white/[0.06] px-4 text-sm font-medium text-white hover:bg-white/10 disabled:opacity-40">
          <ImagePlus className="h-5 w-5 text-cyan-300" aria-hidden="true" /> Add photos
        </button>
        <input ref={cameraRef} type="file" accept="image/*" capture="environment" className="sr-only" aria-label="Take photo" onChange={(event) => { selectImages(event.target.files); event.target.value = '' }} />
        <input ref={galleryRef} type="file" accept="image/*" multiple className="sr-only" aria-label="Choose photos" onChange={(event) => { selectImages(event.target.files); event.target.value = '' }} />
      </div>

      <div className="space-y-2">
        <label htmlFor="post-composer-tags" className="block text-sm font-medium text-white/65">Topics</label>
        {tags.length > 0 && <div className="flex flex-wrap gap-2">{tags.map((tag) => <button key={tag} type="button" disabled={submitting} onClick={() => setTags((current) => current.filter((item) => item !== tag))} className="rounded-full border border-cyan-400/25 bg-cyan-400/10 px-3 py-1 text-xs text-cyan-200">#{tag} ×</button>)}</div>}
        <input id="post-composer-tags" value={tagInput} onChange={(event) => setTagInput(event.target.value)} onBlur={addTag} onKeyDown={(event) => { if (event.key === 'Enter') { event.preventDefault(); addTag() } }} disabled={submitting} placeholder="Add a subject and press Enter" className="min-h-11 w-full rounded-xl border border-white/10 bg-white/[0.05] px-4 text-sm text-white placeholder:text-white/35 focus:border-cyan-400 focus:outline-none" />
      </div>

      <p className="flex items-center gap-2 text-xs text-white/50"><Sparkles className="h-4 w-4 text-cyan-300" aria-hidden="true" /> Posts appear in Community after publishing. Add a caption even when sharing a photo.</p>
      {error && <p role="alert" className="text-sm text-red-300">{error}</p>}
      <div className="flex gap-3 border-t border-white/10 pt-4">
        {onCancel && <button type="button" onClick={onCancel} disabled={submitting} className="min-h-12 rounded-xl border border-white/15 px-5 text-sm text-white/70 hover:bg-white/10">Cancel</button>}
        <button type="button" onClick={submit} disabled={!content.trim() || submitting} className="flex min-h-12 flex-1 items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-blue-500 to-cyan-500 px-5 text-sm font-bold text-white shadow-lg shadow-cyan-500/10 disabled:cursor-not-allowed disabled:opacity-40">
          {submitting ? <Loader2 className="h-5 w-5 animate-spin" aria-hidden="true" /> : <Send className="h-5 w-5" aria-hidden="true" />}
          {submitting ? 'Publishing…' : 'Publish post'}
        </button>
      </div>
    </div>
  )
}

export default function CreatePostModal({ onClose, onSubmit }: PostComposerProps & { onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 p-3 backdrop-blur-md sm:p-6" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section role="dialog" aria-modal="true" aria-labelledby="create-post-title" className="max-h-[calc(100dvh-1.5rem)] w-full max-w-xl overflow-y-auto rounded-3xl border border-white/15 bg-[#0d1422] p-5 shadow-2xl sm:p-6">
        <header className="mb-5 flex items-center justify-between">
          <div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300">LYO Community</p><h2 id="create-post-title" className="mt-1 font-rounded text-2xl font-bold text-white">Create a post</h2></div>
          <button type="button" onClick={onClose} aria-label="Close" className="rounded-full bg-white/10 p-2.5 text-white/80 hover:bg-white/20"><X className="h-5 w-5" /></button>
        </header>
        <PostComposer onCancel={onClose} onSubmit={async (data) => { await onSubmit(data); onClose() }} />
      </section>
    </div>
  )
}
