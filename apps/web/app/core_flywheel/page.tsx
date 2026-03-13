import { ErrorBoundary } from "@/components/ui/error-boundary";
import { Sparkles, Rocket, ArrowRight, Shield, Bug, Search, ChevronDown } from "lucide-react";

import {
  GuideSection,
  SubSection,
  P,
  BlockQuote,
  PromptBlock,
  Hl,
  Divider,
  TipBox,
  BulletList,
  NumberedList,
  DataTable,
  CodeBlock,
} from "@/components/complete-guide/guide-components";
import { CoordinationTrioViz } from "@/components/complete-guide/coordination-trio-viz";
import { CoreLoopDiagram } from "@/components/core-flywheel/core-loop-diagram";
import { ArtifactLadderViz } from "@/components/core-flywheel/artifact-ladder-viz";
import { BeadComparisonViz } from "@/components/core-flywheel/bead-comparison-viz";
import { QuickNav } from "@/components/core-flywheel/quick-nav";


export default function CoreFlywheelPage() {
  return (
    <ErrorBoundary>
      <main className="min-h-screen bg-[#020408] selection:bg-[#FF5500]/20 selection:text-white overflow-x-hidden pb-32">
        <Hero />

        {/* Floating quick-nav for desktop */}
        <QuickNav />

        <div className="mx-auto max-w-[1000px] px-6 lg:px-12 relative mt-20">

          {/* ============================================================= */}
          {/* SECTION 1: WHY THE CORE LOOP                                   */}
          {/* ============================================================= */}
          <GuideSection id="why" number="1" title="Why a Simpler Starting Point">
            <P highlight>The full Flywheel system has grown large enough that many people find it overwhelming on first contact. That reaction makes sense. But there is a much smaller core that already captures most of what makes the approach powerful.</P>

            <P>The larger system includes planning workflows, memory systems, prompt libraries, launch tooling, safety tooling, skills, and a lot of accumulated operational detail. You do not need to absorb all of that up front.</P>

            <P>The core loop uses just <Hl>three tools</Hl>. If you understand those three and use them together correctly, you already have the heart of the system.</P>

            <DataTable
              headers={["Layer", "What It Is For"]}
              rows={[
                ["Frontier models", "Generating and refining the markdown plan"],
                ["br (beads_rust)", "Turning that plan into explicit task structure with dependencies"],
                ["bv (beads_viewer)", "Routing work through the dependency graph to find highest-leverage next bead"],
                ["Agent Mail", "Coordinating claims, reservations, progress, and handoff between agents"],
              ]}
            />

            <P>Separate the process into two layers: the <Hl>planning substrate</Hl> (frontier models used to create and refine the markdown plan) and the <Hl>core operating loop</Hl> (Agent Mail, br, and bv once the plan is ready to drive execution).</P>

            <TipBox variant="info">
              When this guide says &quot;three-tool core,&quot; it means the durable execution substrate you keep live while the project is being carried out. It does not mean the planning phase happens in a vacuum. The first step is still creating an excellent markdown plan.
            </TipBox>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 2: FIVE TERMS                                          */}
          {/* ============================================================= */}
          <GuideSection id="terms" number="2" title="Five Terms You Need">
            <P>If these five terms stay clear in your head, most of the rest of the guide gets much easier to follow.</P>

            <DataTable
              headers={["Term", "Meaning"]}
              rows={[
                ["Bead", "A self-contained task with enough context, dependency information, and completion criteria that an agent can work it without guessing."],
                ["Ready bead", "A bead whose blockers are cleared, so it can be started right now."],
                ["Claim", "The act of announcing, usually in Agent Mail, that a specific agent is taking responsibility for a bead."],
                ["Reservation", "A coordination lock or lease on files or resources so two agents do not unknowingly collide."],
                ["Thread", "The running Agent Mail conversation tied to one bead ID, where start, progress, review, and completion messages accumulate."],
              ]}
            />

            <SubSection title="The One Convention That Holds It Together">
              <P>Use the <Hl>bead ID everywhere</Hl>. If the task is <code>br-123</code>, then:</P>
              <BulletList items={[
                <>The Agent Mail thread should also be <code>br-123</code></>,
                <>The subject line should start with <code>[br-123]</code></>,
                <>The file reservation reason should mention <code>br-123</code></>,
                <>Commit messages should include <code>br-123</code> for traceability</>,
              ]} />
              <P>It sounds small, but it is one of the most practical conventions in the whole workflow. The task graph, the coordination thread, and the work claim all line up under the same identifier.</P>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 3: THE CORE IDEA                                       */}
          {/* ============================================================= */}
          <GuideSection id="core-loop" number="3" title="The Core Loop">
            <P highlight>The core loop is simple: generate a plan, encode it as beads, let bv route work, coordinate through Agent Mail, implement, close, and repeat until the graph is done.</P>

            <CoreLoopDiagram />

            <SubSection title="Normal Chat Coding vs. The Core Loop">
              <DataTable
                headers={["Normal Chat Coding", "The Core Loop"]}
                rows={[
                  ["The task mostly lives in chat", "The task gets formalized into a markdown plan and then beads"],
                  ["Coordination lives in scrollback or in the human's head", "Coordination is externalized through Agent Mail"],
                  ["Agents pick work based on local convenience", "bv routes work from the dependency graph"],
                  ["Progress is hard to inspect later", "The bead graph and message threads form a durable record"],
                  ["A crashed agent often takes its local state with it", "Another agent can resume from the bead and the thread"],
                ]}
              />
            </SubSection>

            <P>The core loop moves work out of ephemeral chat and into explicit, inspectable artifacts. That is the short answer to &quot;why bother?&quot;</P>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 4: THE THREE TOOLS                                     */}
          {/* ============================================================= */}
          <GuideSection id="three-tools" number="4" title="The Three Tools Are a Single Machine">
            <P>These three tools solve three different failure modes. Each helps on its own, but the value shows up most clearly when they form a stable loop together.</P>

            <SubSection title="Agent Mail Solves Coordination">
              <P>Without Agent Mail, multiple agents constantly collide: two agents edit the same files, nobody knows who is doing what, messages disappear into chat history, and work gets stranded when an agent crashes.</P>
              <P>Agent Mail gives you a shared coordination layer with <Hl>identities</Hl>, <Hl>threads</Hl>, <Hl>inboxes</Hl>, and <Hl>file reservations</Hl>. Agents announce what they are doing, reserve edit surfaces, and recover when another agent disappears.</P>
            </SubSection>

            <SubSection title="br Solves Task Structure">
              <P>Without br, work collapses into vague conversational intentions: &quot;fix the auth stuff,&quot; &quot;clean up the admin area,&quot; &quot;someone should improve tests.&quot; That kind of tasking is too fuzzy for a swarm.</P>
              <P><code>br</code> turns work into explicit beads with <Hl>status</Hl>, <Hl>priority</Hl>, and <Hl>dependencies</Hl>. Once work is represented that way, multiple agents can make progress without constant human steering.</P>
            </SubSection>

            <SubSection title="bv Solves Routing">
              <P>Even with good beads, agents still need to know what to do next. Without bv, they choose work based on local convenience or whatever they most recently saw in context.</P>
              <P><code>bv</code> reads the bead graph and computes what is most worth doing next. That turns the swarm from &quot;many agents doing work&quot; into &quot;many agents <Hl>pushing the project forward efficiently</Hl>.&quot;</P>
            </SubSection>

            <CoordinationTrioViz />

            <SubSection title="What Goes Wrong If You Skip One">
              <DataTable
                headers={["If You Skip...", "What Usually Happens"]}
                rows={[
                  ["Agent Mail", "Agents overlap, duplicate work, and lose shared situational awareness"],
                  ["br", "Work stays vague, hidden in chat, and hard to coordinate across agents"],
                  ["bv", "Agents pick tasks based on convenience instead of graph-aware leverage"],
                ]}
              />
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 5: THE ARTIFACT LADDER                                 */}
          {/* ============================================================= */}
          <GuideSection id="artifact-ladder" number="5" title="The Artifact Ladder">
            <P>One reason agentic coding feels confusing at first is that the <Hl>active artifact keeps changing</Hl>. The easiest way to stay oriented is to know what the current artifact means and what you do with it next.</P>

            <ArtifactLadderViz />

            <SubSection title="Plan Space, Bead Space, and Code Space">
              <P><strong>Plan space</strong> is where you decide the workflows, constraints, architecture, and testing expectations. <strong>Bead space</strong> is where you transform that thinking into executable memory for agents. <strong>Code space</strong> is where agents implement the local task that a bead defines.</P>
              <P>The general rule is simple. Debates belong in plan space. Translation and dependency shaping belong in bead space. Implementation belongs in code space.</P>
              <TipBox variant="warning">
                If the swarm starts discovering missing structure while coding, the answer is often to step back up into bead space or plan space instead of forcing more code through a weak task graph.
              </TipBox>
            </SubSection>

            <SubSection title="Escalation Ladder">
              <P>When something feels wrong, use the smallest escalation that actually fits the problem:</P>
              <BulletList items={[
                <><strong>Local code confusion</strong> — stay in code space and resolve it there</>,
                <><strong>Weak or underspecified bead</strong> — step back into bead space and rewrite the bead</>,
                <><strong>Wrong graph</strong> — fix the dependencies or add the missing bead</>,
                <><strong>Missing plan work</strong> — step back into plan space and revise the markdown plan</>,
                <><strong>Degraded agent</strong> — restart it with a fresh session</>,
              ]} />
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 6: CONCRETE EXAMPLE                                    */}
          {/* ============================================================= */}
          <GuideSection id="example" number="6" title="A Concrete Example: Atlas Notes">
            <P>A small project makes the workflow easier to picture. Imagine building an internal tool called <strong>Atlas Notes</strong>: team members upload Markdown notes, the system tags and indexes them, users can search them quickly, and admins can inspect failed ingestions.</P>

            <P>If you gave four agents only that vague description, they would step on each other and make mismatched assumptions. The core loop instead looks like this:</P>

            <NumberedList items={[
              "Ask multiple frontier models to produce competing markdown plans, then synthesize them into one strong plan describing uploads, parsing, tagging, search, admin review, and testing expectations.",
              <>Convert that plan into beads in <code>br</code>: upload pipeline (br-101), indexing and search (br-102), admin screen (br-103), auth (br-104), end-to-end tests (br-105).</>,
              "Add dependencies so the graph reflects reality — br-103 depends on br-101 and br-104.",
              "Agents use Agent Mail to announce claims and reserve files.",
              "Agents use bv to see which ready bead matters most right now.",
              "They work, update bead status, send progress in-thread, and repeat.",
            ]} />

            <SubSection title="Weak vs. Strong Artifacts">
              <P>Quality thresholds get easier to feel when you compare weak and strong versions directly. The weak version names a topic. The strong version scopes the actual requirement, constraint, and testing obligation.</P>
              <BeadComparisonViz />
            </SubSection>

            <SubSection title="Sample Agent Mail Thread">
              <P>A typical bead thread has a simple rhythm — three short updates are usually enough:</P>

              <CodeBlock language="text" code={`[br-103] Start: Failed-ingestion admin screen
Claiming br-103. Reserving admin UI files plus retry handler path.
Will send update once list view is working and retry path is wired.

[br-103] Progress: Main path wired
List view and detail view working. Now handling edge cases and tests.

[br-103] Completed
Admin screen done. List view, detail view, and retry action wired.
Auth checks in place. E2E coverage for malformed upload → admin review → retry.`} />
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 7: THE OPERATING RHYTHM                                */}
          {/* ============================================================= */}
          <GuideSection id="operating-rhythm" number="7" title="The Operating Rhythm">
            <SubSection title="Step 1: Create an Excellent Markdown Plan">
              <P>Before beads or swarms or file reservations, create a serious markdown plan. Do not settle for one quick draft from one model.</P>

              <PromptBlock
                title="Multi-Model Synthesis"
                prompt={`I asked 3 competing LLMs to do the exact same thing and they came up with pretty different plans which you can read below. I want you to REALLY carefully analyze their plans with an open mind and be intellectually honest about what they did that's better than your plan. Then I want you to come up with the best possible revisions to your plan that artfully and skillfully blends the "best of all worlds" to create a true, ultimate, superior hybrid version of the plan:

[Paste all plans here]`}
                where="GPT Pro web app with Extended Reasoning, or your strongest available model"
                whyItWorks="Different frontier models have different blind spots. Competitive synthesis forces the model to admit where others are better and merge the strongest ideas."
              />

              <P>At minimum, you want: the user-facing workflows, the important constraints, the major architectural decisions, and the testing expectations.</P>
            </SubSection>

            <SubSection title="Step 2: Turn the Plan into Beads">
              <P>Use <code>br</code> to create actual beads — real work units, not vague slogans.</P>

              <CodeBlock language="bash" code={`# Create the bead with a clear title and basic metadata
br create --title "Upload and parse pipeline" --type task --priority 1
br create --title "Failed-ingestion admin screen" --type task --priority 1
br create --title "End-to-end ingestion tests" --type task --priority 1

# Add the first obvious dependencies
br dep add 103 101
br dep add 105 101

# Check what's ready
br ready --json`} />

              <P>Good beads include: what needs to be done, relevant background, what it depends on, what counts as done, and what tests need to exist. The more explicit the bead graph is, the less improvisation the swarm has to do later.</P>

              <TipBox>
                <strong>Beads are executable memory.</strong> The markdown plan is the best artifact for whole-system thought. Beads are the plan after it has been transformed into a format optimized for distributed execution. Weak beads force improvisation. Rich beads make execution mechanical.
              </TipBox>
            </SubSection>

            <SubSection title="Step 3: Let bv Tell You What Matters Next">
              <P>Once the bead graph exists, stop relying on intuition for task ordering. Use <code>bv</code> to see what is ready, what clears the most downstream blockers, and what work has outsized impact.</P>

              <CodeBlock language="bash" code={`# THE MEGA-COMMAND: start here
bv --robot-triage

# Minimal: just the single top pick + claim command
bv --robot-next`} />

              <P>Do not stare at the JSON forever. Look for the <Hl>top recommendation</Hl>, <Hl>why it is top</Hl>, and <Hl>what it unblocks</Hl>.</P>

              <TipBox variant="warning">
                Sometimes the right response to bv is not &quot;follow the recommendation&quot; but &quot;the graph itself still needs work.&quot; If there are no good ready beads even though work obviously exists, go back and fix the dependencies or add missing beads.
              </TipBox>
            </SubSection>

            <SubSection title="Step 4: Coordinate Through Agent Mail">
              <P>When an agent starts a bead, it should communicate what it is working on and reserve the relevant files.</P>

              <CodeBlock language="text" code={`# Join the coordination layer
ensure_project(project_key="/path/to/repo")
register_agent(project_key="/path/to/repo", program="claude-code", model="opus")

# Claim and reserve
file_reservation_paths(..., reason="br-101")
send_message(..., thread_id="br-101", subject="[br-101] Start: Upload pipeline")`} />

              <P>That keeps the swarm legible. Other agents can see what is happening. If someone crashes, the thread is still there. If there is overlap, the reservation system makes it visible.</P>
            </SubSection>

            <SubSection title="Step 5: Finish, Review, Repeat">
              <P>As work completes: update bead status, send completion notes, and ask bv what the next best ready bead is.</P>

              <CodeBlock language="bash" code={`br update 101 --status in_progress
# ... implement, test, review ...
br close 101 --reason "Completed"
bv --robot-next`} />

              <PromptBlock
                title="Fresh-Eyes Review"
                prompt={`Great, now I want you to carefully read over all of the new code you just wrote and other existing code you just modified with "fresh eyes" looking super carefully for any obvious bugs, errors, problems, issues, confusion, etc. Carefully fix anything you uncover. Use ultrathink.`}
                where="After each bead is implemented — run until no more bugs found"
                whyItWorks="Forces a mode switch from writing to adversarial reading while the code is still fresh. One of the cheapest quality multipliers in the whole method."
              />
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 8: THE HUMAN'S JOB                                     */}
          {/* ============================================================= */}
          <GuideSection id="operator" number="8" title="The Human&apos;s Job">
            <P highlight>The human is not supposed to micromanage every code edit. The human is there to keep the structure clean enough that the agents can work effectively inside it.</P>

            <SubSection title="Main Responsibilities">
              <BulletList items={[
                <><strong>Keep the bead graph honest</strong> — notice when a missing task or missing dependency must be added</>,
                <><strong>Restart or redirect agents</strong> when they drift, get loopy, or lose context</>,
                <><strong>Keep the system moving</strong> instead of letting it stall in over-coordination</>,
                <><strong>Ask the hard question:</strong> if all open beads land cleanly, does that actually close the remaining gap?</>,
              ]} />
            </SubSection>

            <SubSection title="The 15-Minute Operator Sweep">
              <P>During active execution, check the swarm on roughly a 10-15 minute cadence:</P>
              <NumberedList items={[
                <>Run <code>bv --robot-next</code> or <code>bv --robot-triage</code> and check whether the top recommendation still makes sense.</>,
                "Glance through Agent Mail threads for fresh claims, blockers, or silence.",
                "Look for stale reservations or beads stuck in in_progress without movement.",
                "Restart or redirect one drifting agent if something looks loopy or confused.",
                "Ask whether the open and in-progress beads still close the remaining goal gap.",
              ]} />
              <P>That is usually enough to keep the loop healthy without turning the human into a full-time traffic cop.</P>
            </SubSection>

            <SubSection title="Minimum Viable AGENTS.md">
              <P>Even in the smaller core-loop version, you still need a minimal <code>AGENTS.md</code>. It does not have to be a giant doctrine document, but it should say:</P>
              <BulletList items={[
                "What the repo is for",
                "What the stack is",
                "Any non-negotiable safety or style rules",
                "How this project uses Agent Mail, br, and bv",
              ]} />
              <BlockQuote>Treat AGENTS.md as the swarm&apos;s durable operating manual. It tells a fresh or partially confused agent how to behave, what tools exist, and what &quot;doing a good job&quot; looks like in this repo.</BlockQuote>

              <TipBox variant="warning">
                <strong>After compaction, agents must re-read AGENTS.md.</strong> If an agent still seems confused or loopy after rereading it, stop trying to rescue the degraded state and start a fresh session instead.
              </TipBox>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 9: COMMON FAILURE MODES                                */}
          {/* ============================================================= */}
          <GuideSection id="failure-modes" number="9" title="Common Failure Modes">
            <DataTable
              headers={["Symptom", "Likely Cause", "Fix"]}
              rows={[
                ["Agents keep overlapping", "Weak or missing Agent Mail claims and reservations", "Force thread use, reserve surfaces, restate ownership"],
                ["Agents choose random work", "The team is not using bv consistently", "Run bv --robot-triage and route from the graph"],
                ["A task keeps stalling", "The bead is underspecified or missing a dependency", "Rewrite the bead or add the missing dependency"],
                ["The swarm feels busy but confused", "The markdown plan was too weak", "Go back up a level and improve the plan"],
              ]}
            />

            <SubSection title="Agent Disappeared Mid-Bead">
              <P>When an agent vanishes mid-bead, the recovery path should be boring:</P>
              <NumberedList items={[
                "Check the Agent Mail thread for the last meaningful progress update.",
                "Check whether the file reservation is still active and looks abandoned.",
                "Reread AGENTS.md so the local operating contract is fresh.",
                "If the original session is salvageable, resume it. If loopy or degraded, restart.",
                "Reclaim the bead explicitly in Agent Mail so ownership is visible.",
                "Continue from the bead body plus the thread history instead of guessing.",
              ]} />
              <TipBox variant="info">
                If that recovery feels hard, the bead or the thread was probably too thin. That is a signal to write richer beads in the future.
              </TipBox>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 10: HELPER UTILITIES                                    */}
          {/* ============================================================= */}
          <GuideSection id="helpers" number="10" title="Helper Utilities: DCG, UBS & CASS">
            <P>Once the core loop is running smoothly, three helper utilities significantly improve safety, quality, and learning. They are <Hl>multipliers on top of the core loop</Hl>, not prerequisites.</P>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 sm:gap-6 my-12">
              <HelperCard
                icon={<Shield className="h-6 w-6" />}
                name="DCG"
                fullName="Destructive Command Guard"
                color="#FF5F56"
                description="A Claude Code hook that blocks dangerous git and filesystem commands before execution. Sub-millisecond latency, mechanical enforcement."
                usage="Works automatically. When a dangerous command is blocked, use safer alternatives or ask the user to run it manually."
                command="dcg test 'rm -rf /' --explain"
              />
              <HelperCard
                icon={<Bug className="h-6 w-6" />}
                name="UBS"
                fullName="Ultimate Bug Scanner"
                color="#FFBD2E"
                description="Multi-language bug scanner with guardrails. Run it on changed files before every commit to catch injection, unquoted variables, and other hazards."
                usage="ubs <changed-files> before every commit. Exit 0 = safe. Exit >0 = fix and re-run."
                command="ubs $(git diff --name-only --cached)"
              />
              <HelperCard
                icon={<Search className="h-6 w-6" />}
                name="CASS"
                fullName="Cross-Agent Session Search"
                color="#a78bfa"
                description="Indexes prior agent conversations so solved problems can be reused. Finds patterns, decisions, and solutions across session history."
                usage="Search before reinventing a solution. If an agent solved a similar problem before, CASS will find it."
                command="cass search 'auth middleware' --robot --limit 5"
              />
            </div>

            <P>These utilities share a common theme: they take knowledge that would otherwise be invisible or ephemeral — dangerous commands, latent bugs, past session decisions — and make it <Hl>durable and actionable</Hl>.</P>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 11: GETTING STARTED & GRADUATION                       */}
          {/* ============================================================= */}
          <GuideSection id="getting-started" number="11" title="Getting Started">
            <SubSection title="The First 30 Minutes">
              <NumberedList items={[
                "Pick one real project, not a toy.",
                "Ask multiple frontier models for competing markdown plans.",
                "Synthesize them into one strong plan.",
                "Create the first meaningful beads in br.",
                "Add the most obvious dependencies.",
                <>Run <code>bv --robot-triage</code> or <code>bv --robot-next</code>.</>,
                "Launch 2-4 agents however you prefer.",
                "Have each agent coordinate through Agent Mail and claim a real bead.",
              ]} />

              <P>Start smaller than your ego wants to:</P>
              <DataTable
                headers={["Mode", "What It Is Good For"]}
                rows={[
                  ["1 agent", "Learn the artifact flow without coordination overhead"],
                  ["2 agents", "Feel the first real coordination benefits and start using Agent Mail seriously"],
                  ["4 agents", "Experience meaningful swarm behavior where routing and handoff start to matter a lot"],
                ]}
              />
            </SubSection>

            <SubSection title="The Cheat Card">
              <P highlight>If you want the loop on one screen, keep this:</P>
              <NumberedList items={[
                "Plan with multiple models",
                "Synthesize into one markdown plan",
                "Create beads in br",
                "Add dependencies",
                "Run bv",
                "Claim the bead in Agent Mail",
                "Implement",
                "Do a fresh-eyes review",
                "Close the bead",
                "Repeat",
              ]} />
            </SubSection>

            <SubSection title="When to Graduate to the Full Flywheel">
              <P>Move up to the <a href="/complete-guide" className="text-[#FF5500] hover:text-[#FFBD2E] transition-colors font-medium underline decoration-[#FF5500]/30 underline-offset-4 hover:decoration-[#FFBD2E]/50">full guide</a> when one or more of these becomes true:</P>
              <BulletList items={[
                "Your projects are large enough that you want much richer planning workflows",
                "You want stronger AGENTS.md operating manuals with comprehensive tool documentation",
                "You want repeatable prompt libraries and skills",
                "You want better recovery from compaction and session loss",
                "You want memory systems (CASS, CM) that improve the workflow over time",
              ]} />
              <P>At that point, the bigger document stops feeling like overhead and starts feeling like leverage.</P>
            </SubSection>
          </GuideSection>

          <Divider />
          <FooterCTA />

        </div>
      </main>
    </ErrorBoundary>
  );
}


