import type { Metadata } from "next";

const siteUrl = "https://agent-flywheel.com";

export const metadata: Metadata = {
  title: "Learning Hub",
  description:
    "Master agentic coding with interactive lessons covering Linux basics, tmux, git, AI agents, and the complete Dicklesworthstone stack. From zero to autonomous coding workflows.",
  openGraph: {
    title: "ACFS Learning Hub - Master Agentic Coding",
    description:
      "Interactive lessons covering Linux, tmux, git, AI agents, and the Dicklesworthstone stack. From zero to autonomous coding workflows.",
    type: "website",
    url: `${siteUrl}/learn`,
    siteName: "Agent Flywheel",
    // Images auto-generated from opengraph-image.tsx
  },
  twitter: {
    card: "summary_large_image",
    title: "ACFS Learning Hub - Master Agentic Coding",
    description:
      "Interactive lessons from Linux basics to autonomous multi-agent coding workflows.",
    creator: "@jeffreyemanuel",
    // Images auto-generated from twitter-image.tsx
  },
};

export default function LearnLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
