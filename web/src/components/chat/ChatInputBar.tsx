'use client';

import { useEffect, useRef, useState, useCallback, KeyboardEvent } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowUp, Plus, Mic, Square, X, FileText, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { cn } from '@/lib/utils';
import { useChatStore } from '@/stores/chat-store';
import { api } from '@/lib/api';
import type { ChatAttachment } from '@/types';
import { createBrowserSpeechRecognition } from '@/lib/browser-speech';
import ConversationalVoiceLayer from './ConversationalVoiceLayer';

const MAX_CHARS = 4000;
const MAX_ROWS = 6;
const LINE_HEIGHT = 24; // px per row
const MAX_UPLOAD_BYTES = 10 * 1024 * 1024; // 10MB
const MAX_TOTAL_UPLOAD_BYTES = 20 * 1024 * 1024; // 20MB
const MAX_ATTACHMENTS = 4;
const SUPPORTED_ATTACHMENT_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'application/pdf',
  'text/plain',
  'text/markdown',
  'text/csv',
  'application/json',
]);

function attachmentMimeType(file: File): string {
  const reportedType = file.type.toLowerCase();
  if (SUPPORTED_ATTACHMENT_TYPES.has(reportedType)) return reportedType;
  const extension = file.name.split('.').pop()?.toLowerCase();
  return ({
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    webp: 'image/webp',
    heic: 'image/heic',
    pdf: 'application/pdf',
    txt: 'text/plain',
    md: 'text/markdown',
    csv: 'text/csv',
    json: 'application/json',
  } as Record<string, string>)[extension || ''] || '';
}

