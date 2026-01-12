import { ImageResponse } from "next/og";

export const runtime = "edge";

export const alt =
  "The Flywheel - 10 Interconnected Tools for 10x Velocity with AI Coding Agents";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

// Tool definitions with their colors
const tools = [
  { name: "NTM", color: "#22d3ee", desc: "Orchestration" },
  { name: "Agent Mail", color: "#a855f7", desc: "Coordination" },
  { name: "UBS", color: "#f472b6", desc: "Bug Scanner" },
  { name: "Beads", color: "#22c55e", desc: "Task Tracking" },
  { name: "CASS", color: "#f59e0b", desc: "Session Search" },
  { name: "CM", color: "#3b82f6", desc: "Memory" },
  { name: "CAAM", color: "#ec4899", desc: "Auth Manager" },
  { name: "SLB", color: "#14b8a6", desc: "Safety" },
  { name: "DCG", color: "#ef4444", desc: "Guard" },
  { name: "RU", color: "#8b5cf6", desc: "Repo Sync" },
];

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
            "linear-gradient(145deg, #0a0a12 0%, #0f1419 35%, #0d1117 65%, #0a0a12 100%)",
          fontFamily: "system-ui, -apple-system, sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Radial grid pattern */}
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            opacity: 0.04,
            backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' stroke='%2322d3ee' stroke-width='0.5'%3E%3Ccircle cx='30' cy='30' r='20'/%3E%3C/g%3E%3C/svg%3E")`,
            display: "flex",
          }}
        />

        {/* Large glow behind flywheel */}
        <div
          style={{
            position: "absolute",
            top: "50%",
            left: "50%",
            transform: "translate(-50%, -50%)",
            width: 600,
            height: 600,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(34,211,238,0.15) 0%, rgba(168,85,247,0.1) 40%, rgba(244,114,182,0.08) 70%, transparent 100%)",
            filter: "blur(60px)",
            display: "flex",
          }}
        />

        {/* Main content */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 10,
            padding: "40px",
          }}
        >
          {/* Header section */}
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              marginBottom: 30,
            }}
          >
            {/* Badge */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
                marginBottom: 16,
                padding: "6px 16px",
                borderRadius: 20,
                background: "rgba(34,211,238,0.1)",
                border: "1px solid rgba(34,211,238,0.25)",
              }}
            >
              <span
                style={{
                  fontSize: 13,
                  color: "#22d3ee",
                  fontWeight: 600,
                  letterSpacing: "0.08em",
                  textTransform: "uppercase",
                  display: "flex",
                }}
              >
                The Dicklesworthstone Stack
              </span>
            </div>

            {/* Title */}
            <h1
              style={{
                fontSize: 52,
                fontWeight: 800,
                background:
                  "linear-gradient(135deg, #ffffff 0%, #e2e8f0 50%, #94a3b8 100%)",
                backgroundClip: "text",
                color: "transparent",
                margin: 0,
                marginBottom: 8,
                letterSpacing: "-0.03em",
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
                display: "flex",
              }}
            >
              10 Tools for 10x Velocity
            </p>
          </div>

          {/* Tools grid - circular arrangement */}
          <div
            style={{
              display: "flex",
              flexDirection: "row",
              flexWrap: "wrap",
              justifyContent: "center",
              gap: 12,
              maxWidth: 900,
            }}
          >
            {tools.map((tool, i) => (
              <div
                key={i}
                style={{
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  padding: "10px 16px",
                  borderRadius: 12,
                  background: `linear-gradient(135deg, ${tool.color}15 0%, ${tool.color}08 100%)`,
                  border: `1px solid ${tool.color}40`,
                  minWidth: 95,
                }}
              >
                <span
                  style={{
                    fontSize: 15,
                    fontWeight: 700,
                    color: tool.color,
                    display: "flex",
                    marginBottom: 2,
                  }}
                >
                  {tool.name}
                </span>
                <span
                  style={{
                    fontSize: 10,
                    color: "#64748b",
                    display: "flex",
                    textTransform: "uppercase",
                    letterSpacing: "0.05em",
                  }}
                >
                  {tool.desc}
                </span>
              </div>
            ))}
          </div>

          {/* Footer tagline */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 20,
              marginTop: 30,
              fontSize: 16,
              color: "#64748b",
            }}
          >
            <span
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
              }}
            >
              <span
                style={{
                  width: 8,
                  height: 8,
                  borderRadius: "50%",
                  background: "#22c55e",
                  display: "flex",
                }}
              />
              Multiple agents in parallel
            </span>
            <span style={{ color: "#374151", display: "flex" }}>•</span>
            <span style={{ display: "flex" }}>Cross-agent coordination</span>
            <span style={{ color: "#374151", display: "flex" }}>•</span>
            <span style={{ display: "flex" }}>Autonomous progress</span>
          </div>
        </div>

        {/* Bottom gradient accent */}
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
            top: 28,
            right: 35,
            display: "flex",
            fontSize: 13,
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
