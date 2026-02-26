import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "The Agentic Coding Flywheel - TL;DR | Agent Flywheel",
  description:
    "A comprehensive overview of 13 open-source tools that work together to supercharge multi-agent AI coding workflows. NTM, SLB, Agent Mail, Beads Viewer, UBS, CASS Memory, CASS Search, and more.",
  alternates: {
    canonical: "/tldr",
  },
};

export default function TldrLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