// =============================================================================
// HERO SECTION
// =============================================================================
function Hero() {
  return (
    <section className="relative overflow-hidden pt-28 pb-24 md:pt-44 md:pb-36 bg-[#020408] border-b border-white/[0.04]">
      {/* Layered ambient effects for depth */}
      <div className="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-[0.03] mix-blend-overlay pointer-events-none" />
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-[600px] bg-[radial-gradient(ellipse_at_top,rgba(255,85,0,0.08),transparent_70%)]" />
      {/* Secondary purple orb — lower left for depth */}
      <div className="absolute bottom-0 left-0 w-[500px] h-[500px] bg-[radial-gradient(ellipse_at_bottom_left,rgba(167,139,250,0.05),transparent_70%)] pointer-events-none" />
      {/* Floating amber accent orb */}
      <div className="absolute top-1/3 right-[10%] w-[300px] h-[300px] bg-[radial-gradient(circle,rgba(255,189,46,0.04),transparent_60%)] pointer-events-none animate-[float_8s_ease-in-out_infinite]" />

      <div className="relative mx-auto text-center px-6 z-10 max-w-5xl">
        {/* Badge with shimmer effect */}
        <div className="relative inline-flex items-center gap-3 rounded-full border border-[#FF5500]/20 bg-[#FF5500]/5 px-6 py-2.5 text-[0.7rem] font-black uppercase tracking-[0.3em] text-[#FF5500] mb-10 shadow-[0_0_20px_rgba(255,85,0,0.15)] backdrop-blur-xl overflow-hidden">
          <div className="absolute inset-0 bg-[linear-gradient(110deg,transparent_25%,rgba(255,85,0,0.12)_50%,transparent_75%)] bg-[length:200%_100%] animate-[shimmer_3s_ease-in-out_infinite] pointer-events-none" />
          <Sparkles className="h-4 w-4 relative z-10" />
          <span className="relative z-10">The Focused Version</span>
        </div>

        <h1 className="text-[2.75rem] sm:text-6xl md:text-7xl lg:text-8xl font-black text-white tracking-tighter drop-shadow-2xl leading-[1.05]">
          The Core <br/><span className="bg-gradient-to-r from-[#FF5500] to-[#FFBD2E] bg-clip-text text-transparent">Flywheel</span>
        </h1>

        <p className="mx-auto mt-8 sm:mt-10 max-w-2xl sm:max-w-3xl text-lg sm:text-xl md:text-2xl text-zinc-400 leading-relaxed font-light">
          Three tools. One loop. Most of the value. Learn the beginner-friendly core of the Agentic Coding Flywheel: <Hl>Agent Mail</Hl> for coordination, <Hl>br</Hl> for task structure, and <Hl>bv</Hl> for intelligent routing.
        </p>

        <div className="mt-10 sm:mt-12 flex flex-col sm:flex-row items-center justify-center gap-3 sm:gap-4">
          <a
            href="#core-loop"
            className="w-full sm:w-auto inline-flex items-center justify-center rounded-2xl bg-[#FF5500] px-8 py-4 text-sm font-black text-black uppercase tracking-widest transition-all duration-300 hover:bg-[#FFBD2E] hover:shadow-[0_0_40px_rgba(255,189,46,0.4)] hover:-translate-y-1 active:scale-95"
          >
            Start Learning
          </a>
          <a
            href="/complete-guide"
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-2xl border border-white/10 bg-white/[0.02] px-8 py-4 text-sm font-bold text-zinc-400 uppercase tracking-widest transition-all duration-300 hover:border-[#FF5500]/30 hover:text-white hover:-translate-y-1 hover:bg-white/[0.04]"
          >
            Full Guide <ArrowRight className="h-4 w-4" />
          </a>
        </div>

        {/* Scroll indicator */}
        <div className="mt-16 md:mt-20 flex flex-col items-center gap-2 animate-[float_3s_ease-in-out_infinite]">
          <span className="text-[0.6rem] font-bold uppercase tracking-[0.3em] text-white/20">Scroll to explore</span>
          <ChevronDown className="h-4 w-4 text-white/20" />
        </div>
      </div>
    </section>
  );
}


// =============================================================================
// HELPER CARD - For DCG, UBS, CASS section
// =============================================================================
function HelperCard({
  icon,
  name,
  fullName,
  color,
  description,
  usage,
  command,
}: {
  icon: React.ReactNode;
  name: string;
  fullName: string;
  color: string;
  description: string;
  usage: string;
  command: string;
}) {
  return (
    <div
      className="group relative flex flex-col rounded-[2rem] border border-white/[0.04] bg-[#05070A] overflow-hidden transition-all duration-500 hover:-translate-y-2 shadow-2xl"
      style={{ ['--card-color' as string]: color }}
    >
      {/* Colored top accent bar */}
      <div
        className="h-[2px] w-full opacity-40 group-hover:opacity-80 transition-opacity duration-500"
        style={{ background: `linear-gradient(90deg, transparent, ${color}, transparent)` }}
      />

      <div className="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-[0.02] mix-blend-overlay pointer-events-none" />
      <div
        className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none"
        style={{ background: `radial-gradient(ellipse at top, ${color}0A, transparent 70%)` }}
      />

      <div className="relative z-10 flex flex-col h-full gap-5 p-8">
        {/* Icon with glow on hover */}
        <div
          className="flex h-12 w-12 items-center justify-center rounded-xl border transition-all duration-500 group-hover:scale-110"
          style={{
            borderColor: `${color}33`,
            backgroundColor: `${color}0D`,
            color: color,
          }}
        >
          <div className="transition-all duration-500 group-hover:drop-shadow-[0_0_8px_var(--card-color)]">
            {icon}
          </div>
        </div>

        <div>
          <div className="text-[0.6rem] font-bold uppercase tracking-[0.2em] opacity-50 group-hover:opacity-70 transition-opacity duration-500" style={{ color }}>
            {fullName}
          </div>
          <h4 className="text-2xl font-black text-white tracking-tight mt-1">
            {name}
          </h4>
        </div>

        <p className="text-[0.95rem] text-zinc-400 font-light leading-relaxed flex-1">
          {description}
        </p>

        <div className="pt-5 border-t border-white/[0.04] space-y-3">
          <div>
            <span className="text-[0.6rem] font-bold text-white/30 uppercase tracking-[0.15em] block mb-1.5">Usage</span>
            <p className="text-[0.85rem] text-zinc-400 font-light leading-relaxed">{usage}</p>
          </div>
          <code
            className="block text-[0.8rem] text-zinc-500 font-mono bg-white/[0.02] rounded-lg px-3 py-2.5 border-l-2 border border-white/[0.04] transition-colors duration-500 group-hover:text-zinc-400"
            style={{ borderLeftColor: `${color}40` }}
          >
            {command}
          </code>
        </div>
      </div>
    </div>
  );
}


// =============================================================================
// FOOTER CTA
// =============================================================================
function FooterCTA() {
  return (
    <section className="relative overflow-hidden rounded-[3rem] border border-[#FF5500]/20 bg-[#0A0D14] py-24 md:py-32 my-32 shadow-[0_50px_100px_-20px_rgba(255,85,0,0.15)] group">
      <div className="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-[0.03] mix-blend-overlay pointer-events-none" />
      {/* Multi-layer gradient effects */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-full bg-[radial-gradient(ellipse_at_center,rgba(255,85,0,0.05),transparent_70%)] opacity-0 group-hover:opacity-100 transition-opacity duration-1000" />
      <div className="absolute -top-20 -right-20 w-[300px] h-[300px] bg-[radial-gradient(circle,rgba(255,189,46,0.06),transparent_60%)] pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-1000 delay-200" />
      <div className="absolute -bottom-20 -left-20 w-[300px] h-[300px] bg-[radial-gradient(circle,rgba(167,139,250,0.04),transparent_60%)] pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-1000 delay-300" />

      <div className="relative mx-auto text-center px-6 z-10">
        {/* Badge with shimmer */}
        <div className="relative inline-flex items-center gap-3 rounded-full border border-[#FF5500]/30 bg-[#FF5500]/10 px-6 py-2.5 text-[0.7rem] font-black uppercase tracking-[0.3em] text-[#FF5500] mb-10 shadow-inner overflow-hidden">
          <div className="absolute inset-0 bg-[linear-gradient(110deg,transparent_25%,rgba(255,85,0,0.15)_50%,transparent_75%)] bg-[length:200%_100%] animate-[shimmer_3s_ease-in-out_infinite] pointer-events-none" />
          <Rocket className="h-4 w-4 relative z-10" />
          <span className="relative z-10">Ready for More?</span>
        </div>

        <h2 className="text-3xl sm:text-5xl md:text-6xl font-black text-white tracking-tighter drop-shadow-2xl">
          Graduate to the Full <span className="bg-gradient-to-r from-[#FF5500] to-[#FFBD2E] bg-clip-text text-transparent">Flywheel</span>
        </h2>

        <p className="mx-auto mt-8 max-w-2xl text-base sm:text-lg text-zinc-400 leading-relaxed font-light">
          Once the core loop feels natural, the full methodology adds richer planning workflows, memory systems, prompt libraries, and the complete Dicklesworthstone stack.
        </p>

        <div className="mt-10 sm:mt-12 flex flex-col sm:flex-row justify-center gap-3 sm:gap-4">
          <a
            href="/complete-guide"
            className="w-full sm:w-auto inline-flex items-center justify-center rounded-2xl bg-[#FF5500] px-8 py-4 text-sm font-black text-black uppercase tracking-widest transition-all duration-300 hover:bg-[#FFBD2E] hover:shadow-[0_0_40px_rgba(255,189,46,0.4)] hover:-translate-y-1 active:scale-95"
          >
            Read the Full Guide
          </a>
          <a
            href="/wizard/os-selection"
            className="w-full sm:w-auto inline-flex items-center justify-center rounded-2xl border border-white/10 bg-white/[0.02] px-8 py-4 text-sm font-bold text-zinc-400 uppercase tracking-widest transition-all duration-300 hover:border-[#FF5500]/30 hover:text-white hover:-translate-y-1 hover:bg-white/[0.04]"
          >
            Install the Stack
          </a>
        </div>
      </div>
    </section>
  );
}
