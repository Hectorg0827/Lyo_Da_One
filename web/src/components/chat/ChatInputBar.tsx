'use client';

import { useEffect, useRef, useState, useCallback, KeyboardEvent } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowUp, Plus, Mic, X, FileText, Loader2, MessageCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import { cn } from '@/lib/utils';
import { useChatStore } from '@/stores/chat-store';
import { api } from '@/lib/api';

const MAX_CHARS = 4000;
const MAX_ROWS = 6;
const LINE_HEIGHT = 24; // px per row
const MAX_UPLOAD_BYTES = 10 * 1024 * 1024; // 10MB

// Minimal typing for the Web Speech API (not yet in lib.dom for all targets).
type SpeechRecognitionLike = {
  lang: string;
  interimResults: boolean;
  continuous: boolean;
  start: () => void;
  stop: () => void;
  onresult: ((event: { results: ArrayLike<ArrayLike<{ transcript: string }>> }) => void) | null;
  onend: (() => void) | null;
  onerror: (() => void) | null;
};

function getSpeechRecognition(): SpeechRecognitionLike | null {
  if (typeof window === 'undefined') return null;
  const w = window as unknown as Record<string, unknown>;
  const Ctor = (w.SpeechRecognition || w.webkitSpeechRecognition) as
    | (new () => SpeechRecognitionLike)
    | undefined;
  return Ctor ? new Ctor() : null;
}

interface PendingAttachment {
  name: string;
  url: string;
  isImage: boolean;
}

