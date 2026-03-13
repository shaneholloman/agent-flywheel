"use client";

import {
  useRef,
  useState,
  useCallback,
  useEffect,
  type ReactNode,
} from "react";
import { motion, useReducedMotion, useInView, AnimatePresence } from "framer-motion";
import {
  Check,
  Copy,
  ChevronDown,
  Lightbulb,
  AlertTriangle,
  Quote,
  Hash,
  Info,
  X,
  Menu,
} from "lucide-react";
import {
  CodeBlock as SharedCodeBlock,
  type CodeBlockProps as SharedCodeBlockProps,
} from "@/components/ui/code-block";
import { copyTextToClipboard } from "@/lib/utils";

// =============================================================================
// GUIDE SECTION - Anchored sections with gradient headers + scroll reveal
// =============================================================================
interface GuideSectionProps {
  id: string;
  number?: string;
  title: string;
  icon?: ReactNode;
  children: ReactNode;
}

export function GuideSection({
  id,
  number,
  title,
  icon,
  children,
}: GuideSectionProps) {
  const ref = useRef<HTMLElement>(null);
  const isInView = useInView(ref, { once: true, margin: "-100px" });
  const prefersReducedMotion = useReducedMotion();
  const rm = prefersReducedMotion ?? false;

  return (
    <motion.section
      ref={ref}
      id={id}
      initial={rm ? {} : { opacity: 0, y: 15 }}
      animate={isInView ? { opacity: 1, y: 0 } : {}}
      transition={rm ? {} : { type: "spring", stiffness: 100, damping: 20 }}
      className="relative scroll-mt-32"
    >
      {/* Section header */}
      <div className="relative mb-12 group">
        <div className="flex items-center gap-5">
          {number != null && (
            <div className="flex h-12 w-12 sm:h-14 sm:w-14 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-primary/25 to-violet-500/25 border border-primary/40 font-mono text-base sm:text-lg font-black text-primary shadow-[0_0_30px_-5px_var(--color-primary),inset_0_1px_1px_rgba(255,255,255,0.1)] transition-all duration-500 group-hover:shadow-[0_0_50px_-5px_var(--color-primary)] group-hover:scale-110 group-hover:border-primary/60">
              {number}
            </div>
          )}
          {icon && (
            <div className="flex h-12 w-12 sm:h-14 sm:w-14 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-primary/15 to-violet-500/15 border border-primary/20 text-primary transition-all duration-500 group-hover:bg-primary/25 group-hover:border-primary/40 group-hover:shadow-[0_0_30px_-8px_var(--color-primary)]">
              {icon}
            </div>
          )}

          {title.startsWith('Phase ') ? (
            <div className="flex flex-col">
              <span className="text-primary font-mono text-[0.65rem] sm:text-xs uppercase tracking-[0.25em] mb-1.5 font-bold">{title.split(':')[0]}</span>
              <h2 className="text-2xl sm:text-3xl md:text-4xl font-extrabold bg-gradient-to-r from-white via-white to-white/60 bg-clip-text text-transparent tracking-[-0.02em] leading-[1.15]">
                {title.split(':').slice(1).join(':').trim()}
              </h2>
            </div>
          ) : (
            <h2 className="text-2xl sm:text-3xl md:text-4xl font-extrabold bg-gradient-to-r from-white via-white to-white/60 bg-clip-text text-transparent tracking-[-0.02em] leading-[1.15]">
              {title}
            </h2>
          )}
        </div>

        {/* Dramatic separator line with glow */}
        <div className="mt-6 relative">
          <div className="h-px bg-gradient-to-r from-primary/50 via-violet-500/30 to-transparent" />
          <div className="absolute left-0 top-0 h-px w-1/3 bg-gradient-to-r from-primary to-transparent blur-[1px]" />
        </div>
      </div>
      <div className="space-y-8">{children}</div>
    </motion.section>
  );
}

// =============================================================================
// SUBSECTION
// =============================================================================
export function SubSection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <div className="mt-14 first:mt-6">
      <h3 className="text-xl sm:text-2xl font-bold text-white mb-6 flex items-center gap-3 tracking-[-0.01em]">
        <span className="flex items-center justify-center h-7 w-7 rounded-lg bg-gradient-to-br from-primary/20 to-violet-500/15 border border-primary/25 shadow-[0_0_12px_-3px_var(--color-primary)]">
          <Hash className="h-3.5 w-3.5 text-primary" />
        </span>
        {title}
      </h3>
      <div className="space-y-6">{children}</div>
    </div>
  );
}

// =============================================================================
// PARAGRAPH
// =============================================================================
export function P({
  children,
  highlight,
}: {
  children: ReactNode;
  highlight?: boolean;
}) {
  return (
    <p
      className={`text-[0.95rem] sm:text-[1.08rem] leading-[1.75] tracking-[-0.008em] ${
        highlight ? "text-zinc-100 font-medium" : "text-zinc-300/90"
      }`}
    >
      {children}
    </p>
  );
}

// =============================================================================
// BLOCKQUOTE - Elegant quote blocks
// =============================================================================
export function BlockQuote({ children }: { children: ReactNode }) {
  return (
    <div className="relative pl-6 sm:pl-8 py-4 my-8 overflow-hidden rounded-r-xl bg-white/[0.02] backdrop-blur-sm border-r border-y border-white/[0.04]">
      {/* Glowing left accent */}
      <div className="absolute left-0 top-0 bottom-0 w-[3px] rounded-full bg-gradient-to-b from-primary/60 via-violet-400/60 to-primary/60" />
      <div className="absolute left-0 top-0 bottom-0 w-[3px] rounded-full bg-gradient-to-b from-primary via-violet-400 to-primary blur-[3px] opacity-50" />
      <Quote className="absolute left-2 top-2 h-10 w-10 text-primary/[0.06] rotate-180" />
      <div className="relative text-zinc-200 italic leading-[1.8] text-[1.08rem] font-light tracking-[-0.01em]">
        {children}
      </div>
    </div>
  );
}

