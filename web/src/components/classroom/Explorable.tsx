'use client';

import { useMemo, useState } from 'react';
import { Lightbulb } from 'lucide-react';

// ─── Safe expression evaluator ────────────────────────────────────────────────
// Port of the iOS ExpressionEvaluator (24/24 unit-tested there): + - * / ^,
// parens, sin/cos/tan/exp/log/sqrt/abs, pi/e, variables. Pure math — never
// executes code, so LLM-authored expressions are safe.

type Node =
  | { t: 'num'; v: number }
  | { t: 'var'; name: string }
  | { t: 'un'; fn: string; a: Node }
  | { t: 'bin'; op: string; a: Node; b: Node };

const FUNCTIONS = ['sin', 'cos', 'tan', 'exp', 'log', 'ln', 'sqrt', 'abs'];

function compile(expression: string): ((vars: Record<string, number>) => number | null) | null {
  const chars = expression.replace(/\*\*/g, '^').replace(/\s+/g, '');
  let pos = 0;
  const peek = () => chars[pos];

  function parseExpression(): Node | null {
    let lhs = parseTerm();
    if (!lhs) return null;
    while (peek() === '+' || peek() === '-') {
      const op = chars[pos++];
      const rhs = parseTerm();
      if (!rhs) return null;
      lhs = { t: 'bin', op, a: lhs, b: rhs };
    }
    return lhs;
  }
  function parseTerm(): Node | null {
    let lhs = parseUnary();
    if (!lhs) return null;
    while (peek() === '*' || peek() === '/') {
      const op = chars[pos++];
      const rhs = parseUnary();
      if (!rhs) return null;
      lhs = { t: 'bin', op, a: lhs, b: rhs };
    }
    return lhs;
  }
  // Unary minus binds LOOSER than ^ (math convention: -x^2 == -(x^2)).
  function parseUnary(): Node | null {
    if (peek() === '-') {
      pos++;
      const inner = parseUnary();
      return inner ? { t: 'un', fn: 'neg', a: inner } : null;
    }
    if (peek() === '+') pos++;
    return parsePower();
  }
  function parsePower(): Node | null {
    const base = parseAtom();
    if (!base) return null;
    if (peek() === '^') {
      pos++;
      const exp = parseUnary(); // right-assoc, signed exponents ok
      return exp ? { t: 'bin', op: '^', a: base, b: exp } : null;
    }
    return base;
  }
  function parseAtom(): Node | null {
    const c = peek();
    if (!c) return null;
    if (c === '(') {
      pos++;
      const inner = parseExpression();
      if (!inner || peek() !== ')') return null;
      pos++;
      return inner;
    }
    if (/[0-9.]/.test(c)) {
      let s = '';
      while (pos < chars.length && /[0-9.]/.test(chars[pos])) s += chars[pos++];
      const v = Number(s);
      return Number.isFinite(v) ? { t: 'num', v } : null;
    }
    if (/[a-zA-Z]/.test(c)) {
      let name = '';
      while (pos < chars.length && /[a-zA-Z0-9_]/.test(chars[pos])) name += chars[pos++];
      if (FUNCTIONS.includes(name) && peek() === '(') {
        pos++;
        const arg = parseExpression();
        if (!arg || peek() !== ')') return null;
        pos++;
        return { t: 'un', fn: name, a: arg };
      }
      if (name === 'pi') return { t: 'num', v: Math.PI };
      if (name === 'e') return { t: 'num', v: Math.E };
      return { t: 'var', name };
    }
    return null;
  }

  const root = parseExpression();
  if (!root || pos !== chars.length) return null;

  function evalNode(n: Node, vars: Record<string, number>): number | null {
    switch (n.t) {
      case 'num': return n.v;
      case 'var': return vars[n.name] ?? null;
      case 'un': {
        const v = evalNode(n.a, vars);
        if (v === null) return null;
        switch (n.fn) {
          case 'neg': return -v;
          case 'sin': return Math.sin(v);
          case 'cos': return Math.cos(v);
          case 'tan': return Math.tan(v);
          case 'exp': return Math.exp(v);
          case 'log': case 'ln': return v > 0 ? Math.log(v) : null;
          case 'sqrt': return v >= 0 ? Math.sqrt(v) : null;
          case 'abs': return Math.abs(v);
          default: return null;
        }
      }
      case 'bin': {
        const a = evalNode(n.a, vars);
        const b = evalNode(n.b, vars);
        if (a === null || b === null) return null;
        switch (n.op) {
          case '+': return a + b;
          case '-': return a - b;
          case '*': return a * b;
          case '/': return b === 0 ? null : a / b;
          case '^': return Math.pow(a, b);
          default: return null;
        }
      }
    }
  }
  return (vars) => evalNode(root, vars);
}

