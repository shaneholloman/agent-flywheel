import type { Metadata } from "next";

export const metadata: Metadata = {
  title:
    "The Core Flywheel - Agent Mail, Beads & bv | Agent Flywheel",
  description:
    "The focused, beginner-friendly version of the Agentic Coding Flywheel. Learn the three-tool core loop: Agent Mail for coordination, br for task management, and bv for graph-aware triage.",
  alternates: {
    canonical: "/core_flywheel",
  },
};

export default function CoreFlywheelLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