export default function ChatInputBar() {
  const {
    sendMessage,
    isGenerating,
    generationActivity,
    reviseActiveCourse,
    voiceSessionActive,
    setVoiceSessionActive,
  } = useChatStore();
  const isCourseAdjustable = isGenerating && generationActivity === 'course';
  const [value, setValue] = useState('');
  const [speechSupported, setSpeechSupported] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [attachments, setAttachments] = useState<ChatAttachment[]>([]);

  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setSpeechSupported(createBrowserSpeechRecognition() !== null);
  }, []);

  const adjustHeight = useCallback(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    const maxHeight = MAX_ROWS * LINE_HEIGHT + 16; // 16px = padding
    el.style.height = `${Math.min(el.scrollHeight, maxHeight)}px`;
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    if (e.target.value.length > MAX_CHARS) return;
    setValue(e.target.value);
    adjustHeight();
  };

  // Android parity: one microphone control means one continuous voice session.
  // A second dictation recognizer competes for the microphone on mobile Chrome.
  const toggleVoiceSession = () => {
    setVoiceSessionActive(!voiceSessionActive);
  };

  // ── Attachments (shared consumer media API) ───────────────────────────────

  const handleFilePicked = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const selected = Array.from(e.target.files ?? []);
    e.target.value = ''; // allow re-picking the same file
    if (selected.length === 0) return;

    const capacity = MAX_ATTACHMENTS - attachments.length;
    if (capacity <= 0) {
      toast.error(`You can attach up to ${MAX_ATTACHMENTS} files`);
      return;
    }
    if (selected.length > capacity) {
      toast.error(`Only ${capacity} more attachment${capacity === 1 ? '' : 's'} can be added`);
    }

    setUploading(true);
    const uploaded: ChatAttachment[] = [];
    let totalBytes = attachments.reduce((sum, attachment) => sum + attachment.size, 0);

    for (const file of selected.slice(0, capacity)) {
      const mimeType = attachmentMimeType(file);
      if (!SUPPORTED_ATTACHMENT_TYPES.has(mimeType)) {
        toast.error(`${file.name} is not a supported image or document`);
        continue;
      }
      if (file.size > MAX_UPLOAD_BYTES) {
        toast.error(`${file.name} is larger than 10MB`);
        continue;
      }
      if (totalBytes + file.size > MAX_TOTAL_UPLOAD_BYTES) {
        toast.error('Attachments may total at most 20MB');
        break;
      }

      try {
        const normalizedFile = file.type === mimeType
          ? file
          : new File([file], file.name, { type: mimeType });
        const result = await api.media.upload(normalizedFile, 'chat');
        uploaded.push({
          name: file.name,
          url: result.url,
          mimeType: result.contentType || mimeType,
          size: result.size || file.size,
          kind: mimeType.startsWith('image/') ? 'image' : 'document',
        });
        totalBytes += file.size;
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Upload failed';
        toast.error(`${file.name}: ${message}`);
      }
    }

    if (uploaded.length > 0) {
      setAttachments((current) => [...current, ...uploaded].slice(0, MAX_ATTACHMENTS));
    }
    setUploading(false);
  };

  // ── Send ──────────────────────────────────────────────────────────────────

  const handleSubmit = async () => {
    const trimmed = value.trim();
    if (
      (!trimmed && attachments.length === 0)
      || (isGenerating && !isCourseAdjustable)
      || uploading
    ) return;
    setValue('');
    const sentAttachments = attachments;
    setAttachments([]);
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
    // Text or attachments switch back to regular Chat without creating a
    // second thread. The voice layer releases its recognizer and playback.
    if (voiceSessionActive) setVoiceSessionActive(false);
    if (isCourseAdjustable) {
      await reviseActiveCourse(trimmed);
    } else {
      await sendMessage(trimmed, sentAttachments);
    }
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const charCount = value.length;
  const showCount = charCount > MAX_CHARS * 0.75;
  const canSend =
    (value.trim().length > 0 || attachments.length > 0)
    && (!isGenerating || isCourseAdjustable)
    && !uploading;

  return (
    <div className="relative px-3 py-3 md:px-6 md:py-4">
      <ConversationalVoiceLayer />

      {/* Pending attachment chips */}
      <div className="flex gap-2 mb-2 overflow-x-auto max-w-3xl mx-auto">
        <AnimatePresence initial={false}>
          {attachments.map((attachment) => (
          <motion.div
            key={`${attachment.url}-${attachment.name}`}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 6 }}
            className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-white/5 border border-white/10 min-w-0 max-w-[240px] shrink-0"
          >
            {attachment.kind === 'image' ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={attachment.url} alt={attachment.name} className="w-8 h-8 rounded object-cover" />
            ) : (
              <FileText className="w-4 h-4 text-lyo-300 shrink-0" />
            )}
            <span className="text-xs text-white/70 truncate">{attachment.name}</span>
            <button
              onClick={() => setAttachments((current) => current.filter((item) => item.url !== attachment.url))}
              className="p-0.5 text-white/40 hover:text-white"
              title="Remove attachment"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </motion.div>
          ))}
        </AnimatePresence>
      </div>

      {/* Android parity: attachment, live mic, message field and send share a row. */}
      <div
        className={cn(
          'input-island flex items-end gap-1.5 sm:gap-2 px-2 sm:px-3 py-2 max-w-3xl mx-auto',
          isGenerating && 'input-island--thinking'
        )}
      >
        <input
          ref={fileInputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp,image/heic,.pdf,.txt,.md,.csv,.json"
          multiple
          className="hidden"
          onChange={handleFilePicked}
          aria-label="Choose an image or document"
        />
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          disabled={uploading || isGenerating || attachments.length >= MAX_ATTACHMENTS}
          className="h-11 w-9 sm:w-10 rounded-full flex items-center justify-center text-white/85 hover:bg-white/10 transition-colors shrink-0 disabled:opacity-40"
          aria-label="Attach an image or document"
          title="Attach an image or document"
        >
          {uploading ? <Loader2 className="w-5 h-5 animate-spin" /> : <Plus className="w-5 h-5" strokeWidth={1.8} />}
        </button>

        <button
          type="button"
          onClick={toggleVoiceSession}
          disabled={!speechSupported}
          aria-label={voiceSessionActive ? 'End live voice' : 'Start live voice'}
          aria-pressed={voiceSessionActive}
          className={cn(
            'h-11 w-9 sm:w-10 rounded-full flex items-center justify-center transition-colors shrink-0',
            voiceSessionActive ? 'bg-lyo-500/20 text-lyo-300' : 'text-white/75 hover:bg-white/10',
            !speechSupported && 'opacity-40 cursor-not-allowed'
          )}
          title={speechSupported
            ? (voiceSessionActive ? 'End live voice' : 'Start live voice')
            : 'Live voice is unavailable in this browser'}
        >
          {voiceSessionActive ? <Square className="w-4 h-4" fill="currentColor" /> : <Mic className="w-5 h-5" />}
        </button>

        <div className="relative min-w-0 flex-1">
          <textarea
            ref={textareaRef}
            value={value}
            onChange={handleChange}
            onKeyDown={handleKeyDown}
            aria-label="Message Lyo"
            placeholder={
              isCourseAdjustable
                ? 'Adjust the course while it builds…'
                : isGenerating
                  ? 'Lyo is thinking…'
                  : 'Ask Lyo anything…'
            }
            disabled={isGenerating && !isCourseAdjustable}
            rows={1}
            className={cn(
              'w-full min-h-11 max-h-36 resize-none rounded-3xl border border-white/20 bg-white/5',
              'px-3.5 py-2.5 text-base leading-6 text-white placeholder-white/40',
              'focus:outline-none focus:border-lyo-400 focus:ring-1 focus:ring-lyo-400/40',
              'scrollbar-thin scrollbar-thumb-white/10',
              'disabled:opacity-50 disabled:cursor-not-allowed',
              isCourseAdjustable && 'placeholder:text-lyo-300/45'
            )}
            style={{ lineHeight: `${LINE_HEIGHT}px` }}
          />
          <AnimatePresence>
            {showCount && (
              <motion.span
                initial={{ opacity: 0, y: 3 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 3 }}
                className={cn(
                  'absolute -top-5 right-2 text-[11px] font-mono',
                  charCount > MAX_CHARS * 0.95 ? 'text-red-400' : 'text-white/40'
                )}
              >
                {MAX_CHARS - charCount}
              </motion.span>
            )}
          </AnimatePresence>
        </div>

        <motion.button
          type="button"
          onClick={handleSubmit}
          disabled={!canSend}
          whileTap={canSend ? { scale: 0.9 } : {}}
          className={cn(
            'h-11 w-11 rounded-full flex items-center justify-center transition-all shrink-0',
            canSend
              ? 'bg-lyo-600 text-white shadow-lg shadow-lyo-900/30 hover:bg-lyo-500'
              : 'bg-lyo-600/30 text-white/35 cursor-not-allowed'
          )}
          aria-label="Send message"
          title="Send message"
        >
          <ArrowUp className="w-5 h-5" strokeWidth={2.5} />
        </motion.button>
      </div>

      {/* Hint (desktop only) */}
      <p className="hidden md:block text-center text-[11px] text-white/20 mt-2">
        LYO can make mistakes. Press{' '}
        <kbd className="px-1 py-0.5 rounded bg-white/10 font-mono text-[10px]">Enter</kbd> to send,{' '}
        <kbd className="px-1 py-0.5 rounded bg-white/10 font-mono text-[10px]">Shift+Enter</kbd> for newline.
      </p>
    </div>
  );
}
