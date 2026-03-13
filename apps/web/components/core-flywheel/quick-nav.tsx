"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

const NAV_ITEMS = [
  { id: "why", label: "Why", number: "01" },
  { id: "terms", label: "Five Terms", number: "02" },
  { id: "core-loop", label: "Core Loop", number: "03" },
  { id: "three-tools", label: "Three Tools", number: "04" },
  { id: "artifact-ladder", label: "Artifacts", number: "05" },
  { id: "example", label: "Example", number: "06" },
  { id: "operating-rhythm", label: "Rhythm", number: "07" },
  { id: "operator", label: "Human's Job", number: "08" },
  { id: "failure-modes", label: "Failures", number: "09" },
  { id: "helpers", label: "Helpers", number: "10" },
  { id: "getting-started", label: "Start", number: "11" },
] as const;

export function QuickNav() {
  const [activeId, setActiveId] = useState("");
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setVisible(window.scrollY > 600);
    };

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            setActiveId(entry.target.id);
          }
        }
      },
      { rootMargin: "-20% 0px -75% 0px" },
    );

    for (const item of NAV_ITEMS) {
      const el = document.getElementById(item.id);
      if (el) observer.observe(el);
    }

    window.addEventListener("scroll", handleScroll, { passive: true });
    handleScroll();

    return () => {
      observer.disconnect();
      window.removeEventListener("scroll", handleScroll);
    };
  }, []);

  const handleClick = (id: string) => {
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: "smooth" });
      window.history.pushState(null, "", `#${id}`);
    }
  };

  return (
    <AnimatePresence>
      {visible && (
        <motion.nav
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: 20 }}
          transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="fixed right-6 top-1/2 -translate-y-1/2 z-50 hidden xl:flex flex-col gap-1"
          aria-label="Quick navigation"
        >
          <div className="rounded-2xl border border-white/[0.04] bg-[#020408]/80 backdrop-blur-xl p-2.5 shadow-2xl">
            {NAV_ITEMS.map((item) => {
              const isActive = activeId === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => handleClick(item.id)}
                  title={`${item.number}. ${item.label}`}
                  className="group relative flex items-center gap-2 px-2.5 py-1.5 rounded-lg transition-all duration-300 w-full text-left"
                >
                  {/* Active indicator */}
                  {isActive && (
                    <motion.div
                      layoutId="quicknav-active"
                      className="absolute inset-0 rounded-lg bg-[#FF5500]/10 border border-[#FF5500]/20"
                      transition={{ type: "spring", stiffness: 380, damping: 30 }}
                    />
                  )}

                  {/* Dot */}
                  <div
                    className="relative z-10 w-1.5 h-1.5 rounded-full transition-all duration-300 shrink-0"
                    style={{
                      backgroundColor: isActive
                        ? "#FF5500"
                        : "rgba(255,255,255,0.15)",
                      boxShadow: isActive
                        ? "0 0 8px rgba(255,85,0,0.6)"
                        : "none",
                    }}
                  />

                  {/* Label */}
                  <span
                    className="relative z-10 text-[0.6rem] font-bold tracking-wide transition-colors duration-300 whitespace-nowrap"
                    style={{
                      color: isActive
                        ? "#FF5500"
                        : "rgba(255,255,255,0.25)",
                    }}
                  >
                    {item.label}
                  </span>
                </button>
              );
            })}
          </div>
        </motion.nav>
      )}
    </AnimatePresence>
  );
}
