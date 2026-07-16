import React, { InputHTMLAttributes, TextareaHTMLAttributes, ReactNode, forwardRef } from 'react';
import { cn } from '@/lib/utils';

/* ============================================================
   Shared styles
   ============================================================ */
const baseInputClasses = [
  'w-full bg-[var(--surface-2)] text-[var(--text-primary)] placeholder:text-[var(--text-secondary)]',
  'border border-[var(--border)] rounded-xl',
  'transition-all duration-200',
  'focus:outline-none focus:ring-2 focus:ring-[#6c63ff]/60 focus:border-[#6c63ff]',
  'disabled:opacity-50 disabled:cursor-not-allowed',
].join(' ');

const errorInputClasses = 'border-red-500/70 focus:ring-red-500/40 focus:border-red-500';

/* ============================================================
   Input
   ============================================================ */
interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  icon?: ReactNode;
  className?: string;
  wrapperClassName?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { label, error, icon, className, wrapperClassName, id, ...rest },
  ref,
) {
  const inputId = id ?? (label ? label.toLowerCase().replace(/\s+/g, '-') : undefined);

  return (
    <div className={cn('flex flex-col gap-1.5', wrapperClassName)}>
      {label && (
        <label
          htmlFor={inputId}
          className="text-sm font-medium text-[var(--text-secondary)]"
        >
          {label}
        </label>
      )}

      <div className="relative">
        {icon && (
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--text-secondary)] pointer-events-none">
            {icon}
          </span>
        )}

        <input
          ref={ref}
          id={inputId}
          className={cn(
            baseInputClasses,
            'px-3 py-2.5 text-sm',
            icon && 'pl-9',
            error && errorInputClasses,
            className,
          )}
          aria-invalid={!!error}
          aria-describedby={error ? `${inputId}-error` : undefined}
          {...rest}
        />
      </div>

      {error && (
        <p
          id={`${inputId}-error`}
          className="text-xs text-red-400 flex items-center gap-1"
          role="alert"
        >
          {error}
        </p>
      )}
    </div>
  );
});

/* ============================================================
   Textarea
   ============================================================ */
interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
  icon?: ReactNode;
  className?: string;
  wrapperClassName?: string;
}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function Textarea(
  { label, error, icon, className, wrapperClassName, id, ...rest },
  ref,
) {
  const inputId = id ?? (label ? label.toLowerCase().replace(/\s+/g, '-') : undefined);

  return (
    <div className={cn('flex flex-col gap-1.5', wrapperClassName)}>
      {label && (
        <label
          htmlFor={inputId}
          className="text-sm font-medium text-[var(--text-secondary)]"
        >
          {label}
        </label>
      )}

      <div className="relative">
        {icon && (
          <span className="absolute left-3 top-3 text-[var(--text-secondary)] pointer-events-none">
            {icon}
          </span>
        )}

        <textarea
          ref={ref}
          id={inputId}
          className={cn(
            baseInputClasses,
            'px-3 py-2.5 text-sm resize-none min-h-[100px]',
            icon && 'pl-9',
            error && errorInputClasses,
            className,
          )}
          aria-invalid={!!error}
          aria-describedby={error ? `${inputId}-error` : undefined}
          {...rest}
        />
      </div>

      {error && (
        <p
          id={`${inputId}-error`}
          className="text-xs text-red-400 flex items-center gap-1"
          role="alert"
        >
          {error}
        </p>
      )}
    </div>
  );
});

export default Input;