// =============================================================================
// CODE BLOCK - Terminal-style wrapper
// =============================================================================
export function CodeBlock(
  props: Omit<SharedCodeBlockProps, "variant" | "copyable">,
) {
  return <SharedCodeBlock {...props} variant="terminal" copyable />;
}

// =============================================================================
// PROMPT BLOCK - Collapsible prompt display with copy + metadata
// =============================================================================
export function PromptBlock({
  title,
  prompt,
  where,
  whyItWorks,
}: {
  title: string;
  prompt: string;
  where?: string;
  whyItWorks?: string;
}) {
  const [copied, setCopied] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, []);

  const handleCopy = useCallback(async () => {
    const ok = await copyTextToClipboard(prompt);
    if (!ok) return;
    setCopied(true);
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => {
      setCopied(false);
      timerRef.current = null;
    }, 2000);
  }, [prompt]);

  // Very simple client-side syntax highlighting for structural keywords
  const highlightPrompt = (text: string) => {
    // CRITICAL: Escape HTML first to prevent injection or broken rendering from < tags in prompts
    const escaped = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    const keywords = ['Search', 'Review', 'Read', 'Write', 'Fix', 'Create', 'Update', 'Do we have', 'OK', 'Look', 'Execute'];
    let highlighted = escaped;
    keywords.forEach(kw => {
      const regex = new RegExp(`\\b(${kw})\\b`, 'g');
      highlighted = highlighted.replace(regex, '<span class="text-cyan-400 font-semibold">$1</span>');
    });
    // Highlight bracketed variables like [SKILL] or [TOOL]
    highlighted = highlighted.replace(/(\[[A-Z_]+\])/g, '<span class="text-amber-400">$1</span>');
    return highlighted;
  };

  return (
    <div className="group relative rounded-2xl border border-white/[0.08] bg-[#08080a] overflow-hidden transition-all duration-500 hover:border-primary/20" style={{ boxShadow: "0 8px 32px -4px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.03), inset 0 1px 1px rgba(255,255,255,0.03)" }}>
      {/* Top bar — metal material */}
      <div className="relative flex items-center justify-between px-5 py-3.5 bg-gradient-to-r from-[#141418] to-[#111114] border-b border-white/[0.06] z-10">
        <div className="flex items-center gap-2.5">
          <div className="w-3 h-3 rounded-full bg-[#ff5f56] shadow-[0_0_6px_rgba(255,95,86,0.3),inset_0_1px_1px_rgba(255,255,255,0.2)]" />
          <div className="w-3 h-3 rounded-full bg-[#ffbd2e] shadow-[0_0_6px_rgba(255,189,46,0.3),inset_0_1px_1px_rgba(255,255,255,0.2)]" />
          <div className="w-3 h-3 rounded-full bg-[#27c93f] shadow-[0_0_6px_rgba(39,201,63,0.3),inset_0_1px_1px_rgba(255,255,255,0.2)]" />
          <span className="ml-3 text-xs font-mono text-white/40 tracking-wide uppercase">{title}</span>
        </div>
        <motion.button
          whileTap={{ scale: 0.95 }}
          onClick={handleCopy}
          className="opacity-0 group-hover:opacity-100 transition-all duration-300 flex items-center gap-1.5 rounded-lg bg-white/[0.06] px-3 py-1.5 text-xs text-white/70 hover:bg-primary/20 hover:text-primary border border-white/[0.06] hover:border-primary/30"
        >
          {copied ? <Check className="h-3.5 w-3.5 text-emerald-400" /> : <Copy className="h-3.5 w-3.5" />}
          {copied ? "Copied" : "Copy"}
        </motion.button>
      </div>
      {/* Prompt body */}
      <div className="relative z-10">
        <div
          className="px-6 py-6 text-[0.9rem] text-zinc-400 whitespace-pre-wrap font-mono leading-[1.75] overflow-x-auto scrollbar-thin scrollbar-thumb-white/10 scrollbar-track-transparent selection:bg-cyan-900/40 selection:text-white"
          dangerouslySetInnerHTML={{ __html: highlightPrompt(prompt) + '<span class="inline-block w-2.5 h-[1.1em] ml-1.5 align-middle bg-cyan-400/80 animate-blink shadow-[0_0_8px_rgba(34,211,238,0.6)]" />' }}
        />
      </div>
      {/* Metadata footer */}
      <AnimatePresence>
        {(where || whyItWorks) && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            className="relative z-10 bg-gradient-to-r from-primary/[0.03] to-transparent border-t border-white/[0.06] p-5 space-y-4"
          >
            {where && (
              <p className="text-xs text-primary/80 font-mono">
                <span className="text-white/40 mr-1">Location:</span> {where}
              </p>
            )}
            {whyItWorks && (
              <div className="flex items-start gap-2.5">
                <Lightbulb className="h-4 w-4 text-amber-400 shrink-0 mt-0.5 drop-shadow-[0_0_4px_rgba(251,191,36,0.4)]" />
                <p className="text-xs sm:text-sm text-zinc-300/80 leading-relaxed">{whyItWorks}</p>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// =============================================================================
// DATA TABLE - Responsive with mobile scroll indicator
// =============================================================================
export function DataTable({
  headers,
  rows,
}: {
  headers: string[];
  rows: (string | ReactNode)[][];
}) {
  return (
    <div className="relative group">
      {/* Mobile scroll hint */}
      <div className="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-[oklch(0.15_0.01_260)] to-transparent pointer-events-none z-10 opacity-100 sm:opacity-0 transition-opacity" />
      <div className="overflow-x-auto rounded-2xl border border-white/[0.08] scrollbar-thin scrollbar-thumb-white/10 scrollbar-track-transparent backdrop-blur-sm" style={{ boxShadow: "0 4px 24px -1px rgba(0,0,0,0.3), inset 0 1px 1px rgba(255,255,255,0.03)" }}>
        <table className="w-full text-sm min-w-[500px]">
          <thead>
            <tr className="border-b border-primary/15 bg-gradient-to-r from-primary/[0.06] via-violet-500/[0.04] to-transparent">
              {headers.map((h, i) => (
                <th
                  key={i}
                  className="px-3 sm:px-5 py-3.5 text-left font-bold text-white/90 text-xs sm:text-sm whitespace-nowrap tracking-wide"
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, ri) => (
              <tr
                key={ri}
                className="border-b border-white/[0.04] last:border-0 transition-colors hover:bg-primary/[0.03]"
              >
                {row.map((cell, ci) => (
                  <td key={ci} className="px-3 sm:px-5 py-3 text-zinc-300/80 text-xs sm:text-sm">
                    {cell}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

// =============================================================================
// PHASE CARD - With subtle hover glow
// =============================================================================
export function PhaseCard({
  phase,
  title,
  description,
  gradient = "from-primary/20 to-violet-500/20",
  children,
}: {
  phase: string;
  title: string;
  description: string;
  gradient?: string;
  children?: ReactNode;
}) {
  return (
    <div
      className="group relative rounded-2xl bg-slate-900/60 p-6 sm:p-8 overflow-hidden transition-all duration-500 hover:-translate-y-1 border border-white/[0.08] hover:border-primary/30 backdrop-blur-sm"
      style={{ boxShadow: "0 4px 24px -1px rgba(0,0,0,0.4), inset 0 1px 1px rgba(255,255,255,0.04)" }}
    >
      {/* Dynamic Hover Gradient */}
      <div className={`absolute inset-0 opacity-0 group-hover:opacity-100 bg-gradient-to-br ${gradient} transition-opacity duration-500 pointer-events-none`} style={{ opacity: 0 }} />

      {/* Top highlight */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/[0.08] to-transparent group-hover:via-primary/30 transition-colors duration-500" />

      <div className="relative z-10 flex items-start gap-4 sm:gap-6">
        <div className="flex h-13 w-13 sm:h-14 sm:w-14 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-primary/25 to-violet-500/20 border border-primary/30 font-mono text-lg sm:text-xl font-black text-primary shadow-[0_0_25px_-5px_var(--color-primary),inset_0_1px_1px_rgba(255,255,255,0.1)] group-hover:shadow-[0_0_40px_-5px_var(--color-primary)] group-hover:scale-105 transition-all duration-500">
          {phase}
        </div>
        <div className="flex-1 min-w-0">
          <h3 className="font-bold text-white text-lg sm:text-xl tracking-[-0.01em]">{title}</h3>
          <p className="mt-2 text-sm sm:text-base text-zinc-300/80 leading-relaxed">{description}</p>
          {children && <div className="mt-5">{children}</div>}
        </div>
      </div>
    </div>
  );
}

// =============================================================================
// TIP BOX - Tips, warnings, info boxes
// =============================================================================
export function TipBox({
  children,
  variant = "tip",
}: {
  children: ReactNode;
  variant?: "tip" | "warning" | "info";
}) {
  const config = {
    tip: {
      icon: <Lightbulb className="h-5 w-5" />,
      gradient: "from-amber-500/10 to-orange-500/5",
      border: "border-amber-500/20",
      iconColor: "text-amber-400",
      title: "Pro Tip",
    },
    warning: {
      icon: <AlertTriangle className="h-5 w-5" />,
      gradient: "from-red-500/10 to-rose-500/5",
      border: "border-red-500/20",
      iconColor: "text-red-400",
      title: "Warning",
    },
    info: {
      icon: <Info className="h-5 w-5" />,
      gradient: "from-primary/10 to-violet-500/5",
      border: "border-primary/20",
      iconColor: "text-primary",
      title: "Key Insight",
    },
  };
  const c = config[variant];

  return (
    <div
      className={`relative rounded-2xl border ${c.border} bg-gradient-to-br ${c.gradient} p-5 sm:p-6 backdrop-blur-sm overflow-hidden`}
      style={{ boxShadow: "0 4px 24px -1px rgba(0,0,0,0.3), inset 0 1px 1px rgba(255,255,255,0.04)" }}
    >
      {/* Subtle top highlight */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />
      <div className="relative flex gap-3.5 sm:gap-4">
        <div className={`shrink-0 mt-0.5 ${c.iconColor} drop-shadow-[0_0_6px_currentColor]`}>{c.icon}</div>
        <div className="min-w-0">
          <span
            className={`text-[0.65rem] sm:text-xs font-bold ${c.iconColor} uppercase tracking-[0.15em]`}
          >
            {c.title}
          </span>
          <div className="mt-2 sm:mt-2.5 text-zinc-300/90 text-sm sm:text-[0.95rem] leading-[1.7]">{children}</div>
        </div>
      </div>
    </div>
  );
}

// =============================================================================
// TOOL PILL - Small badge for tool names
// =============================================================================
export function ToolPill({ children }: { children: ReactNode }) {
  return (
    <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md bg-primary/10 border border-primary/25 text-primary text-xs font-mono font-semibold whitespace-nowrap shadow-[0_0_10px_-3px_var(--color-primary)]">
      {children}
    </span>
  );
}

// =============================================================================
// INLINE CODE
// =============================================================================
export function IC({ children }: { children: ReactNode }) {
  return (
    <code className="px-1.5 py-0.5 rounded-md bg-emerald-500/[0.08] border border-emerald-500/15 text-emerald-400 text-xs sm:text-sm font-mono font-medium break-all shadow-[0_0_8px_-3px_rgba(52,211,153,0.2)]">
      {children}
    </code>
  );
}

// =============================================================================
// HIGHLIGHT - Gradient highlighted text
// =============================================================================
export function Hl({ children }: { children: ReactNode }) {
  return (
    <span className="font-bold bg-gradient-to-r from-primary via-cyan-300 to-violet-400 bg-clip-text text-transparent drop-shadow-[0_0_12px_var(--color-primary)]">
      {children}
    </span>
  );
}

// =============================================================================
// BULLET LIST
// =============================================================================
export function BulletList({ items }: { items: (string | ReactNode)[] }) {
  return (
    <ul className="space-y-3.5">
      {items.map((item, i) => (
        <li key={i} className="flex items-start gap-3.5">
          <div className="mt-[0.55rem] h-2 w-2 rounded-full bg-gradient-to-br from-primary to-violet-400 shrink-0 shadow-[0_0_10px_var(--color-primary)]" />
          <span className="text-zinc-300/90 text-[0.95rem] sm:text-[1.05rem] leading-[1.7] tracking-[-0.008em]">{item}</span>
        </li>
      ))}
    </ul>
  );
}

// =============================================================================
// NUMBERED LIST
// =============================================================================
export function NumberedList({ items }: { items: (string | ReactNode)[] }) {
  return (
    <ol className="space-y-4">
      {items.map((item, i) => (
        <li key={i} className="flex items-start gap-4">
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-primary/30 to-violet-500/25 border border-primary/20 text-[0.7rem] font-bold text-primary shadow-[0_0_12px_-3px_var(--color-primary),inset_0_1px_1px_rgba(255,255,255,0.1)]">
            {i + 1}
          </span>
          <span className="text-zinc-300/90 text-[0.95rem] sm:text-[1.05rem] leading-[1.7] tracking-[-0.008em] pt-0.5">{item}</span>
        </li>
      ))}
    </ol>
  );
}

// =============================================================================
// DIVIDER
// =============================================================================
export function Divider() {
  return (
    <div className="relative my-16 sm:my-20 flex items-center justify-center">
      <div className="absolute inset-x-0 h-px bg-gradient-to-r from-transparent via-primary/20 to-transparent" />
      <div className="absolute inset-x-0 h-px bg-gradient-to-r from-transparent via-primary/30 to-transparent blur-[2px]" />
      <div className="relative h-2 w-2 rounded-full bg-gradient-to-br from-primary to-violet-400 shadow-[0_0_12px_var(--color-primary)]" />
    </div>
  );
}

// =============================================================================
// STAT CARD - For metrics and numbers
// =============================================================================
export function StatCard({
  value,
  label,
  sublabel,
}: {
  value: string;
  label: string;
  sublabel?: string;
}) {
  return (
    <div className="relative rounded-2xl border border-primary/15 bg-primary/[0.03] p-4 sm:p-5 text-center backdrop-blur-sm" style={{ boxShadow: "0 4px 24px -1px rgba(0,0,0,0.3), 0 0 20px -5px var(--color-primary, rgba(34,211,238,0.1)), inset 0 1px 1px rgba(255,255,255,0.04)" }}>
      <div className="text-2xl sm:text-3xl font-black bg-gradient-to-r from-primary to-violet-400 bg-clip-text text-transparent tracking-tight">
        {value}
      </div>
      <div className="mt-1 text-xs sm:text-sm text-white/60 font-medium">{label}</div>
      {sublabel && <div className="mt-0.5 text-[0.65rem] text-white/35">{sublabel}</div>}
    </div>
  );
}

// =============================================================================
// PRINCIPLE CARD - For the 13 key principles
// =============================================================================
export function PrincipleCard({
  number,
  title,
  children,
  gradient,
}: {
  number: string;
  title: string;
  children: ReactNode;
  gradient?: string;
}) {
  const [open, setOpen] = useState(false);
  const hasContent = children != null;

  return (
    <div
      className="group relative rounded-2xl border border-white/[0.08] bg-slate-900/60 overflow-hidden transition-all duration-500 hover:border-primary/30 backdrop-blur-sm hover:-translate-y-0.5"
      style={{ boxShadow: "0 4px 24px -1px rgba(0,0,0,0.3), inset 0 1px 1px rgba(255,255,255,0.04)" }}
    >
      {/* Hover glow overlay */}
      <div className={`absolute inset-0 opacity-0 group-hover:opacity-100 bg-gradient-to-br ${gradient || "from-primary/[0.04] to-violet-500/[0.02]"} transition-opacity duration-500 pointer-events-none`} />
      {/* Top highlight */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/[0.08] to-transparent group-hover:via-primary/20 transition-colors duration-500" />

      <button
        onClick={() => hasContent && setOpen(!open)}
        className={`w-full relative z-10 flex items-start gap-4 p-5 sm:p-6 text-left ${hasContent ? "cursor-pointer" : "cursor-default"}`}
        aria-expanded={open}
        disabled={!hasContent}
      >
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-primary/25 to-violet-500/20 border border-primary/25 font-mono text-sm font-bold text-primary shadow-[0_0_15px_-3px_var(--color-primary),inset_0_1px_1px_rgba(255,255,255,0.1)] group-hover:scale-110 group-hover:border-primary/50 group-hover:shadow-[0_0_25px_-3px_var(--color-primary)] transition-all duration-300">
          {number}
        </div>
        <div className="flex-1 min-w-0 flex items-center h-10">
          <h4 className="font-bold text-white/90 text-base sm:text-lg leading-snug tracking-[-0.01em] group-hover:text-white transition-colors duration-300">{title}</h4>
        </div>
        {hasContent && (
          <div className="flex h-10 items-center">
            <ChevronDown className={`h-5 w-5 text-white/30 shrink-0 transition-all duration-300 group-hover:text-primary/70 ${open ? "rotate-180" : ""}`} />
          </div>
        )}
      </button>
      <AnimatePresence>
        {open && hasContent && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
            className="overflow-hidden relative z-10"
          >
            <div className="px-5 sm:px-6 pb-5 sm:pb-6 pt-0 text-zinc-300/80 text-sm sm:text-[0.95rem] leading-[1.7] border-t border-white/[0.06] mt-0 pt-5">
              {children}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// =============================================================================
// OPERATOR CARD - For the 8 operators in Section 21
// =============================================================================
export function OperatorCard({
  number,
  name,
  definition,
  trigger,
  failureMode,
  children,
}: {
  number: string;
  name: string;
  definition: string;
  trigger?: string;
  failureMode?: string;
  children?: ReactNode;
}) {
  return (
    <div className="group relative rounded-2xl border border-white/[0.08] bg-[#0a0a0c] p-5 sm:p-6 shadow-lg transition-all duration-300 hover:border-emerald-500/30 hover:shadow-[0_10px_30px_-10px_rgba(16,185,129,0.15)] space-y-4 overflow-hidden">
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-emerald-500/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
      
      <div className="relative z-10 flex items-start gap-4">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-b from-emerald-500/20 to-emerald-500/5 border border-emerald-500/30 font-mono text-sm font-bold text-emerald-400 shadow-[inset_0_1px_1px_rgba(255,255,255,0.1)]">
          {number}
        </div>
        <div className="min-w-0">
          <h4 className="font-semibold text-white text-base sm:text-lg tracking-tight">{name}</h4>
          <p className="mt-1.5 text-sm sm:text-[0.95rem] text-white/60 leading-relaxed font-light">{definition}</p>
        </div>
      </div>
      {trigger && (
        <div className="relative z-10 flex items-start gap-3 text-sm text-white/50 pl-[3.5rem]">
          <span className="text-emerald-400/80 font-medium shrink-0 uppercase tracking-wider text-xs mt-0.5">Trigger</span>
          <span className="leading-relaxed">{trigger}</span>
        </div>
      )}
      {failureMode && (
        <div className="relative z-10 flex items-start gap-3 text-sm text-white/50 pl-[3.5rem]">
          <span className="text-red-400/80 font-medium shrink-0 uppercase tracking-wider text-xs mt-0.5">Failure</span>
          <span className="leading-relaxed">{failureMode}</span>
        </div>
      )}
      {children && <div className="relative z-10 pl-[3.5rem] text-sm text-white/60 pt-2 border-t border-white/[0.05] mt-4 font-light leading-relaxed">{children}</div>}
    </div>
  );
}

// =============================================================================
// FLYWHEEL DIAGRAM - Interactive compounding loop explainer
// =============================================================================
export function FlywheelDiagram() {
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: true, margin: "-100px" });
  const prefersReducedMotion = useReducedMotion();
  const rm = prefersReducedMotion ?? false;
  const [activeStage, setActiveStage] = useState(0);
  const [cycleDepth, setCycleDepth] = useState(1);
  const [autoTour, setAutoTour] = useState(true);

  const stages = [
    {
      id: "human-intent",
      label: "Human Intent",
      short: "Goals + workflows",
      x: 320,
      y: 68,
      color: "#22d3ee",
      input: "Raw desire and taste",
      output: "Explicit constraints and workflows",
      effect: "Human judgment compresses ambiguity before any downstream artifact starts drifting.",
    },
    {
      id: "markdown-plan",
      label: "Markdown Plan",
      short: "Whole-system reasoning",
      x: 518,
      y: 154,
      color: "#a78bfa",
      input: "Clarified goals",
      output: "A design that still fits in context",
      effect: "Architecture gets settled while global reasoning is still cheap and actually possible.",
    },
    {
      id: "building-beads",
      label: "Bead Graph",
      short: "Executable memory",
      x: 452,
      y: 336,
      color: "#f472b6",
      input: "Approved plan decisions",
      output: "Self-contained work packets",
      effect: "Context leaves prose and enters the execution graph where fresh agents can actually use it.",
    },
    {
      id: "swarm-execution",
      label: "Swarm Execution",
      short: "Parallel implementation",
      x: 188,
      y: 336,
      color: "#34d399",
      input: "Prioritized ready beads",
      output: "Code, tests, reviews, commits",
      effect: "Fungible agents stay busy on the frontier instead of improvising their own architecture.",
    },
    {
      id: "memory-and-knowledge",
      label: "Memory & QA",
      short: "CASS, UBS, lessons",
      x: 122,
      y: 154,
      color: "#fbbf24",
      input: "Session history and defects",
      output: "Better prompts and sharper defaults",
      effect: "The next loop starts with stronger artifacts than the previous loop had on day zero.",
    },
  ] as const;

  const cycleOptions = [1, 3, 6] as const;
  const metrics = [
    { label: "Planning leverage", value: Math.min(99, 58 + cycleDepth * 12) },
    { label: "Swarm determinism", value: Math.min(99, 42 + cycleDepth * 18) },
    { label: "Reusable memory", value: Math.min(99, 28 + cycleDepth * 24) },
  ];
  const loopVelocity = [1, 1.8, 3.2][cycleDepth];
  const currentStage = stages[activeStage];

  useEffect(() => {
    if (!isInView || rm || !autoTour) return undefined;

    const intervalId = window.setInterval(() => {
      setActiveStage((current) => (current + 1) % stages.length);
    }, 2600);

    return () => window.clearInterval(intervalId);
  }, [autoTour, isInView, rm, stages.length]);

  const getConnectorPath = (from: { x: number; y: number }, to: { x: number; y: number }) => {
    const center = { x: 320, y: 210 };
    const midX = (from.x + to.x) / 2;
    const midY = (from.y + to.y) / 2;
    const controlX = midX + (center.x - midX) * 0.26;
    const controlY = midY + (center.y - midY) * 0.26;
    return `M ${from.x} ${from.y} Q ${controlX} ${controlY} ${to.x} ${to.y}`;
  };

  return (
    <div
      ref={ref}
      className="my-8 rounded-[28px] border border-white/[0.12] bg-[radial-gradient(circle_at_top,rgba(34,211,238,0.12),transparent_42%),linear-gradient(180deg,rgba(15,23,42,0.96),rgba(2,6,23,0.96))] p-5 sm:p-6 lg:p-7 backdrop-blur-xl shadow-[0_35px_90px_-40px_rgba(2,6,23,0.95),inset_0_1px_1px_rgba(255,255,255,0.08)]"
    >
      <div className="flex flex-col gap-4 border-b border-white/10 pb-5 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <div className="text-[0.65rem] font-semibold uppercase tracking-[0.28em] text-cyan-300/70">
            Interactive Exhibit
          </div>
          <h4 className="mt-2 text-xl font-black tracking-[-0.03em] text-white sm:text-2xl">
            Why the flywheel compounds instead of spinning in place
          </h4>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-white/60">
            Step through the loop a few times. The same project gets faster and safer
            because every completed cycle upgrades the artifacts feeding the next one.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <span className="text-[10px] uppercase tracking-[0.22em] text-white/35">
            Loop depth
          </span>
          {cycleOptions.map((cycleCount, index) => (
            <button
              key={cycleCount}
              type="button"
              aria-pressed={cycleDepth === index}
              onClick={() => {
                setCycleDepth(index);
                setAutoTour(false);
              }}
              className={`min-h-[44px] rounded-full border px-4 py-2 text-xs font-semibold transition-colors ${
                cycleDepth === index
                  ? "border-cyan-400/60 bg-cyan-400/15 text-cyan-200"
                  : "border-white/10 bg-white/[0.03] text-white/55 hover:border-white/20 hover:text-white/80"
              }`}
            >
              Loop {cycleCount}
            </button>
          ))}
          <button
            type="button"
            aria-pressed={autoTour}
            onClick={() => setAutoTour((current) => !current)}
            className={`min-h-[44px] rounded-full border px-4 py-2 text-xs font-semibold transition-colors ${
              autoTour
                ? "border-violet-400/50 bg-violet-400/15 text-violet-200"
                : "border-white/10 bg-white/[0.03] text-white/55 hover:border-white/20 hover:text-white/80"
            }`}
          >
            {autoTour ? "Auto touring" : "Auto paused"}
          </button>
        </div>
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1.2fr_0.9fr]">
        <div className="relative overflow-hidden rounded-[30px] border border-white/10 bg-white/[0.03] p-3 sm:p-4">
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(34,211,238,0.12),transparent_50%),radial-gradient(circle_at_bottom_left,rgba(167,139,250,0.12),transparent_42%)]" />

          <svg
            viewBox="0 0 640 420"
            className="relative z-10 w-full"
            role="img"
            aria-label="Interactive flywheel diagram showing human intent, planning, beads, swarm execution, and memory reinforcing one another across repeated loops."
          >
            <defs>
              <linearGradient id="flywheel-ring-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#22d3ee" />
                <stop offset="45%" stopColor="#a78bfa" />
                <stop offset="75%" stopColor="#f472b6" />
                <stop offset="100%" stopColor="#34d399" />
              </linearGradient>
              <filter id="flywheel-stage-glow" x="-80%" y="-80%" width="260%" height="260%">
                <feGaussianBlur stdDeviation="10" result="blur" />
                <feMerge>
                  <feMergeNode in="blur" />
                  <feMergeNode in="SourceGraphic" />
                </feMerge>
              </filter>
            </defs>

            <ellipse
              cx="320"
              cy="210"
              rx="222"
              ry="150"
              fill="none"
              stroke="url(#flywheel-ring-gradient)"
              strokeOpacity="0.18"
              strokeWidth="1.5"
            />

            {stages.map((stage, index) => {
              const nextStage = stages[(index + 1) % stages.length];
              const isActive = index === activeStage;

              return (
                <motion.path
                  key={`${stage.id}-${nextStage.id}`}
                  d={getConnectorPath(stage, nextStage)}
                  fill="none"
                  stroke={isActive ? stage.color : "#334155"}
                  strokeOpacity={isActive ? 0.9 : 0.45}
                  strokeWidth={isActive ? 3 : 1.6}
                  strokeDasharray={isActive ? "10 8" : "6 7"}
                  initial={false}
                  animate={rm ? undefined : { strokeDashoffset: isActive ? -48 : 0 }}
                  transition={rm ? undefined : { duration: 2.2, repeat: Infinity, ease: "linear" }}
                />
              );
            })}

            {!rm &&
              [0, 1, 2].map((orbitalIndex) => (
                <motion.g
                  key={`orbit-${orbitalIndex}`}
                  style={{ transformOrigin: "320px 210px" }}
                  animate={{ rotate: 360 }}
                  transition={{
                    duration: 18 - cycleDepth * 4 + orbitalIndex * 2,
                    repeat: Infinity,
                    ease: "linear",
                  }}
                >
                  <circle
                    cx="320"
                    cy={78 + orbitalIndex * 18}
                    r={orbitalIndex === 2 ? 4 : 5}
                    fill={orbitalIndex === 1 ? "#a78bfa" : "#22d3ee"}
                    fillOpacity={0.8 - orbitalIndex * 0.15}
                    filter="url(#flywheel-stage-glow)"
                  />
                </motion.g>
              ))}

            <g>
              <circle cx="320" cy="210" r="68" fill="rgba(8,15,31,0.92)" stroke="rgba(255,255,255,0.12)" />
              <circle cx="320" cy="210" r="47" fill="rgba(34,211,238,0.08)" stroke="rgba(34,211,238,0.22)" />
              <text x="320" y="194" textAnchor="middle" className="fill-white/45 text-[11px] uppercase tracking-[0.28em]">
                cycle {cycleOptions[cycleDepth]}
              </text>
              <text x="320" y="218" textAnchor="middle" className="fill-white text-[30px] font-black">
                {loopVelocity.toFixed(1)}x
              </text>
              <text x="320" y="238" textAnchor="middle" className="fill-cyan-200/80 text-[10px] uppercase tracking-[0.18em]">
                loop velocity
              </text>
            </g>

            {stages.map((stage, index) => {
              const isActive = index === activeStage;
              return (
                <motion.g
                  key={stage.id}
                  initial={rm ? false : { opacity: 0, scale: 0.85 }}
                  animate={isInView ? { opacity: 1, scale: isActive ? 1.08 : 1 } : undefined}
                  transition={{
                    type: "spring",
                    stiffness: 220,
                    damping: 20,
                    delay: rm ? 0 : index * 0.08,
                  }}
                  onMouseEnter={() => {
                    setActiveStage(index);
                    setAutoTour(false);
                  }}
                  onFocus={() => {
                    setActiveStage(index);
                    setAutoTour(false);
                  }}
                  onClick={() => {
                    setActiveStage(index);
                    setAutoTour(false);
                  }}
                  className="cursor-pointer"
                >
                  <circle cx={stage.x} cy={stage.y} r="44" fill="transparent" />
                  <circle
                    cx={stage.x}
                    cy={stage.y}
                    r={isActive ? 33 : 28}
                    fill={isActive ? `${stage.color}30` : "rgba(15,23,42,0.92)"}
                    stroke={stage.color}
                    strokeWidth={isActive ? 3 : 2}
                    filter={isActive ? "url(#flywheel-stage-glow)" : undefined}
                  />
                  <text x={stage.x} y={stage.y - 2} textAnchor="middle" className="fill-white text-[12px] font-bold">
                    {stage.label}
                  </text>
                  <text x={stage.x} y={stage.y + 15} textAnchor="middle" className="fill-white/45 text-[9px]">
                    {stage.short}
                  </text>
                </motion.g>
              );
            })}
          </svg>
        </div>

        <div className="space-y-4">
          <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-1">
            {stages.map((stage, index) => {
              const isActive = index === activeStage;
              return (
                <button
                  key={stage.id}
                  type="button"
                  aria-pressed={isActive}
                  onClick={() => {
                    setActiveStage(index);
                    setAutoTour(false);
                  }}
                  className={`min-h-[44px] rounded-2xl border px-4 py-3 text-left transition-colors ${
                    isActive
                      ? "border-white/20 bg-white/[0.08]"
                      : "border-white/8 bg-white/[0.03] hover:border-white/15 hover:bg-white/[0.05]"
                  }`}
                >
                  <div className="text-xs font-semibold uppercase tracking-[0.18em]" style={{ color: stage.color }}>
                    {stage.label}
                  </div>
                  <div className="mt-1 text-sm text-white/55">{stage.short}</div>
                </button>
              );
            })}
          </div>

          <AnimatePresence mode="wait">
            <motion.div
              key={currentStage.id}
              initial={rm ? { opacity: 1 } : { opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              exit={rm ? { opacity: 1 } : { opacity: 0, y: -12 }}
              transition={{ type: "spring", stiffness: 210, damping: 24 }}
              className="rounded-[26px] border border-white/10 bg-white/[0.04] p-5"
            >
              <div className="text-[0.65rem] font-semibold uppercase tracking-[0.22em]" style={{ color: currentStage.color }}>
                Active stage
              </div>
              <div className="mt-2 text-2xl font-black tracking-[-0.03em] text-white">
                {currentStage.label}
              </div>
              <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-1">
                <div className="rounded-2xl border border-white/8 bg-slate-950/60 p-4">
                  <div className="text-[10px] uppercase tracking-[0.22em] text-white/35">What enters</div>
                  <div className="mt-2 text-sm text-white/72">{currentStage.input}</div>
                </div>
                <div className="rounded-2xl border border-white/8 bg-slate-950/60 p-4">
                  <div className="text-[10px] uppercase tracking-[0.22em] text-white/35">What leaves</div>
                  <div className="mt-2 text-sm text-white/72">{currentStage.output}</div>
                </div>
              </div>
              <p className="mt-4 text-sm leading-relaxed text-white/60">{currentStage.effect}</p>
            </motion.div>
          </AnimatePresence>

          <div className="rounded-[26px] border border-white/10 bg-slate-950/60 p-5">
            <div className="text-[0.65rem] font-semibold uppercase tracking-[0.22em] text-white/35">
              Compounding signals after loop {cycleOptions[cycleDepth]}
            </div>
            <div className="mt-4 space-y-3">
              {metrics.map((metric) => (
                <div key={metric.label}>
                  <div className="mb-1 flex items-center justify-between text-xs text-white/55">
                    <span>{metric.label}</span>
                    <span className="font-mono text-white/78">{metric.value}%</span>
                  </div>
                  <div className="h-2 rounded-full bg-white/6">
                    <motion.div
                      className="h-full rounded-full bg-gradient-to-r from-cyan-400 via-violet-400 to-emerald-400"
                      initial={rm ? { width: `${metric.value}%` } : { width: 0 }}
                      animate={{ width: `${metric.value}%` }}
                      transition={{ duration: 0.75, ease: "easeOut" }}
                    />
                  </div>
                </div>
              ))}
            </div>
            <p className="mt-4 text-sm leading-relaxed text-white/55">
              Every full turn upgrades the next starting point: sharper prompts,
              richer beads, better review instincts, and more reusable memory.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

// =============================================================================
// TABLE OF CONTENTS - Desktop sidebar + mobile drawer
// =============================================================================
interface TocItem {
  id: string;
  label: string;
  number?: string;
}

export function TableOfContents({ items }: { items: TocItem[] }) {
  const [activeId, setActiveId] = useState<string>("");
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            setActiveId(entry.target.id);
          }
        }
      },
      // Narrower intersection margin to make the active section more accurate
      { rootMargin: "-15% 0% -80% 0%", threshold: 0 },
    );

    for (const item of items) {
      const el = document.getElementById(item.id);
      if (el) observer.observe(el);
    }
    return () => observer.disconnect();
  }, [items]);

  // Progress calculation
  const activeIndex = items.findIndex(i => i.id === activeId);
  const progress = items.length > 0 ? (Math.max(0, activeIndex) / (items.length - 1)) * 100 : 0;

  const tocContent = (
    <nav className="relative space-y-1" aria-label="Table of contents">
      {/* Progress bar */}
      <div className="mb-4 px-3">
        <div className="flex items-center justify-between text-[0.65rem] text-white/40 mb-1.5 uppercase tracking-wider font-semibold">
          <span>Progress</span>
          <span>{Math.round(progress)}%</span>
        </div>
        <div className="h-1 rounded-full bg-white/[0.06] overflow-hidden">
          <motion.div
            className="h-full rounded-full bg-gradient-to-r from-primary to-violet-500 shadow-glow-sm"
            initial={{ width: 0 }}
            animate={{ width: `${progress}%` }}
            transition={{ duration: 0.3 }}
          />
        </div>
      </div>
      {items.map((item, index) => {
        const isActive = activeId === item.id;
        const isPast = activeIndex > index;

        return (
          <a
            key={item.id}
            href={`#${item.id}`}
            onClick={() => setMobileOpen(false)}
            className={`relative flex items-center gap-3 px-3 py-2 text-[0.8rem] sm:text-sm transition-all duration-300 rounded-lg group ${
              isActive
                ? "text-primary font-medium"
                : isPast
                ? "text-white/30 hover:text-white/50"
                : "text-white/60 hover:text-white/90"
            }`}
          >
            {isActive && (
              <motion.div
                layoutId="toc-indicator"
                className="absolute left-0 w-0.5 h-[60%] bg-primary shadow-[0_0_10px_oklch(0.75_0.18_195)] rounded-r-full"
                transition={{ type: "spring", stiffness: 300, damping: 30 }}
              />
            )}
            
            {/* Hover highlight background */}
            <div className={`absolute inset-0 rounded-lg transition-colors duration-200 ${isActive ? "bg-primary/[0.08]" : "group-hover:bg-white/[0.03]"}`} />

            {item.number != null && (
              <span className={`relative z-10 font-mono text-[0.65rem] w-4 text-center ${isActive ? "opacity-100 text-primary" : "opacity-40"}`}>
                {item.number}
              </span>
            )}
            <span className="relative z-10 truncate">{item.label}</span>
          </a>
        );
      })}
    </nav>
  );

  return (
    <>
      {/* Desktop TOC */}
      <div className="hidden lg:block">
        {tocContent}
      </div>

      {/* Mobile TOC trigger */}
      <div className="lg:hidden fixed bottom-6 right-6 z-50">
        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="flex h-14 w-14 items-center justify-center rounded-full bg-primary text-white shadow-[0_0_20px_rgba(var(--color-primary),0.5)] transition-transform active:scale-95 hover:scale-105"
          aria-label="Toggle table of contents"
        >
          {mobileOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
        </button>
      </div>

      {/* Mobile TOC drawer */}
      <AnimatePresence>
        {mobileOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black/60 backdrop-blur-sm z-40 lg:hidden"
              onClick={() => setMobileOpen(false)}
            />
            <motion.div
              initial={{ x: "100%" }}
              animate={{ x: 0 }}
              exit={{ x: "100%" }}
              transition={{ type: "spring", stiffness: 300, damping: 30 }}
              className="fixed right-0 top-0 bottom-0 w-[85vw] max-w-sm bg-[#0a0a0c] border-l border-white/[0.08] z-50 lg:hidden overflow-y-auto p-4 pt-6 shadow-2xl"
            >
              <div className="flex items-center justify-between mb-8 px-2 border-b border-white/[0.05] pb-4">
                <span className="text-xs font-semibold text-primary/70 uppercase tracking-[0.2em]">Navigation</span>
                <button
                  onClick={() => setMobileOpen(false)}
                  className="p-2 rounded-full hover:bg-white/10 text-white/60 transition-colors"
                  aria-label="Close"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>
              <div className="px-2 pb-12">
                {tocContent}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  );
}

export * from "./guide-components";
export * from "./plan-to-beads-viz";
export * from "./swarm-execution-viz";
export * from "./agent-mail-viz";
