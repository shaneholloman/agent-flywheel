import { ImageResponse } from "next/og";

export const runtime = "edge";

export const alt =
  "Agent Flywheel - Transform a fresh VPS into a fully-configured agentic coding environment in 30 minutes";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          height: "100%",
          width: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          background:
            "linear-gradient(145deg, #0a0a12 0%, #0f1419 40%, #0d1117 70%, #0a0a12 100%)",
          fontFamily: "system-ui, -apple-system, sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Grid pattern overlay */}
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            opacity: 0.03,
            backgroundImage: `url("data:image/svg+xml,%3Csvg width='40' height='40' viewBox='0 0 40 40' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' stroke='%2322d3ee' stroke-width='0.5'%3E%3Cpath d='M0 20h40M20 0v40'/%3E%3C/g%3E%3C/svg%3E")`,
            display: "flex",
          }}
        />

        {/* Glowing orbs for depth - cyan */}
        <div
          style={{
            position: "absolute",
            top: -150,
            left: -100,
            width: 500,
            height: 500,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(34,211,238,0.15) 0%, transparent 60%)",
            display: "flex",
          }}
        />

        {/* Glowing orbs for depth - pink */}
        <div
          style={{
            position: "absolute",
            bottom: -200,
            right: -100,
            width: 600,
            height: 600,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(244,114,182,0.1) 0%, transparent 60%)",
            display: "flex",
          }}
        />

        {/* Purple accent orb */}
        <div
          style={{
            position: "absolute",
            top: 100,
            right: 200,
            width: 300,
            height: 300,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(168,85,247,0.08) 0%, transparent 60%)",
            display: "flex",
          }}
        />

        {/* Main content container */}
        <div
          style={{
            display: "flex",
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "center",
            gap: 60,
            zIndex: 10,
            padding: "40px 60px",
            width: "100%",
          }}
        >
          {/* Left side - Flywheel Icon */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              position: "relative",
            }}
          >
            {/* Outer glow ring */}
            <div
              style={{
                position: "absolute",
                width: 280,
                height: 280,
                borderRadius: "50%",
                background:
                  "radial-gradient(circle, rgba(34,211,238,0.25) 0%, rgba(168,85,247,0.15) 50%, transparent 70%)",
                filter: "blur(30px)",
                display: "flex",
              }}
            />

            {/* Flywheel SVG */}
            <svg
              width="220"
              height="220"
              viewBox="0 0 100 100"
              fill="none"
              style={{
                filter: "drop-shadow(0 0 30px rgba(34,211,238,0.4))",
              }}
            >
              <defs>
                <linearGradient id="ringGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stopColor="#22d3ee" />
                  <stop offset="50%" stopColor="#a855f7" />
                  <stop offset="100%" stopColor="#f472b6" />
                </linearGradient>
                <linearGradient id="centerGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stopColor="#22d3ee" />
                  <stop offset="100%" stopColor="#06b6d4" />
                </linearGradient>
              </defs>

              {/* Outer ring */}
              <circle
                cx="50"
                cy="50"
                r="45"
                stroke="url(#ringGrad)"
                strokeWidth="2"
                fill="none"
                opacity="0.8"
              />

              {/* Inner ring */}
              <circle
                cx="50"
                cy="50"
                r="35"
                stroke="#22d3ee"
                strokeWidth="1"
                fill="none"
                opacity="0.4"
              />

              {/* Center hub */}
              <circle cx="50" cy="50" r="12" fill="url(#centerGrad)" opacity="0.9" />
              <circle
                cx="50"
                cy="50"
                r="8"
                fill="rgba(255,255,255,0.2)"
              />

              {/* Flywheel nodes - 10 tools around the circle */}
              {[0, 36, 72, 108, 144, 180, 216, 252, 288, 324].map((angle, i) => {
                const rad = (angle * Math.PI) / 180;
                const x = 50 + 40 * Math.cos(rad);
                const y = 50 + 40 * Math.sin(rad);
                const colors = [
                  "#22d3ee",
                  "#a855f7",
                  "#f472b6",
                  "#22c55e",
                  "#f59e0b",
                  "#22d3ee",
                  "#a855f7",
                  "#f472b6",
                  "#22c55e",
                  "#f59e0b",
                ];
                return (
                  <g key={i}>
                    {/* Connection line from center */}
                    <line
                      x1="50"
                      y1="50"
                      x2={x}
                      y2={y}
                      stroke={colors[i]}
                      strokeWidth="1.5"
                      opacity="0.5"
                    />
                    {/* Node circle */}
                    <circle cx={x} cy={y} r="5" fill={colors[i]} opacity="0.9" />
                    <circle
                      cx={x}
                      cy={y}
                      r="3"
                      fill="rgba(255,255,255,0.3)"
                    />
                  </g>
                );
              })}

              {/* Rotating arrows suggesting motion */}
              <path
                d="M50 8 L54 14 L46 14 Z"
                fill="#22d3ee"
                opacity="0.7"
              />
              <path
                d="M92 50 L86 54 L86 46 Z"
                fill="#a855f7"
                opacity="0.7"
              />
              <path
                d="M50 92 L46 86 L54 86 Z"
                fill="#f472b6"
                opacity="0.7"
              />
              <path
                d="M8 50 L14 46 L14 54 Z"
                fill="#22c55e"
                opacity="0.7"
              />
            </svg>
          </div>

          {/* Right side - Text content */}
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "flex-start",
              justifyContent: "center",
              maxWidth: 650,
            }}
          >
            {/* Badge */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
                marginBottom: 20,
                padding: "8px 16px",
                borderRadius: 20,
                background: "rgba(34,211,238,0.1)",
                border: "1px solid rgba(34,211,238,0.3)",
              }}
            >
              <div
                style={{
                  width: 8,
                  height: 8,
                  borderRadius: "50%",
                  background: "#22c55e",
                  display: "flex",
                }}
              />
              <span
                style={{
                  fontSize: 14,
                  color: "#22d3ee",
                  fontWeight: 600,
                  letterSpacing: "0.05em",
                  textTransform: "uppercase",
                  display: "flex",
                }}
              >
                Free & Open Source
              </span>
            </div>

            {/* Title */}
            <h1
              style={{
                fontSize: 64,
                fontWeight: 800,
                background:
                  "linear-gradient(135deg, #ffffff 0%, #e2e8f0 50%, #94a3b8 100%)",
                backgroundClip: "text",
                color: "transparent",
                margin: 0,
                marginBottom: 8,
                letterSpacing: "-0.03em",
                lineHeight: 1.1,
                display: "flex",
              }}
            >
              Agent Flywheel
            </h1>

            {/* Subtitle with gradient */}
            <p
              style={{
                fontSize: 26,
                fontWeight: 600,
                background:
                  "linear-gradient(90deg, #22d3ee 0%, #a855f7 50%, #f472b6 100%)",
                backgroundClip: "text",
                color: "transparent",
                margin: 0,
                marginBottom: 24,
                display: "flex",
              }}
            >
              AI Agents Coding For You
            </p>

            {/* Description */}
            <p
              style={{
                fontSize: 20,
                color: "#94a3b8",
                margin: 0,
                marginBottom: 28,
                lineHeight: 1.5,
                display: "flex",
              }}
            >
              Transform a fresh VPS into a fully-configured agentic coding
              environment in ~30 minutes
            </p>

            {/* Stats row */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 24,
                fontSize: 16,
              }}
            >
              {/* Claude */}
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 8,
                  padding: "6px 14px",
                  borderRadius: 8,
                  background: "rgba(249,115,22,0.15)",
                  border: "1px solid rgba(249,115,22,0.3)",
                }}
              >
                <span style={{ color: "#fb923c", fontWeight: 600, display: "flex" }}>
                  Claude
                </span>
              </div>

              {/* Codex */}
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 8,
                  padding: "6px 14px",
                  borderRadius: 8,
                  background: "rgba(34,197,94,0.15)",
                  border: "1px solid rgba(34,197,94,0.3)",
                }}
              >
                <span style={{ color: "#4ade80", fontWeight: 600, display: "flex" }}>
                  Codex
                </span>
              </div>

              {/* Gemini */}
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 8,
                  padding: "6px 14px",
                  borderRadius: 8,
                  background: "rgba(59,130,246,0.15)",
                  border: "1px solid rgba(59,130,246,0.3)",
                }}
              >
                <span style={{ color: "#60a5fa", fontWeight: 600, display: "flex" }}>
                  Gemini
                </span>
              </div>

              {/* Tools count */}
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                  color: "#64748b",
                }}
              >
                <span style={{ color: "#22d3ee", fontWeight: 700, display: "flex" }}>
                  30+
                </span>
                <span style={{ display: "flex" }}>Dev Tools</span>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom gradient accent line */}
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: 0,
            right: 0,
            height: 4,
            background:
              "linear-gradient(90deg, transparent 0%, #22d3ee 25%, #a855f7 50%, #f472b6 75%, transparent 100%)",
            display: "flex",
          }}
        />

        {/* Corner accent - top right */}
        <div
          style={{
            position: "absolute",
            top: 30,
            right: 40,
            display: "flex",
            alignItems: "center",
            gap: 8,
            fontSize: 14,
            color: "#475569",
          }}
        >
          <span style={{ display: "flex" }}>agent-flywheel.com</span>
        </div>
      </div>
    ),
    {
      ...size,
    }
  );
}