export default function ChatInputBar() {
  const { sendMessage, isGenerating } = useChatStore();
  const [value, setValue] = useState('');
  const [listening, setListening] = useState(false);
  const [speechSupported, setSpeechSupported] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [attachment, setAttachment] = useState<PendingAttachment | null>(null);

  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);
  const dictationBaseRef = useRef('');

  useEffect(() => {
    setSpeechSupported(getSpeechRecognition() !== null);
    return () => recognitionRef.current?.stop();
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

  // ── Voice dictation (Web Speech API) ──────────────────────────────────────

  const toggleDictation = () => {
    if (listening) {
      recognitionRef.current?.stop();
      return;
    }
    const recognition = getSpeechRecognition();
    if (!recognition) return;
    recognitionRef.current = recognition;
    dictationBaseRef.current = value ? value.replace(/\s*$/, ' ') : '';
    recognition.lang = navigator.language || 'en-US';
    recognition.interimResults = true;
    recognition.continuous = true;
    recognition.onresult = (event) => {
      let transcript = '';
      for (let i = 0; i < event.results.length; i++) {
        transcript += event.results[i][0].transcript;
      }
      setValue((dictationBaseRef.current + transcript).slice(0, MAX_CHARS));
      adjustHeight();
    };
    recognition.onend = () => setListening(false);
    recognition.onerror = () => {
      setListening(false);
      toast.error("Couldn't access the microphone");
    };
    try {
      recognition.start();
      setListening(true);
    } catch {
      toast.error('Voice input is unavailable');
    }
  };

  // ── Attachments (existing storage API) ────────────────────────────────────

  const handleFilePicked = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ''; // allow re-picking the same file
    if (!file) return;
    if (file.size > MAX_UPLOAD_BYTES) {
      toast.error('File too large (max 10MB)');
      return;
    }
    setUploading(true);
    try {
      const result = await api.storage.upload(file, 'chat');
      const url = Object.values(result.urls ?? {})[0];
      if (!url) throw new Error('no url');
      setAttachment({
        name: file.name,
        url,
        isImage: file.type.startsWith('image/'),
      });
    } catch {
      toast.error("Upload failed — check that you're logged in");
    } finally {
      setUploading(false);
    }
  };

  // ── Send ──────────────────────────────────────────────────────────────────

  const handleSubmit = async () => {
    const trimmed = value.trim();
    if ((!trimmed && !attachment) || isGenerating) return;
    recognitionRef.current?.stop();

    // Reference the uploaded file inside the message so the AI (and the
    // transcript) can see it — markdown renders it inline in the thread.
    let content = trimmed;
    if (attachment) {
      const md = attachment.isImage
        ? `![${attachment.name}](${attachment.url})`
        : `[📎 ${attachment.name}](${attachment.url})`;
      content = trimmed ? `${trimmed}\n\n${md}` : md;
    }

    setValue('');
    setAttachment(null);
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
    await sendMessage(content);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const charCount = value.length;
  const showCount = charCount > MAX_CHARS * 0.75;
  const canSend = (value.trim().length > 0 || !!attachment) && !isGenerating && !uploading;

  return (
    <div className="relative px-3 py-3 md:px-6 md:py-4">
      {/* Pending attachment chip */}
      <AnimatePresence>
        {attachment && (
          <motion.div
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 6 }}
            className="flex items-center gap-2 mb-2 px-3 py-1.5 rounded-xl bg-white/5 border border-white/10 w-fit max-w-full"
          >
            {attachment.isImage ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={attachment.url} alt={attachment.name} className="w-8 h-8 rounded object-cover" />
            ) : (
              <FileText className="w-4 h-4 text-lyo-300 shrink-0" />
            )}
            <span className="text-xs text-white/70 truncate">{attachment.name}</span>
            <button
              onClick={() => setAttachment(null)}
              className="p-0.5 text-white/40 hover:text-white"
              title="Remove attachment"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Input island — mirrors iOS HybridInputBar: black rounded-24 card,
          rotating angular-gradient border tinted by AI state, text field on
          top, controls row below (+ / Chat pill · mic / send). */}
      <div
        className={cn(
          'input-island px-4 pt-3 pb-2.5 max-w-3xl mx-auto',
          isGenerating && 'input-island--thinking'
        )}
      >
        {/* Textarea */}
        <textarea
          ref={textareaRef}
          value={value}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          placeholder={
            isGenerating ? 'Lyo is thinking…' : listening ? 'Listening…' : 'Message Lyo...'
          }
          disabled={isGenerating}
          rows={1}
          className={cn(
            'w-full resize-none bg-transparent text-base text-white placeholder-white/35',
            'focus:outline-none leading-6 py-0.5 max-h-36 scrollbar-thin scrollbar-thumb-white/10',
            'disabled:opacity-50 disabled:cursor-not-allowed'
          )}
          style={{ lineHeight: `${LINE_HEIGHT}px` }}
        />

        {/* Controls row */}
        <div className="flex items-center gap-2 mt-2">
          {/* Attachment ("+") */}
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*,.pdf,.txt,.md,.csv"
            className="hidden"
            onChange={handleFilePicked}
          />
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center text-white/90 hover:bg-white/15 transition-all duration-200 shrink-0 disabled:opacity-50"
            title="Attach an image or document"
          >
            {uploading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-[18px] h-[18px]" strokeWidth={1.5} />}
          </button>

          {/* Mode pill */}
          <span className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-full bg-white/10 text-white text-xs font-semibold select-none">
            <MessageCircle className="w-3.5 h-3.5 fill-current" />
            Chat
          </span>

          <div className="flex-1" />

          {/* Character count */}
          <AnimatePresence>
            {showCount && (
              <motion.span
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.8 }}
                className={cn(
                  'text-[11px] font-mono',
                  charCount > MAX_CHARS * 0.95 ? 'text-red-400' : 'text-white/30'
                )}
              >
                {MAX_CHARS - charCount}
              </motion.span>
            )}
          </AnimatePresence>

          {/* Voice dictation — hidden entirely when the browser can't do it */}
          {speechSupported && (
            <button
              type="button"
              onClick={toggleDictation}
              className={cn(
                'w-8 h-8 rounded-full flex items-center justify-center transition-all duration-200',
                listening
                  ? 'text-accent-orange bg-accent-orange/15 animate-pulse'
                  : 'text-white/90 hover:bg-white/10'
              )}
              title={listening ? 'Stop dictating' : 'Dictate your message'}
            >
              <Mic className="w-[18px] h-[18px]" />
            </button>
          )}

          {/* Send — white circle, dark arrow (iOS) */}
          <motion.button
            type="button"
            onClick={handleSubmit}
            disabled={!canSend}
            whileTap={canSend ? { scale: 0.9 } : {}}
            className={cn(
              'w-8 h-8 rounded-full flex items-center justify-center transition-all duration-200',
              canSend
                ? 'bg-white text-black shadow-lg shadow-black/30 hover:opacity-90'
                : 'bg-white/10 text-white/25 cursor-not-allowed'
            )}
            title="Send message"
          >
            <ArrowUp className="w-4 h-4" strokeWidth={2.5} />
          </motion.button>
        </div>
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
