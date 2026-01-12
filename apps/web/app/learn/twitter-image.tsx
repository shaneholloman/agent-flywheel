import { ImageResponse } from "next/og";

export const runtime = "edge";

export const alt =
  "ACFS Learning Hub - Master Agentic Coding with Interactive Lessons";
export const size = {
  width: 1200,
  height: 600,
};
export const contentType = "image/png";

// Lesson topics
const topics = [
  { name: "Linux", color: "#22d3ee" },
  { name: "SSH", color: "#a855f7" },
  { name: "Tmux", color: "#f472b6" },
  { name: "Git", color: "#22c55e" },
  { name: "Agents", color: "#f59e0b" },
  { name: "NTM", color: "#3b82f6" },
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
            "linear-gradient(145deg, #0a0a12 0%, #0f1419 40%, #0d1117 70%, #0a0a12 100%)",
          fontFamily: "system-ui, -apple-system, sans-serif",
          position: "relative",
          overflow: "hidden",
          padding: "45px 65px",
        }}
      >
        {/* Background orbs */}
        <div
          style={{
            position: "absolute",
            top: -80,
            left: -40,
            width: 350,
            height: 350,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(34,211,238,0.15) 0%, transparent 60%)",
            display: "flex",
          }}
        />
        <div
          style={{
            position: "absolute",
            bottom: -120,
            right: -60,
            width: 400,
            height: 400,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(168,85,247,0.12) 0%, transparent 60%)",
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
            maxWidth: "55%",
          }}
        >
          {/* Badge */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              marginBottom: 16,
              padding: "6px 14px",
              borderRadius: 16,
              background: "rgba(34,211,238,0.1)",
              border: "1px solid rgba(34,211,238,0.25)",
            }}
          >
            {/* Book icon */}
            <svg
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#22d3ee"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
              <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
            </svg>
            <span
              style={{
                fontSize: 12,
                color: "#22d3ee",
                fontWeight: 600,
                letterSpacing: "0.08em",
                textTransform: "uppercase",
                display: "flex",
              }}
            >
              Interactive Learning
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
            ACFS Learning Hub
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
            Master Agentic Coding
          </p>

          {/* Description */}
          <p
            style={{
              fontSize: 17,
              color: "#94a3b8",
              margin: 0,
              marginBottom: 22,
              lineHeight: 1.5,
              display: "flex",
            }}
          >
            From Linux basics to autonomous multi-agent workflows. Hands-on
            lessons with progress tracking.
          </p>

          {/* Stats */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 16,
              fontSize: 14,
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
              <span style={{ color: "#22d3ee", fontWeight: 700, display: "flex" }}>
                11+
              </span>
              Lessons
            </span>
            <span style={{ color: "#374151", display: "flex" }}>•</span>
            <span style={{ display: "flex" }}>Exercises</span>
            <span style={{ color: "#374151", display: "flex" }}>•</span>
            <span
              style={{
                display: "flex",
                alignItems: "center",
                gap: 5,
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
              Free
            </span>
          </div>
        </div>

        {/* Right - Topic pills */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "flex-end",
            gap: 14,
            zIndex: 10,
          }}
        >
          {/* First row */}
          <div
            style={{
              display: "flex",
              gap: 12,
            }}
          >
            {topics.slice(0, 3).map((topic, i) => (
              <div
                key={i}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 8,
                  padding: "12px 20px",
                  borderRadius: 12,
                  background: `linear-gradient(135deg, ${topic.color}15 0%, ${topic.color}06 100%)`,
                  border: `1px solid ${topic.color}40`,
                }}
              >
                <div
                  style={{
                    width: 10,
                    height: 10,
                    borderRadius: "50%",
                    background: topic.color,
                    display: "flex",
                  }}
                />
                <span
                  style={{
                    fontSize: 15,
                    fontWeight: 600,
                    color: topic.color,
                    display: "flex",
                  }}
                >
                  {topic.name}
                </span>
              </div>
            ))}
          </div>

          {/* Second row */}
          <div
            style={{
              display: "flex",
              gap: 12,
            }}
          >
            {topics.slice(3, 6).map((topic, i) => (
              <div
                key={i}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 8,
                  padding: "12px 20px",
                  borderRadius: 12,
                  background: `linear-gradient(135deg, ${topic.color}15 0%, ${topic.color}06 100%)`,
                  border: `1px solid ${topic.color}40`,
                }}
              >
                <div
                  style={{
                    width: 10,
                    height: 10,
                    borderRadius: "50%",
                    background: topic.color,
                    display: "flex",
                  }}
                />
                <span
                  style={{
                    fontSize: 15,
                    fontWeight: 600,
                    color: topic.color,
                    display: "flex",
                  }}
                >
                  {topic.name}
                </span>
              </div>
            ))}
          </div>

          {/* Progress visual */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 6,
              marginTop: 10,
            }}
          >
            {[...Array(6)].map((_, i) => (
              <div
                key={i}
                style={{
                  width: 32,
                  height: 6,
                  borderRadius: 3,
                  background:
                    i < 4
                      ? `linear-gradient(90deg, #22d3ee, #a855f7)`
                      : "rgba(100,116,139,0.3)",
                  display: "flex",
                }}
              />
            ))}
          </div>
          <span
            style={{
              fontSize: 12,
              color: "#64748b",
              display: "flex",
            }}
          >
            Track your progress
          </span>
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
              "linear-gradient(90deg, transparent 0%, #22d3ee 25%, #a855f7 50%, #f472b6 75%, transparent 100%)",
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
          <span style={{ display: "flex" }}>agent-flywheel.com/learn</span>
        </div>
      </div>
    ),
    {
      ...size,
    }
  );
}
