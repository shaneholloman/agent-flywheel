import type { Metadata } from "next";

const siteUrl = "https://agent-flywheel.com";

export const metadata: Metadata = {
  title: "The Flywheel",
  description:
    "Twenty interconnected tools that enable multiple AI agents to work in parallel, review each other's work, and make incredible autonomous progress while you're away.",
  alternates: {
    canonical: `${siteUrl}/flywheel`,
  },
};

export default function FlywheelLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