// ─── The manipulable ─────────────────────────────────────────────────────────

export interface ExplorableParam {
  name: string;
  min: number;
  max: number;
  initial: number;
  step?: number;
}

export function Explorable({
  expression, params, xMin = -5, xMax = 5, prompt,
}: {
  expression: string;
  params: ExplorableParam[];
  xMin?: number;
  xMax?: number;
  prompt?: string;
}) {
  const [values, setValues] = useState<Record<string, number>>(() =>
    Object.fromEntries(params.map((p) => [p.name, p.initial])));

  const evaluate = useMemo(() => compile(expression), [expression]);

  const W = 560, H = 200;
  const domain = Math.max(xMax - xMin, 0.1);

  const path = useMemo(() => {
    if (!evaluate) return null;
    const samples: { x: number; y: number }[] = [];
    const n = 240;
    for (let i = 0; i <= n; i++) {
      const x = xMin + (domain * i) / n;
      const y = evaluate({ ...values, x });
      if (y !== null && Number.isFinite(y)) samples.push({ x, y });
    }
    if (samples.length < 2) return null;

    const ys = samples.map((s) => s.y).sort((a, b) => a - b);
    let lo = ys[Math.floor(ys.length / 20)];
    let hi = ys[ys.length - 1 - Math.floor(ys.length / 20)];
    if (hi - lo < 1e-6) { lo -= 1; hi += 1; }
    const pad = (hi - lo) * 0.15;
    lo -= pad; hi += pad;

    const px = (x: number) => ((x - xMin) / domain) * W;
    const py = (y: number) => H - ((y - lo) / (hi - lo)) * H;

    let d = '';
    let prev: { x: number; y: number } | null = null;
    for (const s of samples) {
      const jump = prev && Math.abs(s.y - prev.y) > (hi - lo) * 2;
      d += `${!prev || jump ? 'M' : 'L'}${px(s.x).toFixed(1)},${py(s.y).toFixed(1)}`;
      prev = s;
    }
    const zeroY = lo < 0 && hi > 0 ? py(0) : null;
    const zeroX = xMin < 0 && xMax > 0 ? px(0) : null;
    return { d, zeroY, zeroX };
  }, [evaluate, values, xMin, xMax, domain]);

  if (!evaluate || !path) {
    return <pre className="text-white/60 text-sm font-mono">{expression}</pre>;
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-[11px] font-black tracking-widest text-lyo-300 uppercase">🎛 Try it yourself</p>
        <code className="text-xs text-white/40 font-mono">{expression}</code>
      </div>

      <svg viewBox={`0 0 ${W} ${H}`} className="w-full max-w-xl mx-auto rounded-xl bg-black/25 border border-white/10">
        {path.zeroY !== null && (
          <line x1={0} x2={W} y1={path.zeroY} y2={path.zeroY} stroke="rgba(255,255,255,0.12)" strokeWidth={1} />
        )}
        {path.zeroX !== null && (
          <line y1={0} y2={H} x1={path.zeroX} x2={path.zeroX} stroke="rgba(255,255,255,0.12)" strokeWidth={1} />
        )}
        <path d={path.d} fill="none" stroke="#A78BFA" strokeWidth={2.5}
          strokeLinecap="round" strokeLinejoin="round" />
      </svg>

      <div className="space-y-2 max-w-xl mx-auto">
        {params.map((p) => (
          <div key={p.name} className="flex items-center gap-3">
            <code className="text-sm font-bold text-white/70 w-8">{p.name}</code>
            <input
              type="range"
              min={p.min}
              max={p.max}
              step={p.step ?? 0.1}
              value={values[p.name] ?? p.initial}
              onChange={(e) => setValues((v) => ({ ...v, [p.name]: Number(e.target.value) }))}
              className="flex-1 accent-accent-purple"
            />
            <span className="text-xs text-white/50 font-mono w-12 text-right">
              {(values[p.name] ?? p.initial).toFixed(2)}
            </span>
          </div>
        ))}
      </div>

      {prompt && (
        <p className="flex items-center gap-2 text-sm text-accent-gold justify-center">
          <Lightbulb className="w-4 h-4" /> {prompt}
        </p>
      )}
    </div>
  );
}
