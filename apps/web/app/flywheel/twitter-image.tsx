import { ImageResponse } from "next/og";

export const runtime = "edge";

export const alt =
  "The Flywheel - 10 Interconnected Tools for 10x Velocity with AI Coding Agents";
export const size = {
  width: 1200,
  height: 600,
};
export const contentType = "image/png";

// Tool definitions with their colors
const tools = [
  { name: "NTM", color: "#22d3ee" },
  { name: "Agent Mail", color: "#a855f7" },
  { name: "UBS", color: "#f472b6" },
  { name: "Beads", color: "#22c55e" },
  { name: "CASS", color: "#f59e0b" },
  { name: "CM", color: "#3b82f6" },
  { name: "CAAM", color: "#ec4899" },
  { name: "SLB", color: "#14b8a6" },
  { name: "DCG", color: "#ef4444" },
  { name: "RU", color: "#8b5cf6" },
];

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          height: "100%",
          width: "100%",
          display: "flex",
          flexDirection: "row",
          alignItems: "center",
          justifyContent: "space-between",
          background:
            "linear-gradient(145deg, #0a0a12 0%, #0f1419 35%, #0d1117 65%, #0a0a12 100%)",
          fontFamily: "system-ui, -apple-system, sans-serif",
          position: "relative",
          overflow: "hidden",
          padding: "45px 60px",
        }}
      >
        {/* Background glow */}
        <div
          style={{
            position: "absolute",
            top: "50%",
            right: "15%",
            transform: "translateY(-50%)",
            width: 450,
            height: 450,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(34,211,238,0.18) 0%, rgba(168,85,247,0.12) 40%, rgba(244,114,182,0.08) 70%, transparent 100%)",
            filter: "blur(50px)",
            display: "flex",
          }}
        />

        {/* Left content */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            zIndex: 10,
            maxWidth: "50%",
          }}
        >
          {/* Badge */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              marginBottom: 16,
              padding: "5px 14px",
              borderRadius: 16,
              background: "rgba(34,211,238,0.1)",
              border: "1px solid rgba(34,211,238,0.25)",
            }}
          >
            <span
              style={{
                fontSize: 11,
                color: "#22d3ee",
                fontWeight: 600,
                letterSpacing: "0.08em",
                textTransform: "uppercase",
                display: "flex",
              }}
            >
              Dicklesworthstone Stack
            </span>
          </div>

          {/* Title */}
          <h1
            style={{
              fontSize: 48,
              fontWeight: 800,
              background:
                "linear-gradient(135deg, #ffffff 0%, #e2e8f0 50%, #94a3b8 100%)",
              backgroundClip: "text",
              color: "transparent",
              margin: 0,
              marginBottom: 6,
              letterSpacing: "-0.03em",
              lineHeight: 1.1,
              display: "flex",
            }}
          >
            The Flywheel
          </h1>

          {/* Subtitle */}
          <p
            style={{
              fontSize: 22,
              fontWeight: 600,
              background:
                "linear-gradient(90deg, #22d3ee 0%, #a855f7 50%, #f472b6 100%)",
              backgroundClip: "text",
              color: "transparent",
              margin: 0,
              marginBottom: 18,
              display: "flex",
            }}
          >
            10 Tools for 10x Velocity
          </p>

          {/* Description */}
          <p
            style={{
              fontSize: 16,
              color: "#94a3b8",
              margin: 0,
              marginBottom: 22,
              lineHeight: 1.5,
              display: "flex",
            }}
          >
            Multiple AI agents working in parallel, coordinating automatically,
            making autonomous progress
          </p>

          {/* Key benefits */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 16,
              fontSize: 13,
              color: "#64748b",
            }}
          >
            <span
              style={{
                display: "flex",
                alignItems: "center",
                gap: 6,
              }}
            >
              <span
                style={{
                  width: 6,
                  height: 6,
                  borderRadius: "50%",
                  background: "#22c55e",
                  display: "flex",
                }}
              />
              Parallel execution
            </span>
            <span style={{ color: "#374151", display: "flex" }}>•</span>
            <span style={{ display: "flex" }}>Cross-agent coordination</span>
            <span style={{ color: "#374151", display: "flex" }}>•</span>
            <span style={{ display: "flex" }}>Safety guardrails</span>
          </div>
        </div>

        {/* Right - Tool grid */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            gap: 10,
            zIndex: 10,
          }}
        >
          {/* First row - 5 tools */}
          <div
            style={{
              display: "flex",
              gap: 10,
            }}
          >
            {tools.slice(0, 5).map((tool, i) => (
              <div
                key={i}
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  padding: "10px 16px",
                  borderRadius: 10,
                  background: `linear-gradient(135deg, ${tool.color}18 0%, ${tool.color}08 100%)`,
                  border: `1px solid ${tool.color}45`,
                  minWidth: 80,
                }}
              >
                <span
                  style={{
                    fontSize: 13,
                    fontWeight: 700,
                    color: tool.color,
                    display: "flex",
                  }}
                >
                  {tool.name}
                </span>
              </div>
            ))}
          </div>

          {/* Second row - 5 tools */}
          <div
            style={{
              display: "flex",
              gap: 10,
            }}
          >
            {tools.slice(5, 10).map((tool, i) => (
              <div
                key={i}
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  padding: "10px 16px",
                  borderRadius: 10,
                  background: `linear-gradient(135deg, ${tool.color}18 0%, ${tool.color}08 100%)`,
                  border: `1px solid ${tool.color}45`,
                  minWidth: 80,
                }}
              >
                <span
                  style={{
                    fontSize: 13,
                    fontWeight: 700,
                    color: tool.color,
                    display: "flex",
                  }}
                >
                  {tool.name}
                </span>
              </div>
            ))}
          </div>

          {/* Connecting lines visualization */}
          <div
            style={{
              display: "flex",
              justifyContent: "center",
              marginTop: 15,
            }}
          >
            <svg
              width="400"
              height="80"
              viewBox="0 0 400 80"
              fill="none"
              style={{ opacity: 0.6 }}
            >
              {/* Central hub */}
              <circle cx="200" cy="40" r="15" fill="#22d3ee" opacity="0.8" />
              <circle cx="200" cy="40" r="8" fill="rgba(255,255,255,0.3)" />

              {/* Connecting lines from tools */}
              {[40, 120, 200, 280, 360].map((x, i) => (
                <g key={i}>
                  <line
                    x1={x}
                    y1="5"
                    x2="200"
                    y2="40"
                    stroke={tools[i].color}
                    strokeWidth="1.5"
                    opacity="0.5"
                  />
                  <line
                    x1={x}
                    y1="75"
                    x2="200"
                    y2="40"
                    stroke={tools[i + 5].color}
                    strokeWidth="1.5"
                    opacity="0.5"
                  />
                </g>
              ))}
            </svg>
          </div>
        </div>

        {/* Bottom gradient */}
        <div
          style={{
            position: "absolute",
            bottom: 0,
            left: 0,
            right: 0,
            height: 4,
            background:
              "linear-gradient(90deg, transparent 0%, #22d3ee 20%, #a855f7 40%, #f472b6 60%, #22c55e 80%, transparent 100%)",
            display: "flex",
          }}
        />

        {/* URL */}
        <div
          style={{
            position: "absolute",
            top: 22,
            right: 30,
            display: "flex",
            fontSize: 12,
            color: "#4b5563",
          }}
        >
          <span style={{ display: "flex" }}>agent-flywheel.com/flywheel</span>
        </div>
      </div>
    ),
    {
      ...size,
    }
  );
}
