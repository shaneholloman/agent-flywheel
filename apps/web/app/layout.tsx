import type { Metadata, Viewport } from "next";
import { Suspense } from "react";
import { JetBrains_Mono, Instrument_Sans } from "next/font/google";
import { QueryProvider } from "@/components/query-provider";
import { AnalyticsProvider } from "@/components/analytics-provider";
import { ThirdPartyScripts } from "@/components/third-party-scripts";
import { MotionProvider } from "@/components/motion/motion-provider";
import "./globals.css";

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-jetbrains",
  subsets: ["latin"],
  display: "swap",
});

const instrumentSans = Instrument_Sans({
  variable: "--font-instrument",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Agent Flywheel - Agentic Coding Setup",
  description:
    "Transform a fresh cloud server into a fully-configured agentic coding environment. Claude Code, OpenAI Codex, Google Gemini: all pre-configured with 30+ modern developer tools. All totally free and open-source.",
  keywords: [
    "VPS setup",
    "AI coding",
    "Claude",
    "Codex",
    "Gemini",
    "developer tools",
    "agentic coding",
    "Agent Flywheel",
  ],
  authors: [{ name: "Jeffrey Emanuel", url: "https://jeffreyemanuel.com/" }],
  openGraph: {
    title: "Agent Flywheel - Agentic Coding Setup",
    description:
      "From zero to fully-configured agentic coding VPS in 30 minutes.",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Agent Flywheel - Agentic Coding Setup",
    description:
      "From zero to fully-configured agentic coding VPS in 30 minutes.",
  },
};

export const viewport: Viewport = {
  themeColor: "#0a0a12",
  colorScheme: "dark",
  viewportFit: "cover", // Enable safe area insets for notch/home bar
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${jetbrainsMono.variable} ${instrumentSans.variable} font-sans antialiased`}
      >
        {/* Noise texture overlay */}
        <div className="pointer-events-none fixed inset-0 z-50 bg-noise" />
        <Suspense fallback={null}>
          <ThirdPartyScripts />
          <QueryProvider>
            <MotionProvider>
              <AnalyticsProvider>{children}</AnalyticsProvider>
            </MotionProvider>
          </QueryProvider>
        </Suspense>
      </body>
    </html>
  );
}
