import type { Metadata } from "next";

const siteUrl = "https://agent-flywheel.com";

export const metadata: Metadata = {
  title: "The Flywheel",
  description:
    "Ten interconnected tools plus utilities that enable multiple AI agents to work in parallel, review each other's work, and make incredible autonomous progress while you're away.",
  openGraph: {
    title: "The Flywheel - 10 Tools for 10x Velocity",
    description:
      "Ten interconnected tools that enable multiple AI agents to work in parallel, coordinate automatically, and make autonomous progress. Using three tools is 10x better than one.",
    type: "website",
    url: `${siteUrl}/flywheel`,
    siteName: "Agent Flywheel",
    // Images auto-generated from opengraph-image.tsx
  },
  twitter: {
    card: "summary_large_image",
    title: "The Flywheel - 10 Tools for 10x Velocity",
    description:
      "Ten interconnected tools that enable multiple AI agents to work in parallel and make autonomous progress.",
    creator: "@jeffreyemanuel",
    // Images auto-generated from twitter-image.tsx
  },
};

export default function FlywheelLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
