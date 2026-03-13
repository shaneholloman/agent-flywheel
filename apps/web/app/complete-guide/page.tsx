import { ErrorBoundary } from "@/components/ui/error-boundary";
import { Sparkles, Rocket } from "lucide-react";

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
  StatCard,
  CodeBlock,
} from "@/components/complete-guide/guide-components";
import { PlanToBeadsViz } from "@/components/complete-guide/plan-to-beads-viz";
import { AgentMailViz } from "@/components/complete-guide/agent-mail-viz";
import { SwarmExecutionViz } from "@/components/complete-guide/swarm-execution-comparison";
import { RepresentationLadder } from "@/components/complete-guide/representation-ladder";
import { ContextHorizonViz } from "@/components/complete-guide/context-horizon-viz";
import { CoordinationTrioViz } from "@/components/complete-guide/coordination-trio-viz";
import { ConvergenceViz } from "@/components/complete-guide/convergence-viz";
import { PlanEvolutionStudio } from "@/components/complete-guide/plan-evolution-studio";
import { FlywheelDiagram } from "@/components/complete-guide/flywheel-diagram";


export default function CompleteGuidePage() {
  return (
    <ErrorBoundary>
      <main className="min-h-screen bg-[#020408] selection:bg-[#FF5500]/20 selection:text-white overflow-x-hidden pb-32">
        <Hero />

        <div className="mx-auto max-w-[1000px] px-6 lg:px-12 relative mt-20">

          {/* ============================================================= */}
          {/* SECTION 1: THE COMPLETE WORKFLOW                                */}
          {/* ============================================================= */}
          <GuideSection id="workflow" number="1" title="The Complete Workflow">
            <P highlight>This is the end-to-end methodology for creating software with frontier AI models, exhaustive markdown planning, beads-based task management, and coordinated agent swarms. Every project follows the same arc, whether it is a small CLI tool or a complex web application. This guide is about moving the hardest thinking into representations that still fit into model context windows. That is the whole game.</P>

            <FlywheelDiagram />

            <P>It starts with you. You have an idea for a piece of software. Maybe a web app, maybe a CLI tool, maybe a complex system. Instead of opening an editor and starting to code, you do something that feels counterintuitive: you spend the vast majority of your time planning.</P>

            <NumberedList items={[
              <><strong>You explain what you want to build</strong> to a frontier model like GPT Pro with Extended Reasoning. Your concept, your goals, the user workflows, why it matters. The model produces an initial markdown plan: a comprehensive design document for the entire system.</>,
              <><strong>You ask competing models to create their own plans.</strong> Claude Opus, Gemini with Deep Think, Grok Heavy. Each one independently designs the same project. They come up with surprisingly different approaches, each with unique strengths and blind spots.</>,
              <><strong>You synthesize the best ideas from all plans into one.</strong> GPT Pro analyzes the competing plans and produces a &quot;best of all worlds&quot; hybrid that blends the strongest ideas from every model into a single superior document.</>,
              <><strong>You iterate relentlessly.</strong> Round after round of refinement, each time in a fresh conversation, until the suggestions become incremental. Plans created this way routinely reach 3,000 to 6,000+ lines. They are not slop. They are the result of countless iterations and feedback from many frontier models.</>,
              <><strong>You convert the plan into beads.</strong> Beads are self-contained work units (like Jira or Linear tasks, but optimized for use by coding agents). Each bead carries its own context, reasoning, dependencies, and test obligations. A complex plan might produce 200-500 beads with a full dependency graph.</>,
              <><strong>You polish the beads obsessively.</strong> &quot;Check your beads N times, implement once,&quot; where N is as many as you can stomach. Each polishing round finds things the previous round missed: duplicates, missing dependencies, incomplete context. You run this 4-6+ times until convergence.</>,
              <><strong>You launch a swarm of agents.</strong> Claude Code, Codex, and Gemini-CLI sessions running in parallel, all in the same codebase. They coordinate through Agent Mail, choose work intelligently using bv&apos;s graph-theory routing, and execute beads systematically.</>,
              <><strong>You tend the swarm, not the code.</strong> The human checks for stuck beads, rescues agents after context compaction, sends review prompts, and ensures flow quality. You are the clockwork deity. You designed the machine, set it running, and now you manage it.</>,
              <><strong>Agents review, test, and harden.</strong> Self-review with fresh eyes, cross-agent review, random code exploration, testing coverage, UI/UX polish. Rounds and rounds until reviews come back clean.</>,
            ]} />

            <P>That is the whole movie. For the CASS Memory System, this process turned a 5,500-line markdown plan into 347 beads. Twenty-five agents produced 11,000 lines of working, tested code with 204 commits in about five hours. You can see the <a href="https://github.com/Dicklesworthstone/cass_memory_system/blob/main/PLAN_FOR_CASS_MEMORY_SYSTEM.md" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">actual plan</a>, the <a href="https://dicklesworthstone.github.io/cass-memory-system-agent-mailbox-viewer/viewer/" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">actual agent mail messages</a>, and the <a href="https://dicklesworthstone.github.io/beads_for_cass/" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">actual beads</a> for yourself.</P>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 my-12">
              <StatCard value="5,500" label="Line Plan" sublabel="Synthesized from 4 frontier models" />
              <StatCard value="347" label="Beads" sublabel="With full dependency structure" />
              <StatCard value="11k" label="Lines of Code" sublabel="Working, tested, production-ready" />
              <StatCard value="~5 hrs" label="To Ship" sublabel="25 agents, 204 commits" />
            </div>

            <BlockQuote>Once you have the beads in good shape based on a great markdown plan, I almost view the project as a foregone conclusion at that point. The rest is basically mindless &quot;machine tending&quot; of your swarm of 5-15 agents.</BlockQuote>

            <P>The frontier models and coding agent harnesses really are that good already. They just need this extra level of tooling, prompting, and workflows to reach their full potential. The rest of this guide zooms into each stage.</P>

            <SubSection title="Glossary">
              <DataTable
                headers={["Term", "Plain-English Meaning", "Why It Matters"]}
                rows={[
                  ["Markdown plan", "A huge design document where the whole project still fits in context", "Where architecture, workflows, tradeoffs, and intent get worked out"],
                  ["Bead", "A self-contained work unit in br with context, dependencies, and test obligations", "What agents actually execute"],
                  ["Bead graph", "The full dependency structure across all beads", "What lets bv compute the right next work"],
                  ["Plan space", "The reasoning mode where you are still shaping the whole system", "The cheapest place to buy correctness"],
                  ["Bead space", "The reasoning mode where you are shaping executable work packets", "Where planning becomes swarm-ready"],
                  ["Code space", "The implementation and verification layer inside the codebase", "Where local execution happens"],
                  ["AGENTS.md", "The operating manual every agent must reload after compaction", "Keeps the swarm from forgetting how to behave"],
                  ["Skill", "A reusable instruction bundle that teaches agents how to use a tool or execute a workflow", "How methods become repeatable instead of staying as tacit lore"],
                  ["Compaction", "Context compression inside a long-running agent session", "Why re-reading AGENTS.md is mandatory"],
                  ["Fungible agents", "Generalist agents that can replace one another", "Makes crashes and amnesia survivable"],
                ]}
              />
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 2: WHY PLANNING DOMINATES                              */}
          {/* ============================================================= */}
          <GuideSection id="philosophy" number="2" title="Why Planning Is 85% of the Work">
            <P>You spend 85% of your time on planning. The first time you try it, it feels wrong. No code is being written. Every instinct tells you to just start building. That discomfort is the signal that you are doing it right.</P>

            <BlockQuote>The models are far smarter when reasoning about a plan that is very detailed and fleshed out but still trivially small enough to easily fit within their context window. This is really the key insight behind my obsessive focus on planning and why I spend 80%+ of my time on that part.</BlockQuote>

            <ContextHorizonViz />

            <P>A markdown plan, even a massive 6,000-line one, is still vastly smaller than the codebase it describes. When models reason about a plan instead of raw implementation, they can hold the <Hl>whole system in their context window at once</Hl>. Once you start turning that plan into code, the system rapidly becomes too large to understand holistically. You are doing global reasoning while global reasoning is still possible.</P>

            <BlockQuote>I think you get a better result faster by creating one big comprehensive, detailed, granular plan. That&apos;s the only way to get these models to use their big brains to understand the entire system all at the same time.</BlockQuote>

            <P>Planning tokens are far fewer and cheaper than implementation tokens. A big, complex markdown plan is shorter than a few substantive code files, let alone a whole project. That means you can afford many more refinement rounds in planning than in implementation. Each planning round evaluates system-wide consequences, not just local code edits. Each improvement to the plan gets amortized across every downstream bead and code change. Planning is the cheapest place to buy correctness, coherence, and ambition.</P>

            <BlockQuote>This workflow is what prevents it from generating slop. I spend 85% of my time and energy in the planning phases.</BlockQuote>

            <P>Without front-loaded planning, agents are effectively improvising architecture from a narrow local window into the codebase. That is exactly when you get placeholder abstractions, missing workflow details, contradictory assumptions, and compatibility shims that nobody actually wanted. With a detailed plan and polished beads, the models are no longer inventing the system from scratch while coding. They are executing a constrained, coherent design.</P>

            <SubSection title="The Human Part">
              <BlockQuote>The plan creation is the most free form, creative, human part of the process. I just usually start writing in a messy stream of thought way to convey the basic concept and then collaboratively work the agent to flesh it out in an initial draft.</BlockQuote>

              <P>The human is not there to hand-author every line of the plan. The human is there to inject intent, judgment, taste, product sense, and strategic direction at the point where those qualities affect the entire downstream system. Once the plan is excellent, the rest becomes much more mechanical.</P>

              <P>When prompting the model to create the initial markdown plan, you spend a lot of time explaining the goals and intent of the project and detailing the workflows: how you want the final software to work from the standpoint of the user&apos;s interactions. The more the model understands about what you&apos;re really trying to accomplish and the end goal and why, it can do a better job for you.</P>

              <P>Debates belong in planning, not implementation. As many important disagreements as possible should happen before the swarm is burning expensive implementation tokens. Implementation can still surface surprises, but the posture of the workflow is to front-load decisions into plan space.</P>
            </SubSection>

            <SubSection title="Three Reasoning Spaces">
              <P>The methodology separates work into three spaces, each with a different artifact and a different question it answers:</P>

              <RepresentationLadder />

              <DataTable
                headers={["Space", "Primary Artifact", "What You Decide There"]}
                rows={[
                  ["Plan space", "Large markdown plan", "Architecture, features, workflows, tradeoffs — the whole system still fits in context"],
                  ["Bead space", "br issues + dependency graph", "Task boundaries, execution order, embedded context — agents need explicit, local work units"],
                  ["Code space", "Source files + tests", "Implementation and verification — the plan has already constrained the high-level decisions"],
                ]}
              />

              <P>Plan space is where you figure out what the system should be. Bead space is where you turn that into <Hl>executable memory</Hl>, a graph of self-contained work units detailed enough that agents don&apos;t have to keep consulting the full plan. Code space is where agents implement, review, and test locally. The key is knowing which space you&apos;re in: if you are still redesigning the product, stay in plan space. If you are mainly packaging the work for execution, move to bead space.</P>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 3: CREATING & REFINING THE PLAN                        */}
          {/* ============================================================= */}
          <GuideSection id="planning" number="3" title="Creating & Refining the Markdown Plan">
            <SubSection title="Before You Start: The Foundation Bundle">
              <P>Before writing the plan itself, you need a coherent foundation. Think of it as assembling a <Hl>foundation bundle</Hl>: a tech stack decision, an initial architectural direction, a strong AGENTS.md file bootstrapped from a known-good template, up-to-date best-practices guides, and enough product and workflow explanation for the models to understand what &quot;good&quot; looks like.</P>

              <P>A strong bootstrap move is to start every new project by copying an AGENTS.md from an existing project that already has good general behavioral rules, safety notes, tool blurbs, and coordination guidance. Later, once the plan and beads are clearer, you ask agents to replace the project-specific content while preserving the general rules that carry across projects.</P>

              <TipBox variant="warning">
                Weak foundations leak uncertainty into every later stage. If any of these are missing, the plan will silently absorb ambiguity that later shows up as bad beads, confused agents, and sloppy implementation.
              </TipBox>
            </SubSection>

            <SubSection title="Writing the Initial Plan">
              <P>You don&apos;t even need to write the initial markdown plan yourself. You can write that with GPT Pro, just explaining what it is you want to make. Claude Opus in the web app is also good for this, but GPT Pro with Extended Reasoning remains the top choice for initial planning. No other model can touch Pro on the web when it&apos;s dealing with input that easily fits into its context window. It&apos;s truly unique. And since you get it on an all-you-can-eat basis with a Pro plan, take full advantage of that.</P>

              <P>You usually also specify the tech stack. For a web app, it&apos;s generally TypeScript, Next.js 16, React 19, Tailwind, Supabase, with anything performance-critical in Rust compiled to WASM. For a CLI tool, usually Go or Rust. If the stack isn&apos;t obvious, do a deep research round with GPT Pro or Gemini and have them study all the relevant libraries and make a suggestion taking your goals into account.</P>
            </SubSection>

            <SubSection title="What a First Plan Looks Like">
              <P>A first serious markdown plan would not say &quot;build a notes app.&quot; It would start spelling out the actual user-visible system:</P>

              <BulletList items={[
                "Users upload Markdown files through a drag-and-drop UI.",
                "The system parses frontmatter tags and stores upload failures for review.",
                "Search must support keyword, tag, and date filtering with low perceived latency.",
                "Admins need a dedicated screen showing ingestion failures, parse reasons, and retry actions.",
                "Auth is internal-only; unauthorized users must never see document content or metadata.",
                "We need e2e coverage for upload success, upload failure, search, filtering, and admin review.",
              ]} />

              <P>That is still only the beginning. But it already shows the difference between ordinary brainstorming and Flywheel planning: the plan tries to make the whole product legible before any code exists.</P>
            </SubSection>

            <SubSection title="Multi-Model Plans">
              <P>For the best results, ask multiple frontier models to independently create plans for the same project. GPT Pro, Claude Opus, Gemini with Deep Think, Grok Heavy. Each comes up with pretty different plans. Different frontier models have different &quot;tastes&quot; and blind spots. Passing a plan through a gauntlet of different models is the cheapest way to buy architectural robustness.</P>

              <P>In the CASS Memory System project, the <a href="https://github.com/Dicklesworthstone/cass_memory_system/tree/main/competing_proposal_plans" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">competing plans are publicly visible</a>. This pattern has been used across at least 10 sessions spanning 7+ projects.</P>

              <P>Then show their competing plans to GPT Pro with this prompt:</P>

              <PromptBlock
                title="Best-of-All-Worlds Synthesis"
                prompt={`I asked 3 competing LLMs to do the exact same thing and they came up with pretty different plans which you can read below. I want you to REALLY carefully analyze their plans with an open mind and be intellectually honest about what they did that's better than your plan. Then I want you to come up with the best possible revisions to your plan (you should simply update your existing document for your original plan with the revisions) that artfully and skillfully blends the "best of all worlds" to create a true, ultimate, superior hybrid version of the plan that best achieves our stated goals and will work the best in real-world practice to solve the problems we are facing and our overarching goals while ensuring the extreme success of the enterprise as best as possible; you should provide me with a complete series of git-diff style changes to your original plan to turn it into the new, enhanced, much longer and detailed plan that integrates the best of all the plans with every good idea included (you don't need to mention which ideas came from which models in the final revised enhanced plan):`}
                where="GPT Pro web app with Extended Reasoning"
                whyItWorks="Forces the model to be intellectually honest about what competitors did better, then synthesize a hybrid that's stronger than any individual plan. This is the signature phrase of the methodology — 'best of all worlds' appears in 10+ distinct sessions across 7+ projects."
              />

              <P>Take GPT Pro&apos;s output (the git-diff style revisions) and paste it into Claude Code or Codex to integrate the revisions in-place:</P>

              <PromptBlock
                title="Integrate Synthesis Revisions"
                prompt={`OK, now integrate these revisions to the markdown plan in-place; use ultrathink and be meticulous. At the end, you can tell me which changes you wholeheartedly agree with, which you somewhat agree with, and which you disagree with:

[Pasted synthesis output]`}
                where="Claude Code or Codex"
                whyItWorks="Claude critically assesses each suggestion, providing a second layer of quality filtering. You get its honest assessment of which changes actually improve things."
              />

              <PlanEvolutionStudio />
            </SubSection>

            <SubSection title="Iterative Refinement">
              <P>Now paste the current plan into a <strong>fresh</strong> GPT Pro conversation with this prompt. The key word is fresh. Fresh conversations prevent the model from anchoring on its own prior output. Repeat 4-5 rounds:</P>

              <PromptBlock
                title="Plan Refinement Prompt"
                prompt={`Carefully review this entire plan for me and come up with your best revisions in terms of better architecture, new features, changed features, etc. to make it better, more robust/reliable, more performant, more compelling/useful, etc.

For each proposed change, give me your detailed analysis and rationale/justification for why it would make the project better along with the git-diff style changes relative to the original markdown plan shown below:

<PASTE YOUR EXISTING COMPLETE PLAN HERE>`}
                where="GPT Pro web app — fresh conversation each round"
                whyItWorks="This has never failed to improve a plan significantly. Each round finds architectural issues, missing features, and robustness improvements that the previous round missed."
              />

              <P>This has never failed to improve a plan significantly. The best part is that you can start a fresh conversation in ChatGPT and do it all again once Claude Code or Codex finishes integrating your last batch of suggested revisions. After four or five rounds of this, you tend to reach a steady-state where the suggestions become very incremental.</P>

              <P>You can still get extra mileage by blending in smart ideas from Gemini with Deep Think enabled, or from Grok Heavy, or Opus in the web app, but you still want to use GPT Pro on the web as the final arbiter of what to take from which model and how to best integrate it.</P>

              <TipBox>
                <strong>The &quot;Lie to Them&quot; technique:</strong> Models tend to stop looking for problems after finding ~20-25 issues. If you tell them to find &quot;all&quot; problems, they stop early. The solution: lie to them and give them a huge number, and then they keep cranking until they have uncovered all of them. This works for plan revisions, bead-to-plan cross-references, and any comparison/audit task.
              </TipBox>

              <PromptBlock
                title="Overshoot Mismatch Hunt"
                prompt={`Do this again, and actually be super super careful: can you please check over the plan again and compare it to all that feedback I gave you? I am positive that you missed or screwed up at least 80 elements of that complex feedback.`}
                where="After any review pass that feels too short or self-satisfied"
                whyItWorks="By claiming 80+ errors exist, the model keeps searching exhaustively rather than satisfying itself with a partial list."
              />

              <P>Plans created this way routinely reach 3,000-6,000+ lines. They are not slop. They are the result of countless iterations and blending of ideas and feedback from many models. For the CASS GitHub Pages export feature, the plan went through multiple rounds over about 3 hours, growing to approximately <a href="https://github.com/Dicklesworthstone/coding_agent_session_search/blob/main/PLAN_TO_CREATE_GH_PAGES_WEB_EXPORT_APP.md" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">3,500 lines</a>. You can also see a <a href="https://github.com/Dicklesworthstone/jeffreysprompts.com/blob/main/PLAN_TO_MAKE_JEFFREYSPROMPTS_WEBAPP_AND_CLI_TOOL.md" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">6,000-line plan</a> to get a feel for the scale.</P>

              <P>It feels slow because no code is being written. But if you do it correctly and then start up enough agents in your swarm with Agent Mail, beads, and bv, the code will be written so ridiculously quickly that it more than makes up for this slow part. And what&apos;s more, the code will be really good.</P>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 4: PLANS BECOME BEADS                                  */}
          {/* ============================================================= */}
          <GuideSection id="beads" number="4" title="Converting the Plan into Beads">
            <P>Then you&apos;re ready to turn the plan into beads. Think of these as epics, tasks, and subtasks with an associated dependency structure. The name comes from <a href="https://github.com/AstroBeads/beads" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">Steve Yegge&apos;s amazing project</a>, which is like Jira or Linear, but optimized for use by coding agents. They are stored locally in <code>.beads/</code> JSONL files that commit with your code.</P>

            <P highlight>There are two separate stages here. The planning is and should be prior to and orthogonal to beads. You should always have a super detailed markdown plan first. Then treat transforming that markdown plan into beads as a separate, distinct problem with its own challenges. But once you&apos;re in &quot;bead space&quot; you never look back at the markdown plan. But that&apos;s why it&apos;s so critical to transfer all the details over to the beads.</P>

            <PromptBlock
              title="Plan to Beads Conversion"
              prompt={`OK so please take ALL of that and elaborate on it more and then create a comprehensive and granular set of beads for all this with tasks, subtasks, and dependency structure overlaid, with detailed comments so that the whole thing is totally self-contained and self-documenting (including relevant background, reasoning/justification, considerations, etc.-- anything we'd want our "future self" to know about the goals and intentions and thought process and how it serves the over-arching goals of the project.) Use only the \`br\` tool to create and modify the beads and add the dependencies. Use ultrathink.`}
              where="Claude Code with Opus"
              whyItWorks="This prompt forces the agent to treat plan-to-beads as a translation problem rather than task extraction. The key sentence is the requirement that beads be so detailed you never need to reopen the markdown plan. That pushes rationale, test expectations, design intent, and sequencing into the bead graph itself. It also blocks a common failure mode where the model collapses a rich plan into terse todo items. By explicitly asking for tasks, subtasks, dependency structure, comments, and future-self context, you are telling the model that memory density matters more than brevity."
            />

            <P>For existing projects with a specific plan file, prefix it: &quot;OK so now read ALL of PLAN_FILE_NAME.md; please take ALL of that and elaborate on it...&quot; The rest of the prompt stays the same.</P>

            <PlanToBeadsViz />

            <SubSection title="Beads as Executable Memory">
              <P>The plan is still the best artifact for whole-system thought. But once a swarm is involved, what you need is not a beautiful essay. You need a task graph that carries enough local context for agents to act correctly without repeatedly loading the whole project back into memory. If the beads are weak, the swarm becomes improvisational. If the beads are rich, the swarm becomes almost mechanical.</P>

              <BlockQuote>It works better if most of the decision making is made ahead of time during the planning phases and then is embedded in the beads.</BlockQuote>

              <BulletList items={[
                <><strong>Self-contained:</strong> Beads must be so detailed that you never need to refer back to the original markdown plan. Every piece of context, reasoning, and intent should be embedded.</>,
                <><strong>Rich content:</strong> Beads can and should contain long descriptions with embedded markdown. They don&apos;t need to be short bullet-point entries. You can embed snippets of markdown inside the beads and they often do; JSONL is just how they serialize.</>,
                <><strong>Complete coverage:</strong> Everything from the markdown plan must be embedded into the beads. Lose nothing in the conversion.</>,
                <><strong>Explicit dependencies:</strong> The dependency graph must be correct; this is what enables bv to compute the optimal execution order.</>,
                <><strong>Include testing:</strong> Beads should include comprehensive unit tests and e2e test scripts with great, detailed logging.</>,
              ]} />

              <TipBox variant="info">
                Conceptually, the beads are more for the agents than for you. The models are the primary consumer of beads. You can always have agents interpret beads back into markdown if needed.
              </TipBox>
            </SubSection>

            <SubSection title="What Good Beads Look Like">
              <P>To make this concrete, imagine a small internal web app called &quot;Atlas Notes&quot; for uploading and searching team notes. Instead of one vague task like &quot;build Atlas Notes,&quot; the plan becomes many self-contained beads:</P>

              <BulletList items={[
                <><strong>br-101 Upload and Parse Pipeline:</strong> Describes accepted file formats, frontmatter parsing expectations, where failures are logged, what happens on malformed input, and which unit and e2e tests prove the pipeline works.</>,
                <><strong>br-102 Search Index and Query UX:</strong> Carries the search behavior, indexing rules, latency expectations, filter semantics, empty-state UX, and test coverage for keyword/tag/date combinations.</>,
                <><strong>br-103 Ingestion Failure Dashboard:</strong> Includes the admin workflow, permission boundaries, retry logic, logging expectations, and the exact reasons this dashboard matters for operational trust.</>,
              ]} />

              <P>The titles are not the important part. What matters is that each bead is rich enough that a fresh agent can open it and immediately understand what correct implementation looks like, why it matters, and how to verify it.</P>

              <P>For the CASS Memory System (5,500-line plan), the conversion produced 347 beads with complete dependency structure. FrankenSQLite had hundreds of beads created via parallel subagents. For complex projects, expect 200-500 initial beads.</P>

              <BlockQuote>Once you convert the plan docs into beads, you&apos;re supposed to not really need to refer back to the docs if you did a good job. The docs are still useful though, for people and for agents in various contexts, but you don&apos;t need to swamp all the agents with the full plan once you&apos;ve turned it into beads.</BlockQuote>
            </SubSection>

            <SubSection title="Beads CLI Quick Reference">
              <CodeBlock language="bash" code={`br create --title "..." --priority 2 --label backend    # Create issue
br list --status open --json                             # List open issues
br ready --json                                          # Show unblocked tasks
br show <id>                                             # View issue details
br update <id> --status in_progress                      # Claim task
br close <id> --reason "Completed"                       # Close task
br dep add <id> <other-id>                               # Add dependency
br comments add <id> "Found root cause..."               # Add comment
br sync --flush-only                                     # Export to JSONL (no git ops)`} />
              <P>Priority uses numbers: P0=critical, P1=high, P2=medium, P3=low, P4=backlog. Types: task, bug, feature, epic, question, docs. <code>br ready</code> shows only unblocked work. Storage is a SQLite + JSONL hybrid; the JSONL files commit with your code.</P>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 5: POLISHING BEADS                                     */}
          {/* ============================================================= */}
          <GuideSection id="polishing" number="5" title="Check Your Beads N Times, Implement Once">
            <P>Before you burn up a lot of tokens with a big agent swarm on a new project, the old woodworking maxim of &quot;Measure twice, cut once!&quot; is worth revising as <strong>&quot;Check your beads N times, implement once,&quot;</strong> where N is basically as many as you can stomach. This is the step most people underinvest in.</P>

            <P>After the initial conversion finishes, do a round of this prompt. If Claude Code did a compaction at any point, be sure to tell it to re-read your AGENTS.md file first:</P>

            <PromptBlock
              title="Bead Polishing Prompt"
              prompt={`Reread AGENTS.md so it's still fresh in your mind. Check over each bead super carefully-- are you sure it makes sense? Is it optimal? Could we change anything to make the system work better for users? If so, revise the beads. It's a lot easier and faster to operate in "plan space" before we start implementing these things!

DO NOT OVERSIMPLIFY THINGS! DO NOT LOSE ANY FEATURES OR FUNCTIONALITY!

Also, make sure that as part of these beads, we include comprehensive unit tests and e2e test scripts with great, detailed logging so we can be sure that everything is working perfectly after implementation. Remember to ONLY use the \`br\` tool to create and modify the beads and to add the dependencies to beads. Use ultrathink.`}
              where="Claude Code with Opus — run 4-6+ times"
              whyItWorks="This prompt keeps the system from freezing beads too early. It tells the model to stay in plan space for as long as it is still finding meaningful improvements, which is exactly where reasoning is cheapest and most global. The warnings against oversimplifying and losing functionality are crucial because models otherwise tend to 'improve' artifacts by deleting complexity they do not fully understand. It combines local bead QA (via br) with graph QA (via bv), and forces tests into the bead definitions themselves so test work cannot be deferred into an afterthought."
            />

            <ConvergenceViz />

            <P>From real sessions, polishing involves duplicate detection and merging, quality scoring on WHAT/WHY/HOW criteria, filling empty bead descriptions, correcting dependency links, and cross-referencing beads against the markdown plan to ensure nothing was lost. FrankenSQLite identified 9 exact duplicate pairs and closed them, choosing survivors based on &quot;richer testing specs, better dependency chains, and higher priority.&quot;</P>

            <P>Tell agents to go through each bead and explicitly check it against the markdown plan. Or vice versa — go through the markdown plan and cross-reference every single thing against the beads (both closed and open) to ensure complete coverage.</P>

            <SubSection title="Convergence Detection: When to Stop">
              <P>Bead polishing follows numerical optimization convergence patterns:</P>

              <DataTable
                headers={["Phase", "Rounds", "Character"]}
                rows={[
                  ["Major Fixes", "1-3", "Wild swings, fundamental changes"],
                  ["Architecture", "4-7", "Interface improvements, boundary refinements"],
                  ["Refinement", "8-12", "Edge cases, nuanced handling"],
                  ["Polishing", "13+", "Converging to steady state"],
                ]}
              />

              <P>Three signals indicate convergence: agent responses getting shorter (output size shrinking), the rate of change decelerating (change velocity slowing), and successive rounds becoming more similar (content similarity increasing). When the weighted convergence score reaches 0.75+, you&apos;re ready to finalize. Above 0.90, you&apos;re hitting diminishing returns.</P>

              <TipBox variant="warning">
                <strong>Early termination red flags:</strong> If you see <strong>oscillation</strong> (alternating between two versions), reframe the problem. If you see <strong>expansion</strong> (output growing instead of shrinking), step back — the agent is adding complexity. If you see a <strong>plateau at low quality</strong>, kill the current approach and restart fresh.
              </TipBox>
            </SubSection>

            <SubSection title="Fresh Eyes Technique">
              <P>If improvements start to flatline, start a brand new Claude Code session:</P>

              <PromptBlock
                title="Fresh Eyes on Beads"
                prompt={`First read ALL of the AGENTS.md file and README.md file super carefully and understand ALL of both! Then use your code investigation agent mode to fully understand the code, and technical architecture and purpose of the project. Use ultrathink.`}
                where="A brand new Claude Code session"
                whyItWorks="Fresh sessions don't carry the accumulated assumptions of the previous session. They see the beads with genuinely new eyes."
              />

              <P>Then follow up with:</P>

              <PromptBlock
                title="Fresh Review of Beads"
                prompt={`We recently transformed a markdown plan file into a bunch of new beads. I want you to very carefully review and analyze these using \`br\` and \`bv\`. Check over each bead super carefully-- are you sure it makes sense? Is it optimal? Could we change anything to make the system work better for users? If so, revise the beads. It's a lot easier and faster to operate in "plan space" before we start implementing these things! Use ultrathink.`}
                where="Same fresh session, after it finishes reading"
              />

              <P>As a final step, have Codex with GPT (high reasoning effort) do one last round using the same polishing prompt. Different models catch different things.</P>
            </SubSection>

            <SubSection title="Deduplication Check">
              <P>After large bead creation batches, run a dedicated dedup pass:</P>

              <PromptBlock
                title="Bead Deduplication"
                prompt={`Reread AGENTS.md so it's still fresh in your mind. Check over ALL open beads. Make sure none of them are duplicative or excessively overlapping... try to intelligently and cleverly merge them into single canonical beads that best exemplify the strengths of each.`}
                where="Claude Code, after large bead creation batches"
              />
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 5b: IDEA-WIZARD & AD-HOC CHANGES                       */}
          {/* ============================================================= */}
          <GuideSection id="idea-wizard" number="" title="Adding Features to Existing Projects">
            <P>The full planning pipeline (Phases 1-5) is for new projects built from scratch. For existing projects that need new features, the <strong>Idea-Wizard</strong> is a formalized 6-phase pipeline:</P>

            <NumberedList items={[
              <><strong>Ground in reality.</strong> Read AGENTS.md and list all existing beads (<code>br list --json</code>). This prevents creating duplicates.</>,
              <><strong>Generate 30, winnow to 5.</strong> The agent brainstorms 30 ideas for improvements, then self-selects the best 5 with justification.</>,
              <><strong>Expand to 15.</strong> Prompt: &quot;ok and your next best 10 and why.&quot; The agent produces ideas 6-15, checking each against existing beads for novelty.</>,
              <><strong>Human review.</strong> You review the 15 ideas and select which to pursue.</>,
              <><strong>Turn into beads.</strong> Selected ideas become beads with full descriptions, dependencies, and priority levels.</>,
              <><strong>Refine 4-5 times.</strong> The same polishing loop as above. Single-pass beads are never optimal.</>,
            ]} />

            <PromptBlock
              title="Idea-Wizard: Generate Ideas"
              prompt={`Come up with 30 ideas for improvements, enhancements, new features, or fixes for this project. Then winnow to your VERY best 5 and explain why each is valuable.`}
              where="Claude Code, for existing projects needing new features"
            />

            <P>Then: &quot;ok and your next best 10 and why.&quot; The agent produces ideas 6-15, carefully checking each against existing beads for novelty. Having agents brainstorm 30 then winnow to 5 produces much better results than asking for 5 directly because the winnowing forces critical evaluation.</P>

            <P>Not every change needs the full pipeline. For quick, bounded changes, use the built-in TODO system:</P>

            <PromptBlock
              title="Ad-Hoc Execution"
              prompt={`OK, please do ALL of that now. Keep a super detailed, granular, and complete TODO list of all items so you don't lose track of anything and remember to complete all the tasks and sub-tasks you identified or which you think of during the course of your work on these items!`}
              where="When the overhead of formal bead creation would slow you down more than it helps"
              whyItWorks="The TODO list becomes a lightweight execution scaffold that survives compaction. If the task starts expanding or involving multiple agents, that's the signal to convert it into proper beads."
            />
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 6: THE COORDINATION STACK                              */}
          {/* ============================================================= */}
          <GuideSection id="coordination" number="6" title="The Coordination Stack">
            <P>Then you&apos;re ready to start implementing. The fastest way to do that is to start up a big swarm of agents that coordinate using three interlocking tools:</P>

            <CoordinationTrioViz />

            <BlockQuote>Agent Mail + Beads + bv are what unlock the truly insane productivity gains.</BlockQuote>

            <P>Each tool is essential but insufficient alone. <a href="https://github.com/Dicklesworthstone/mcp_agent_mail" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">Agent Mail</a> without beads leaves agents with no structured work to coordinate around. <a href="https://github.com/Dicklesworthstone/beads_rust" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">Beads</a> without bv leaves agents randomly choosing tasks. <a href="https://github.com/Dicklesworthstone/beads_viewer" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">bv</a> without Agent Mail leaves agents unable to communicate. The system is distributed and decentralized, with each agent using bv to find the next optimal bead, marking it as in-progress, and communicating about it via Agent Mail.</P>

            <SubSection title="Agent Mail: Why Naive Coordination Fails">
              <P>Building your own agent coordination from scratch is full of footguns that Agent Mail was designed to sidestep:</P>

              <BulletList items={[
                <><strong>No broadcast-to-all default.</strong> Agents are lazy and will only use broadcast mode, spamming every agent with mostly irrelevant information. It&apos;s like if your email system defaulted to reply-all every time. That burns precious context.</>,
                <><strong>Good MCP ergonomics.</strong> It takes a huge amount of careful iteration to get the API surface right so agents use it reliably without wasting tokens.</>,
                <><strong>No git worktrees.</strong> Worktrees demolish development velocity and create reconciliation debt when agents diverge. Working in one shared space surfaces conflicts immediately. All agents commit directly to <code>main</code>.</>,
                <><strong>Advisory file reservations.</strong> Agents call dibs temporarily on files, but it&apos;s not rigidly enforced, and reservations expire. Agents can reclaim files that haven&apos;t been touched recently. Rigid locks held by dead agents block everyone else. Advisory reservations with TTL expiry degrade gracefully.</>,
                <><strong>Semi-persistent identity.</strong> Agent Mail generates whimsical names like &quot;ScarletCave&quot; and &quot;CoralBadger&quot; — meaningful enough for coordination, disposable enough that losing one doesn&apos;t corrupt the system. No agent&apos;s identity is load-bearing.</>,
              ]} />

              <AgentMailViz />
            </SubSection>

            <SubSection title="bv: The Graph-Theory Compass">
              <BlockQuote>That right answer comes from the dependency structure of the tasks, and this can be mechanically computed using basic graph theory. And that&apos;s what bv does. It&apos;s like a compass that each agent can use to tell them which direction will unlock the most work overall.</BlockQuote>

              <P>bv precomputes dependency metrics (PageRank, betweenness, HITS, eigenvector, critical path, cycle detection) so agents get deterministic, dependency-aware output. When multiple agents each independently query bv for priority, you get <Hl>emergent coordination</Hl>. Agents naturally spread across the optimal work frontier without needing a central coordinator.</P>

              <DataTable
                headers={["Pattern", "Meaning", "Action"]}
                rows={[
                  ["High PageRank + High Betweenness", "Critical bottleneck", "DROP EVERYTHING, fix this first"],
                  ["High PageRank + Low Betweenness", "Foundation piece", "Important but not currently blocking"],
                  ["Low PageRank + High Betweenness", "Unexpected chokepoint", "Investigate why this is a bridge"],
                  ["Low PageRank + Low Betweenness", "Leaf work", "Safe to parallelize freely"],
                ]}
              />

              <P>PageRank finds what everything depends on. Betweenness finds bottlenecks. The math knows your priorities better than gut intuition. Agents just run <code>bv --robot-triage</code> — the mega-command — and get a massive wealth of insights into what to work on next.</P>
            </SubSection>

            <SubSection title="Bead IDs as Threading Anchors">
              <P>Bead IDs create a unified audit trail across all coordination layers: the bead ID goes in the Agent Mail thread_id, the subject prefix (<code>[br-123]</code>), the file reservation reason, and the commit message. This makes all coordination activity traceable back to a single task.</P>
            </SubSection>

            <SubSection title="AGENTS.md: The Operating Manual">
              <P>The AGENTS.md file is the single most critical piece of infrastructure for agent coordination. It tells every agent how to behave, what tools exist, what safety constraints matter, and what &quot;doing a good job&quot; means in this repo. Every tool should come with a prepared blurb designed for inclusion in AGENTS.md. Think of these blurbs as the modern equivalent of man pages.</P>

              <P>Every AGENTS.md should include these core rules:</P>

              <NumberedList items={[
                <><strong>Rule 0, The Override Prerogative:</strong> The human&apos;s instructions override everything.</>,
                <><strong>Rule 1, No File Deletion:</strong> Never delete files without explicit permission.</>,
                <><strong>No destructive git commands:</strong> <code>git reset --hard</code>, <code>git clean -fd</code>, <code>rm -rf</code> are absolutely forbidden.</>,
                <><strong>Branch policy:</strong> All work happens on <code>main</code>, never <code>master</code>.</>,
                <><strong>No script-based code changes:</strong> Always make code changes manually.</>,
                <><strong>No file proliferation:</strong> No <code>mainV2.rs</code> or <code>main_improved.rs</code> variants.</>,
                <><strong>Compiler checks after changes:</strong> Always verify no errors were introduced.</>,
                <><strong>Multi-agent awareness:</strong> Never stash, revert, or overwrite other agents&apos; changes.</>,
              ]} />

              <P>More content in AGENTS.md means more frequent compactions, but it saves time and avoids mistakes by giving agents all the context upfront. This tradeoff is worth making.</P>

              <P>If you don&apos;t have a good AGENTS.md file, none of this stuff is going to work well. You can see example AGENTS.md files for a <a href="https://github.com/Dicklesworthstone/brenner_bot/blob/main/AGENTS.md" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">complex NextJS webapp</a> and a <a href="https://github.com/Dicklesworthstone/repo_updater/blob/main/AGENTS.md" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">bash script project</a>.</P>

              <BlockQuote>After compaction they become like drug-addled children and all bets are off. They need to be forced to read it again or they start acting insane.</BlockQuote>

              <P>&quot;Reread AGENTS.md&quot; is the single most common prompt prefix across the entire session archive. After every context compaction, agents must re-read it:</P>

              <PromptBlock
                title="Post-Compaction Reset"
                prompt={`Reread AGENTS.md so it's still fresh in your mind.`}
                where="Immediately after any context compaction (the single most commonly used prompt)"
                whyItWorks="Compaction wipes out the soft operational knowledge that keeps the swarm sane: how to behave, how to coordinate, what tools exist, what rules matter, what mistakes to avoid. This one-line prompt restores that control plane in one move. It rehydrates the agent's behavioral contract after context loss. Important enough to have been automated with the post_compact_reminder tool."
              />

              <BlockQuote>The main thing that&apos;s dangerous is for them to do a compaction and then not immediately reread AGENTS.md because that file contains their whole marching orders. Suddenly they&apos;re like a bumbling new employee who doesn&apos;t know the ropes at all.</BlockQuote>

              <P>The pragmatic approach: don&apos;t fight compaction, just re-read AGENTS.md and roll with it. When beads are well-constructed, compaction matters less because each bead is self-contained. The agent can pick up any bead fresh without needing the full conversation history.</P>

              <BlockQuote>I used to be a compaction absolutist, but now I just tell them to re-read AGENTS.md and roll with it until they start doing dumb stuff, then start a new session.</BlockQuote>
            </SubSection>

            <SubSection title="Single-Branch Git Model">
              <P>All agents commit directly to <code>main</code>. This may surprise you if you&apos;re used to feature branches. But branch-per-agent creates merge hell with 10+ agents making frequent commits. Worktrees add filesystem complexity and path confusion. Agents lose context when switching branches. And logical conflicts survive textual merges — a function signature change on one branch and a new callsite on another merge cleanly but fail to compile. On a single branch, the second agent sees the signature change immediately and adapts.</P>

              <P>Instead of branch isolation, three complementary mechanisms prevent conflicts: <strong>file reservations</strong> (agents reserve files via Agent Mail before editing; advisory, not rigid, with TTL expiry so dead agents cannot deadlock the system), a <strong>pre-commit guard</strong> (blocks commits to files reserved by another agent), and <strong>DCG</strong> (Destructive Command Guard, which mechanically blocks dangerous commands).</P>

              <TipBox variant="info">
                <strong>DCG origin story:</strong> On December 17, 2025, an agent ran <code>git checkout --</code> on uncommitted work. Files were recovered via <code>git fsck --lost-found</code>, but the incident proved that instructions do not prevent execution. <strong>Mechanical enforcement does.</strong> DCG was built the next day.
              </TipBox>

              <DataTable
                headers={["Blocked Command", "Safe Alternative", "Why"]}
                rows={[
                  ["git reset --hard", "git stash", "Recoverable"],
                  ["git checkout -- file", "git stash push file", "Preserves changes"],
                  ["git push --force", "git push --force-with-lease", "Checks remote unchanged"],
                  ["git clean -fd", "git clean -fdn (preview first)", "Shows what would delete"],
                  ["rm -rf /path", "rm -ri /path", "Interactive confirmation"],
                ]}
              />

              <P><strong>The recommended git workflow:</strong> Pull latest, reserve files, edit and test, commit immediately, push, release reservation. Key principles: commit early and often (small commits reduce the conflict window), push after every commit (unpushed commits are invisible to other agents), reserve before editing, release when done.</P>

              <BlockQuote>You NEVER, under ANY CIRCUMSTANCE, stash, revert, overwrite, or otherwise disturb in ANY way the work of other agents. Just treat those changes identically to changes that you yourself made. Just fool yourself into thinking YOU made the changes and simply don&apos;t recall it for some reason.</BlockQuote>
            </SubSection>

            <SubSection title="Agent Fungibility">
              <P>Every agent is a generalist. No role specialization. All agents read the same AGENTS.md and can pick up any bead. This is deliberately opposed to &quot;specialist agent&quot; architectures where one agent has a special role — specialist agents become bottlenecks. When the specialist crashes or needs compaction, the whole system suffers. With 12 fungible agents, losing one makes almost no difference.</P>

              <P>Think of it like <Hl>RaptorQ fountain codes</Hl>: beads are &quot;blobs&quot; in a stream, any agent catches any bead in any order. There is no &quot;rarest chunk&quot; bottleneck, and the system is resilient to partial agent failures by design. Failure recovery is trivial: the bead remains marked <code>in_progress</code>, any other agent can resume it, and a replacement agent is just <code>ntm add PROJECT --cc=1</code> plus the standard marching orders prompt.</P>

              <BlockQuote>When one agent breaks, it&apos;s not even a problem when all the agents are fungible. Agents become like commodities and can be instantiated and destroyed at will and the only downside is some slowdown and some wasted tokens.</BlockQuote>
            </SubSection>

            <SubSection title="Security Comes Free with Good Planning">
              <P>Security review is baked into the standard workflow at multiple levels rather than being a separate phase. The cross-agent review prompt explicitly calls out security problems. When models reason about an entire system&apos;s architecture at once (which is what the plan enables), they spot authentication gaps, data exposure risks, and trust boundary violations without being told to look. UBS catches security anti-patterns mechanically: unpinned dependencies, missing input validation, hardcoded secrets, supply chain vulnerabilities. Beads that include comprehensive e2e tests naturally cover authentication and authorization paths.</P>

              <P>Security vulnerabilities are usually symptoms of incomplete reasoning about the system. If the plan is detailed enough to cover all user workflows, edge cases, and failure modes, security considerations emerge from that completeness rather than requiring a separate checklist. For projects with explicit security requirements (financial, healthcare), add dedicated security review beads.</P>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 7: LAUNCHING & RUNNING THE SWARM                       */}
          {/* ============================================================= */}
          <GuideSection id="swarm" number="7" title="Launching & Running the Swarm">
            <P>You can create sessions using Claude Code, Codex, and Gemini-CLI in different panes in tmux, or use the <a href="https://github.com/Dicklesworthstone/ntm" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">ntm project</a> (Named Tmux Manager) as the command center:</P>

            <CodeBlock language="bash" code={`# Spawn a multi-agent session
ntm spawn myproject --cc=2 --cod=1 --gmi=1

# Send a prompt to ALL agents
ntm send myproject "Your marching orders prompt here"

# Send to specific agent type
ntm send myproject --cc "Focus on the API layer"

# Open the command palette (battle-tested prompts)
ntm palette`} />

            <P>NTM is useful but not mandatory. WezTerm with one agent per tab is another good setup — trigger common prompts from a Stream Deck, keep a prompt file open in your editor for rarer ones, and use Claude Code&apos;s Ctrl-r prompt history. The method cares that you can launch agents, get prompts into them quickly, and keep the coordination layer intact.</P>

            <P>Give each agent these marching orders:</P>

            <PromptBlock
              title="Swarm Marching Orders"
              prompt={`First read ALL of the AGENTS.md file and README.md file super carefully and understand ALL of both! Then use your code investigation agent mode to fully understand the code, and technical architecture and purpose of the project. Then register with MCP Agent Mail and introduce yourself to the other agents.

Be sure to check your agent mail and to promptly respond if needed to any messages; then proceed meticulously with your next assigned beads, working on the tasks systematically and meticulously and tracking your progress via beads and agent mail messages.

Don't get stuck in "communication purgatory" where nothing is getting done; be proactive about starting tasks that need to be done, but inform your fellow agents via messages when you do so and mark beads appropriately.

When you're not sure what to do next, use the bv tool mentioned in AGENTS.md to prioritize the best beads to work on next; pick the next one that you can usefully work on and get started. Make sure to acknowledge all communication requests from other agents and that you are aware of all active agents and their names. Use ultrathink.`}
              where="Every agent in the swarm gets this as their initial prompt"
              whyItWorks="This is the closest thing to a canonical swarm kickoff packet. It front-loads the shared operating context, forces the agent to establish social presence through Agent Mail, and then pivots away from passive waiting toward execution. The line about 'communication purgatory' matters because swarm failure often comes from over-coordination rather than under-coordination. The prompt establishes a control loop: load rules, understand the codebase, join the coordination layer, claim work, keep state synchronized, and use bv whenever local judgment is insufficient. The prompts are deliberately generic; their vagueness is a feature, letting you reuse them for every project while the agent gets specifics from AGENTS.md and the beads."
            />

            <SubSection title="Agent Composition & Model Recommendations">
              <DataTable
                headers={["Phase", "Recommended Model", "Why"]}
                rows={[
                  ["Initial plan creation", "GPT Pro (web)", "Extended reasoning, all-you-can-eat pricing"],
                  ["Plan synthesis", "GPT Pro (web)", "Best at being the 'final arbiter'"],
                  ["Plan refinement", "GPT Pro + Opus (web)", "Pro reviews, Claude integrates"],
                  ["Plan → Beads conversion", "Claude Code (Opus)", "Best coding agent for structured creation"],
                  ["Bead polishing", "Claude Code (Opus)", "Consistent, thorough"],
                  ["Implementation", "Claude Code + Codex + Gemini", "Diverse swarm"],
                  ["Code review", "Claude Code + Gemini", "Gemini good for review duty"],
                  ["Final verification", "Codex (GPT)", "Different model catches different things"],
                ]}
              />

              <P>Efficiency definitely declines as N grows, but if you have enough tasks in beads and they have Agent Mail and you don&apos;t start them all at the exact same time, you go faster as N grows. The practical limit is around 12 agents on a single project, sometimes higher. Or run 5 agents per project across multiple projects simultaneously.</P>
            </SubSection>

            <SubSection title="The Thundering Herd">
              <P>When you start up like 5 of each kind of agent and have them all collaborate in the same shared workspace, you can hit the classic &quot;thundering herd&quot; problem. The fix: stagger agent starts by 30 seconds minimum, make sure agents mark beads as in-progress quickly, and wait 4 seconds after launch before sending the initial prompt.</P>

              <SwarmExecutionViz />
            </SubSection>

            <SubSection title="What the Human Actually Does">
              <P>The human tends the swarm like an operator tending a machine that mostly runs on its own. These tasks are monitoring and maintenance. The hard cognitive work already happened during planning, which is why you can tend multiple project swarms at the same time.</P>

              <P>On roughly a 10-30 minute cadence:</P>

              <NumberedList items={[
                <><strong>Check bead progress.</strong> Use <code>br list --status in_progress --json</code> or <code>bv --robot-triage</code>. Are agents making steady progress? Are any beads stuck?</>,
                <><strong>Handle compactions.</strong> When you see an agent acting confused, send: &quot;Reread AGENTS.md so it&apos;s still fresh in your mind.&quot; This is the single most common intervention. It takes 5 seconds.</>,
                <><strong>Run periodic reviews.</strong> Pick an agent and send the &quot;fresh eyes&quot; review prompt. This catches bugs before they compound.</>,
                <><strong>Manage rate limits.</strong> When an agent gets rate-limited, switch its account with <code>caam activate claude backup-2</code> or start a new agent.</>,
                <><strong>Commit periodically.</strong> Every 1-2 hours, designate one agent for the organized commit prompt.</>,
                <><strong>Handle surprises.</strong> Create new beads for unanticipated issues, or if it&apos;s plan-level, update the plan and create new beads.</>,
              ]} />

              <BlockQuote>YOU are the bottleneck. Be the clockwork deity to your agent swarms: design a beautiful and intricate machine, set it running, and then move on to the next project. By the time you come back to the first one, you should have huge chunks of work already done and ready.</BlockQuote>

              <TipBox variant="warning">
                <strong>Watch for strategic drift.</strong> A swarm can look productive while heading in the wrong direction — agents generating lots of code and commits while the real goal still feels far away. If that happens, stop and ask: &quot;Where are we on this project? Do we actually have the thing we are trying to build? If we intelligently implement all open beads, would we close that gap completely?&quot; If the answer is no, add or revise beads, re-polish them, and resume with a corrected frontier. Busy agents are not the goal; a bead graph that actually converges on the project goal is the goal.
              </TipBox>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 8: REVIEW, TESTING & HARDENING                         */}
          {/* ============================================================= */}
          <GuideSection id="review" number="8" title="Review, Testing & Hardening">
            <P>If you&apos;ve done a good job creating your beads, the agents will be able to get a decent sized chunk of work done in that first pass. Then, before they start moving to the next bead, have them review all their work:</P>

            <PromptBlock
              title="Fresh Eyes Review"
              prompt={`Great, now I want you to carefully read over all of the new code you just wrote and other existing code you just modified with "fresh eyes" looking super carefully for any obvious bugs, errors, problems, issues, confusion, etc. Carefully fix anything you uncover. Use ultrathink.`}
              where="After each bead is implemented — run until no more bugs are found"
              whyItWorks="This prompt is short because it is not redirecting the agent into a new domain. It is forcing a mode switch from generative coding to adversarial reading. The phrase 'fresh eyes' pushes the model to reframe code it just wrote as something potentially wrong, confusing, or internally inconsistent. That reduces the pattern where an agent stops once code compiles and never performs the low-cost bug sweep that catches obvious issues. The most effective reviews use subagent delegation: dispatch a fresh subagent with no memory of the original implementation to review each changed file."
            />

            <P>Keep running rounds until they stop finding bugs. Typically 1-2 rounds for simple beads, 2-3 for complex ones. If an agent keeps finding bugs after 3 rounds, the implementation approach may be fundamentally off; consider having a different agent take over. From session history, the most effective reviews use <Hl>subagent delegation</Hl>: the parent agent identifies recently changed files via <code>git diff --name-only HEAD~5</code> and dispatches a fresh subagent (with no memory of the original implementation) to review each file. Each review should answer four questions:</P>

            <NumberedList items={[
              <><strong>Is the implementation correct?</strong> Does it do what the bead description says it should?</>,
              <><strong>Are there edge cases?</strong> Empty inputs, concurrent access, error paths, boundary conditions.</>,
              <><strong>Are there similar issues elsewhere?</strong> If you find a bug, search for the same pattern in other files.</>,
              <><strong>Should the approach be different?</strong> Sometimes the implementation is correct but there is a simpler or more robust way.</>,
            ]} />

            <P>When reviews come back clean, have them move on to the next bead:</P>

            <PromptBlock
              title="Advance to Next Bead"
              prompt={`Reread AGENTS.md so it's still fresh in your mind. Use ultrathink. Use bv with the robot flags (see AGENTS.md for info on this) to find the most impactful bead(s) to work on next and then start on it. Remember to mark the beads appropriately and communicate with your fellow agents. Pick the next bead you can actually do usefully now and start coding on it immediately; communicate what you're working on to your fellow agents and mark beads appropriately as you work. And respond to any agent mail messages you've received.`}
              where="After self-review comes back clean"
              whyItWorks="This transition prompt is the glue between beads. It combines re-reading AGENTS.md (for compaction safety), querying bv for priority, and communicating with the swarm. It ensures the agent uses graph-theory routing to choose the task that unblocks the most downstream work, rather than picking arbitrarily."
            />

            <SubSection title="Testing: Free Labor">
              <P>When all your beads are completed, make sure you have solid test coverage:</P>

              <PromptBlock
                title="Test Coverage"
                prompt={`Do we have full unit test coverage without using mocks/fake stuff? What about complete e2e integration test scripts with great, detailed logging? If not, then create a comprehensive and granular set of beads for all this with tasks, subtasks, and dependency structure overlaid with detailed comments. Use ultrathink.`}
                where="After initial implementation pass is complete"
              />

              <BlockQuote>The tests become obsolete and need to be revised as the code changes, which slows down dev velocity. But if all the tests are written and maintained by agents, who cares? Add another couple agents to the swarm and let them deal with updating the tests and running them. It&apos;s free!</BlockQuote>

              <P>Larger projects produce massive test suites. BrennerBot has nearly 5,000 tests. Stuff tends to &quot;just work&quot; in that case. Use UBS (Ultimate Bug Scanner) as a quality gate before every commit: <code>ubs &lt;changed-files&gt;</code> catches errors beyond what linters and type checkers find, including security holes, supply chain vulnerabilities, and runtime stability issues.</P>

              <P>After any substantive code changes, always verify with compiler checks:</P>

              <CodeBlock language="bash" code={`# Rust
cargo check --all-targets
cargo clippy --all-targets -- -D warnings
cargo fmt --check

# Go
go build ./...
go vet ./...

# TypeScript
bun typecheck
bun lint`} />
            </SubSection>

            <SubSection title="UI/UX Polish">
              <P>UI/UX polish is a separate phase that happens after core functionality works. When an agent implements an &quot;authentication&quot; bead, it focuses on making auth work correctly. Whether the login form has good visual hierarchy is an orthogonal concern requiring a different mode of attention.</P>

              <PromptBlock
                title="UI/UX Scrutiny"
                prompt={`Great, now I want you to super carefully scrutinize every aspect of the application workflow and implementation and look for things that just seem sub-optimal or even wrong/mistaken to you, things that could very obviously be improved from a user-friendliness and intuitiveness standpoint, places where our UI/UX could be improved and polished to be slicker, more visually appealing, and more premium feeling and just ultra high quality, like Stripe-level apps. Use ultrathink.`}
                where="After core functionality is working"
              />

              <PromptBlock
                title="Platform-Specific Polish"
                prompt={`I still think there are strong opportunities to enhance the UI/UX look and feel and to make everything work better and be more intuitive, user-friendly, visually appealing, polished, slick, and world class in terms of following UI/UX best practices like those used by Stripe, don't you agree? And I want you to carefully consider desktop UI/UX and mobile UI/UX separately while doing this and hyper-optimize for both separately to play to the specifics of each modality. I'm looking for true world-class visual appeal, polish, slickness, etc. that makes people gasp at how stunning and perfect it is in every way. Use ultrathink.`}
                where="After the scrutiny pass"
                whyItWorks="The 'don't you agree?' phrasing is not politeness. It triggers the model to critically evaluate its own previous work rather than just validating it."
              />
            </SubSection>

            <SubSection title="De-Slopification">
              <P>After agents write documentation (README, user-facing text), run a de-slopify pass to remove telltale AI writing patterns. This must be done manually, not via regex. Read each line and revise systematically:</P>

              <DataTable
                headers={["Pattern", "Problem"]}
                rows={[
                  ["Emdash overuse", "LLMs use emdashes constantly, even when semicolons, commas, or sentence splits work better"],
                  ["\"It's not X, it's Y\"", "Formulaic contrast structure"],
                  ["\"Here's why\" / \"Here's why it matters:\"", "Clickbait-style lead-in"],
                  ["\"Let's dive in\"", "Forced enthusiasm"],
                  ["\"At its core...\"", "Pseudo-profound opener"],
                  ["\"It's worth noting...\"", "Unnecessary hedge"],
                ]}
              />
            </SubSection>

            <SubSection title="Deep Cross-Agent Review">
              <P>Then keep doing rounds of these two prompts until they consistently come back clean with no changes made. These prompts serve different purposes and should be alternated. This is one of the more art-than-science parts of the methodology:</P>

              <PromptBlock
                title="Random Code Exploration"
                prompt={`I want you to sort of randomly explore the code files in this project, choosing code files to deeply investigate and understand and trace their functionality and execution flows through the related code files which they import or which they are imported by.

Once you understand the purpose of the code in the larger context of the workflows, I want you to do a super careful, methodical, and critical check with "fresh eyes" to find any obvious bugs, problems, errors, issues, silly mistakes, etc. and then systematically and meticulously and intelligently correct them.

Be sure to comply with ALL rules in AGENTS.md and ensure that any code you write or revise conforms to the best practice guides referenced in the AGENTS.md file. Use ultrathink.`}
                where="Alternate with the cross-agent review below"
                whyItWorks="The prompt first asks the agent to build a mental model of purpose and flow, then asks for criticism. That ordering matters. A bug hunt without workflow understanding degrades into linting; a bug hunt after tracing execution flows catches logic errors, mismatched assumptions, and silent product-level breakage. The 'randomly explore' framing breaks the locality trap. Directed reviews focus on files that seem important, which are the files that got the most attention already. Bugs that survive to this phase live in utility modules, error handling paths, configuration parsing, and edge-case branches."
              />

              <PromptBlock
                title="Cross-Agent Review"
                prompt={`Ok can you now turn your attention to reviewing the code written by your fellow agents and checking for any issues, bugs, errors, problems, inefficiencies, security problems, reliability issues, etc. and carefully diagnose their underlying root causes using first-principle analysis and then fix or revise them if necessary? Don't restrict yourself to the latest commits, cast a wider net and go super deep! Use ultrathink.`}
                where="Alternate with the random exploration above"
                whyItWorks="This prompt forces the swarm to stop treating code ownership as sacred. A large share of real defects live at the boundaries between agents' changes or in assumptions nobody revisits because they were made by 'someone else.' The instruction not to restrict review to the latest commits prevents shallow PR-style skimming and pushes the agent to trace older surrounding code, dependency surfaces, and adjacent workflows where the real root cause may live. The first-principles wording nudges the reviewer away from symptom-fixing toward actual causal diagnosis."
              />

              <P>The cross-agent prompt tends to induce a suspicious, adversarial stance aimed at boundary failures and root causes in code written by others. The random-exploration prompt tends to induce a curiosity-driven stance aimed at reconstructing workflows and finding latent bugs in code that nobody is actively staring at. These prompts overlap in literal meaning, but they reliably activate different search behaviors in the models.</P>

              <P><strong>How to run deep bug hunting:</strong> Send the random exploration prompt to 2-3 agents simultaneously — each will explore different parts of the codebase because the randomness ensures variety. After they report back, send the cross-agent review prompt. Alternate until agents consistently come back with &quot;I reviewed X, Y, Z files and found no issues.&quot; When two consecutive rounds both come back clean, the codebase is in good shape. If agents keep finding bugs after 4+ rounds, go back to bead space and create specific fix beads. Always run <code>ubs .</code> on the full project first and fix everything it flags before letting agents hunt for subtler issues.</P>
            </SubSection>

            <SubSection title="Organized Commits">
              <P>Periodically have one agent handle git operations:</P>

              <PromptBlock
                title="Organized Commits"
                prompt={`Now, based on your knowledge of the project, commit all changed files now in a series of logically connected groupings with super detailed commit messages for each and then push. Take your time to do it right. Don't edit the code at all. Don't commit obviously ephemeral files. Use ultrathink.`}
                where="Every 1-2 hours during active development"
                whyItWorks="Designating one agent prevents merge conflicts and produces coherent commit messages. Small, frequent commits reduce the window for conflicts and make all agents' work visible to each other."
              />
            </SubSection>

            <SubSection title="Swarm Diagnosis: Reality Check">
              <P>When the swarm looks active but you suspect it is not closing the real gap to the goal:</P>

              <PromptBlock
                title="High-Level Reality Check"
                prompt={`Where are we on this project? Do we actually have the thing we are trying to build? If not, what is blocking us? If we intelligently implement all open and in-progress beads, would we close that gap completely? Why or why not?`}
                where="When the swarm feels busy but directionally off"
                whyItWorks="This prompt breaks the spell of local productivity. Instead of asking whether the current bead is going well, it asks whether the current frontier of work actually converges on the project outcome. If the agent concludes that finishing all open beads still would not get you there, the answer is not 'work harder.' The answer is to revise the bead graph and re-aim the swarm."
              />
            </SubSection>

            <SubSection title="README Revision">
              <PromptBlock
                title="README Reviser"
                prompt={`OK, we have made tons of recent changes that aren't yet reflected in the README file. First, reread AGENTS.md so it's still fresh in your mind. Now, we need to revise the README for these changes (don't write about them as "changes" however, make it read like it was always like that, since we don't have any users yet!). Also, what else can we put in there to make the README longer and more detailed about what we built, why it's useful, how it works, the algorithms/design principles used, etc? This should be incremental NEW content, not replacement for what is there already.`}
                where="After significant implementation work"
              />
            </SubSection>

            <SubSection title="Catch-All Oversight">
              <PromptBlock
                title="Quick Final Sanity Check"
                prompt={`Great. Look over everything again for any obvious oversights or omissions or mistakes, conceptual errors, blunders, etc.`}
                where="After any significant change, as a quick final pass"
              />
            </SubSection>

            <SubSection title="The De-Slopify Prompt">
              <PromptBlock
                title="De-Slopify Documentation"
                prompt={`I want you to read through the complete text carefully and look for any telltale signs of "AI slop" style writing; one big tell is the use of emdash. You should try to replace this with a semicolon, a comma, or just recast the sentence accordingly so it sounds good while avoiding emdash.

Also, you want to avoid certain telltale writing tropes, like sentences of the form "It's not [just] XYZ, it's ABC" or "Here's why" or "Here's why it matters:". Basically, anything that sounds like the kind of thing an LLM would write disproportionately more commonly than a human writer and which sounds inauthentic/cringe.

And you can't do this sort of thing using regex or a script, you MUST manually read each line of the text and revise it manually in a systematic, methodical, diligent way.`}
                where="After agents write README or any user-facing documentation"
              />
            </SubSection>

            <SubSection title="Landing the Plane">
              <P>When ending a work session, agents must complete every step. Work is NOT complete until <code>git push</code> succeeds. Unpushed work is stranded locally and invisible to every other agent.</P>

              <NumberedList items={[
                <><strong>File issues for remaining work.</strong> Create beads for anything that needs follow-up.</>,
                <><strong>Run quality gates.</strong> Tests, linters, builds (if code changed).</>,
                <><strong>Update issue status.</strong> Close finished work, update in-progress items.</>,
                <><strong>Sync beads.</strong> <code>br sync --flush-only</code> to export to JSONL, then <code>git add .beads/</code>.</>,
                <><strong>Commit and push.</strong> <code>git pull --rebase &amp;&amp; git add &lt;files&gt; &amp;&amp; git commit &amp;&amp; git push</code>.</>,
                <><strong>Verify.</strong> <code>git status</code> must show &quot;up to date with origin.&quot;</>,
              ]} />

              <P>For the Atlas Notes example, &quot;done for now&quot; would not mean &quot;the upload page appears.&quot; It would mean: the upload, parse, search, and admin-review workflows all work end to end; the key beads are closed and remaining polish ideas exist as new beads; tests cover the critical user journeys and known failure paths; UBS and compiler/lint checks are clean; commits and pushes are complete; and the next session can restart from beads, AGENTS.md, and Agent Mail threads rather than from human memory.</P>

              <P>A Flywheel session is only landable when a future swarm can pick it back up without the human re-explaining the project from scratch.</P>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 9: THE COMPLETE TOOLCHAIN                              */}
          {/* ============================================================= */}
          <GuideSection id="toolchain" number="9" title="The Complete Toolchain">
            <P>The Flywheel is supported by a stack of 11 purpose-built tools, all free and open-source:</P>

            <DataTable
              headers={["Tool", "Command", "Purpose"]}
              rows={[
                ["NTM", "ntm", "Named Tmux Manager — agent cockpit for spawning, sending, and broadcasting"],
                ["Agent Mail", "am", "Agent coordination — identities, inbox/outbox, file reservations"],
                ["UBS", "ubs", "Ultimate Bug Scanner — 1000+ patterns, pre-commit guardrails"],
                ["Beads", "br", "Issue tracking — dependency-aware, JSONL+SQLite hybrid"],
                ["Beads Viewer", "bv", "Triage engine — PageRank, betweenness, HITS, robot mode"],
                ["RCH", "rch", "Remote build offloading — keeps heavy CPU work off the swarm box"],
                ["CASS", "cass", "Session search — unified agent history indexing"],
                ["CASS Memory", "cm", "Procedural memory — episodic → working → procedural"],
                ["CAAM", "caam", "Auth switching — sub-100ms account swap across providers"],
                ["DCG", "dcg", "Safety guard — blocks destructive git/filesystem operations mechanically"],
                ["SLB", "slb", "Two-person rule — optional guardrails for dangerous commands"],
              ]}
            />

            <P>Not every tool is used the same way. <code>br</code>, <code>bv</code>, <code>ubs</code>, and <code>rch</code> are ordinary shell commands. Agent Mail is primarily experienced through MCP tools and macros. The installer (<a href="https://agent-flywheel.com" target="_blank" rel="noopener noreferrer" className="text-[#FF5500] hover:text-[#FFBD2E] underline underline-offset-4 decoration-[#FF5500]/30 hover:decoration-[#FFBD2E]/50 transition-colors">agent-flywheel.com</a>) installs all of them with a single <code>curl|bash</code> command.</P>

            <SubSection title="The Flywheel Interactions">
              <P>The complete interaction flow from spawn to memory:</P>

              <CodeBlock language="text" code={`NTM spawns agents --> Agents read AGENTS.md
                  --> Agents register with Agent Mail
                  --> Agents query bv for task priority
                  --> Agents claim beads via br
                  --> Agents reserve files via Agent Mail
                  --> Agents implement and test
                  --> UBS scans for bugs
                  --> Agents commit and push
                  --> CASS indexes the session
                  --> CM distills procedural memory
                  --> Next cycle is better`} />
            </SubSection>

            <SubSection title="The VPS Environment">
              <DataTable
                headers={["Aspect", "Value"]}
                rows={[
                  ["User", "ubuntu"],
                  ["Shell", "zsh (with oh-my-zsh + powerlevel10k)"],
                  ["Workspace", "/data/projects"],
                  ["Sudo", "Passwordless (vibe mode)"],
                  ["Tmux prefix", "Ctrl-a"],
                ]}
              />

              <P>Use <code>acfs newproj</code> to bootstrap a project with full tooling:</P>

              <CodeBlock language="bash" code={`acfs newproj myproject --interactive

# Creates:
# myproject/
# ├── .git/        # Git repository initialized
# ├── .beads/      # Local issue tracking (br)
# ├── .claude/     # Claude Code settings
# ├── AGENTS.md    # Instructions for AI agents
# └── .gitignore   # Standard ignores`} />
            </SubSection>

            <SubSection title="The Incremental Onboarding Path">
              <P>For beginners who find the full system overwhelming:</P>

              <NumberedList items={[
                <><strong>Start with:</strong> Agent Mail + Beads (br) + Beads Viewer (bv) — this core trio captures most of the value</>,
                <><strong>Then add:</strong> UBS for bug hunting</>,
                <><strong>Then add:</strong> DCG for destructive command protection</>,
                <><strong>Then add:</strong> CASS for session history</>,
                <><strong>Then add:</strong> CM (CASS Memory) for codifying lessons into procedural memory</>,
              ]} />

              <TipBox variant="warning">
                <strong>Common beginner mistakes:</strong> Making a hasty plan all at once instead of the multi-model iterative process. Trying to convert the plan to beads in a single pass. Not doing at least 3 rounds of polishing. &quot;Well, of course the project is going to suck and be a buggy mess if you do that.&quot;
              </TipBox>
            </SubSection>

            <SubSection title="Scale Observations from Real Projects">
              <DataTable
                headers={["Project", "Beads", "Plan Lines", "Agents", "Time to MVP"]}
                rows={[
                  ["CASS Memory System", "347+", "5,500", "~25", "~5 hours"],
                  ["FrankenSQLite", "Hundreds", "Large spec", "Many parallel", "Multi-session"],
                  ["Frankensearch", "122+ (3 epics)", "—", "Multiple", "Multi-session"],
                  ["Apollobot", "26", "—", "Single session", "2-3 polish rounds"],
                ]}
              />
            </SubSection>

            <SubSection title="Patterns That Work">
              <BulletList items={[
                <><strong>The &quot;30 to 5 to 15&quot; funnel:</strong> When generating ideas, having agents brainstorm 30 then winnow to 5 produces much better results than asking for 5 directly. The winnowing forces critical evaluation.</>,
                <><strong>Parallel subagents for bulk bead operations:</strong> Creating dozens of beads is faster when dispatched to parallel subagents, each handling a subset.</>,
                <><strong>Staggered agent starts:</strong> Starting agents 30-60 seconds apart avoids the thundering herd problem.</>,
                <><strong>One agent for git operations:</strong> Designating one agent to handle all commits prevents merge conflicts and produces coherent commit messages.</>,
              ]} />
            </SubSection>

            <SubSection title="Anti-Patterns to Avoid">
              <BulletList items={[
                <><strong>Single-pass beads:</strong> First-draft beads are never optimal. Always do 4-5 polishing passes minimum.</>,
                <><strong>Skipping plan-to-bead validation:</strong> Not cross-referencing beads against the plan leads to missing features discovered only during implementation.</>,
                <><strong>Communication purgatory:</strong> Agents spending more time messaging each other than coding. Be proactive about starting work.</>,
                <><strong>Holding reservations too long:</strong> File reservations with long TTLs block other agents unnecessarily. Reserve, edit, commit, release.</>,
                <><strong>Not re-reading AGENTS.md after compaction:</strong> Context compaction loses nuances. The re-read is mandatory, not optional.</>,
              ]} />
            </SubSection>

            <SubSection title="Supporting Infrastructure">
              <DataTable
                headers={["Component", "Purpose"]}
                rows={[
                  ["AGENTS.md", "Per-project configuration teaching agents about tools and rules"],
                  ["Best practices guides", "Referenced in AGENTS.md, kept current"],
                  ["Markdown plan files", "Source-of-truth planning documents"],
                  ["acfs newproj", "Bootstraps projects with full tooling (.git, .beads, .claude, AGENTS.md)"],
                  ["acfs doctor", "Single command to verify entire installation"],
                  ["NTM command palette", "Battle-tested prompt library accessible via ntm palette"],
                  ["Claude Code Skills", "Each tool has a dedicated skill for automated workflows"],
                ]}
              />
            </SubSection>

            <SubSection title="The Skills Ecosystem">
              <P>A skill is a reusable operational instruction pack for an agent. In Claude Code terms, that usually means a SKILL.md file plus optional references, scripts, or templates that tell the agent how to use a tool, how to execute a methodology, what pitfalls to avoid, and what a good result looks like. A good skill is closer to executable know-how than to ordinary prose documentation.</P>

              <P>A tool changes what the agent <em>can</em> do. A skill changes how <em>well</em> the agent knows how to do it. The same model with and without a good skill often behaves like two different agents. Every Flywheel tool has a corresponding Claude Code skill that encodes best practices and automates common workflows. Many are bundled directly in the tool repos and get installed automatically.</P>
            </SubSection>

            <SubSection title="Vendor Lock-In: Avoid It">
              <BlockQuote>PSA: you should avoid vendor lock-in for agent coding primitives like task management (e.g., beads) and agent communication (e.g., MCP Agent Mail) so you can use all the agents together, which is more powerful anyway. They want you in a walled garden, but it&apos;s 100% unnecessary.</BlockQuote>

              <P>Beads, Agent Mail, and bv are all CLI tools that work identically regardless of which agent invokes them. A Claude Code agent and a Codex agent and a Gemini agent can all call <code>br ready --json</code> and get the same task list. The practical test: could you swap out every Claude Code agent for Codex or Gemini without changing your AGENTS.md, beads, Agent Mail setup, or workflow? If yes, you&apos;re vendor-neutral.</P>
            </SubSection>

            <SubSection title="Validation Gates">
              <P>These gates turn the methodology into a contract. If a gate fails, drop back a phase instead of pushing forward optimistically.</P>

              <DataTable
                headers={["Gate", "Must Be True Before Advancing"]}
                rows={[
                  ["Foundation", "Goals, workflows, stack, architecture direction, AGENTS.md, and best-practices guides exist and are coherent"],
                  ["Plan", "Markdown plan covers workflows, architecture, sequencing, constraints, testing expectations, and major failure paths"],
                  ["Translation", "Every material plan element maps to one or more beads, checked in both directions"],
                  ["Bead", "Beads are self-contained, dependency-correct, rich in context, and explicit about test obligations"],
                  ["Launch", "Agent Mail, file reservations, bead IDs, bv, AGENTS.md, and staggered startup are all ready"],
                  ["Ship", "Reviews, tests, UBS, remaining-work beads, and feedback capture into reusable artifacts are complete"],
                ]}
              />
            </SubSection>

            <SubSection title="Vibe Mode Aliases">
              <P>On the VPS, agents run with full permissions via short aliases:</P>

              <CodeBlock language="bash" code={`alias cc='NODE_OPTIONS="--max-old-space-size=32768" claude --dangerously-skip-permissions'
alias cod='codex --dangerously-bypass-approvals-and-sandbox'
alias gmi='gemini --yolo'`} />

              <P>These are configured automatically by the installer. DCG provides the safety net that makes this viable.</P>
            </SubSection>

            <SubSection title="Cost">
              <P>~$500/month for Claude Max and GPT Pro subscriptions (at minimum), plus ~$50/month for a cloud server (OVH, Contabo). Multiple Max accounts may be needed for large swarms; CAAM enables instant switching when hitting rate limits. At scale, token usage for a single intensive session can reach ~20M input tokens and ~3.5M output tokens.</P>
            </SubSection>
          </GuideSection>

          <Divider />

          {/* ============================================================= */}
          {/* SECTION 10: THE FLYWHEEL EFFECT                                */}
          {/* ============================================================= */}
          <GuideSection id="flywheel" number="10" title="The Flywheel Effect">
            <P highlight>If you simply use these tools, workflows, and prompts in the way just described, you can create really incredible software in just a couple days, sometimes in just one day. I&apos;ve done it a bunch of times now and it really does work, as crazy as that may sound. You see my GitHub profile for the proof of this. It looks like the output from a team of 100+ developers.</P>

            <P>It behaves like a flywheel rather than a checklist because each cycle makes the next one better:</P>

            <BulletList items={[
              <><strong>Planning quality compounds</strong> because you keep reusing prompts, patterns, and reasoning structures that CASS proves actually worked.</>,
              <><strong>Execution quality compounds</strong> because better beads make swarm behavior more deterministic and less dependent on human improvisation.</>,
              <><strong>Tool quality compounds</strong> because agents use the tools, complain about them, and then help improve them.</>,
              <><strong>Memory compounds</strong> because the results of one swarm, captured by CASS session search, become training data, rituals, and infrastructure for the next one.</>,
            ]} />

            <SubSection title="How the Compounding Actually Works">
              <P>Each session makes the next one better. Concretely: <strong>Session N produces raw data</strong> — CASS automatically logs every agent session. <strong>Between sessions, CM distills patterns</strong> — running <code>cm reflect</code> extracts procedural rules like &quot;always run cargo check after modifying Cargo.toml&quot; with confidence scores that decay without reinforcement and amplify with repetition. <strong>Session N+1 starts with those patterns loaded</strong> — running <code>cm context &quot;Building an API&quot;</code> retrieves relevant procedural memory. Simultaneously, UBS patterns grow as new bug classes get added. Agent Mail coordination norms get refined in AGENTS.md and skills.</P>

              <P>The compounding is real but not automatic in the early stages. You have to actually run <code>cm reflect</code>, actually review CASS session data, actually update AGENTS.md with lessons learned. But even manually, spending 15 minutes between projects reviewing what worked and updating your AGENTS.md template produces outsized returns on every subsequent project.</P>
            </SubSection>

            <SubSection title="Agent Feedback Forms">
              <P>Apply the same feedback mechanisms you would use for humans (structured surveys, satisfaction ratings, net promoter scores) directly to agents evaluating tools. After an agent finishes using a tool in a real project, ask it to fill out a structured feedback survey. Then pipe that feedback directly into another agent working on the tool itself. The iteration cycle collapses from weeks to minutes.</P>

              <PromptBlock
                title="Agent Tool Feedback"
                prompt={`Based on your experience with [TOOL] today in this project, how would you rate [TOOL] across multiple dimensions, from 0 (worst) to 100 (best)? Was it helpful to you? Did it flag a lot of useful things that you would have missed otherwise? Did the issues it flagged have a good signal-to-noise ratio? What did it do well, and what was it bad at? Did you run into any errors or problems while using it?

What changes to [TOOL] would make it work even better for you and be more useful in your development workflow? Would you recommend it to fellow coding agents? How strongly, and why or why not? The more specific you can be, and the more dimensions you can score [TOOL] on, the more helpful it will be for me as I improve it and incorporate your feedback to make [TOOL] even better for you in the future!`}
                where="After an agent finishes using a tool in a real project"
                whyItWorks="Many of the same concepts we use for people are directly applicable to agents. 'By robots, for robots.' This produces structured, actionable feedback. When used across multiple agents on different project types, you get a diverse sample of experiences."
              />
            </SubSection>

            <SubSection title="CASS Memory: Three-Layer Architecture">
              <P>CM (CASS Memory System) implements a three-layer memory architecture that turns raw session history into operational knowledge:</P>

              <CodeBlock language="text" code={`EPISODIC MEMORY (cass): Raw session logs from all agents
         ↓ cass search
WORKING MEMORY (Diary): Structured session summaries
         ↓ reflect + curate
PROCEDURAL MEMORY (Playbook): Distilled rules with confidence scores`} />

              <P>Rules have a 90-day confidence half-life (decays without feedback) and a 4x harmful multiplier (one mistake counts 4x as much as one success). Rules mature through stages: <code>candidate</code> to <code>established</code> to <code>proven</code>.</P>

              <CodeBlock language="bash" code={`cm context "Building an API" --json   # Get relevant memories for a task
cm recall "authentication patterns"   # Search past sessions
cm reflect                            # Update procedural memory from recent sessions
cm mark b-8f3a2c --helpful            # Reinforce a useful rule
cm mark b-xyz789 --harmful --reason "Caused regression"  # Flag a bad rule`} />

              <P>The <code>cm context</code> command is the single most important pre-task ritual. Running it at the start of a session gives agents knowledge distilled from every previous session that touched similar work.</P>
            </SubSection>

            <SubSection title="Meta-Skill: Skill Refinement via CASS Mining">
              <PromptBlock
                title="Skill Refinement Meta-Skill"
                prompt={`Search CASS for all sessions where agents used the [SKILL] skill. Look for: patterns of confusion, repeated mistakes, steps agents skipped, workarounds they invented, and things they did that weren't in the skill but should be.

Then rewrite the skill to fix every issue you found. Make the happy path obvious, add guardrails for the common mistakes, and incorporate the best workarounds as official steps. Test the rewritten skill against the failure cases from the session logs.`}
                where="Claude Code, targeting any skill with 10+ CASS sessions of usage data"
                whyItWorks="This is the meta-skill pattern in action. The skill-refiner skill itself can be refined using its own session data, which is the self-referential property that makes the whole system accelerate. After 3-4 cycles, the skill is dramatically more reliable than the original. Each cycle takes less human effort because the meta-skill itself has improved."
              />
            </SubSection>

            <SubSection title="CASS Ritual Detection">
              <P>The flywheel&apos;s learning loop depends on mining past sessions to find what actually works. CASS enables <Hl>ritual detection</Hl>: discovering prompts that are repeated so frequently they constitute validated methodology.</P>

              <DataTable
                headers={["Repetition Count", "Status", "Action"]}
                rows={[
                  ["count >= 10", "RITUAL", "Validated methodology. Extract into a skill."],
                  ["count 5-9", "Emerging pattern", "Worth investigating further."],
                  ["count < 5", "One-off", "Not generalizable yet."],
                ]}
              />

              <P>This is how the prompt library in this guide was originally discovered. It was not invented top-down; it was mined bottom-up from hundreds of real sessions.</P>
            </SubSection>

            <SubSection title="The Kernel: 9 Invariants">
              <NumberedList items={[
                <><strong>Global reasoning belongs in plan space.</strong> Do the hardest architectural and product reasoning while the whole project still fits in context.</>,
                <><strong>The markdown plan must be comprehensive before coding starts.</strong> Skeleton-first coding throws away the main advantage of frontier models.</>,
                <><strong>Plan-to-beads is a distinct translation problem.</strong> A good plan does not automatically produce a good bead graph.</>,
                <><strong>Beads are the execution substrate.</strong> Once good enough, they should carry enough context that agents no longer need the full plan.</>,
                <><strong>Convergence matters more than first drafts.</strong> Plans and beads both improve through repeated polishing until changes become small and corrective.</>,
                <><strong>Swarm agents are fungible.</strong> Coordination must live in artifacts and tools, not in special agents or unstated knowledge.</>,
                <><strong>Coordination must survive crashes and compaction.</strong> AGENTS.md, Agent Mail, bead state, and robot modes exist to keep work moving when sessions die.</>,
                <><strong>Session history is part of the system.</strong> Repeated prompts, failures, and recoveries should be mined via CASS and folded back into tools, skills, and validators.</>,
                <><strong>Implementation is not the finish line.</strong> Review, testing, UBS, and feedback-to-infrastructure loops are part of the core method.</>,
              ]} />
            </SubSection>

            <SubSection title="Time Investment">
              <DataTable
                headers={["Phase", "Typical Duration", "Notes"]}
                rows={[
                  ["Planning (multi-model synthesis + refinement)", "3+ hours for a complex feature", "Feels slow because no code is written, but the downstream payoff is enormous"],
                  ["Plan to beads conversion", "Significant; Claude needed 'coaxing and cajoling' for 347 beads", "A 5,500-line plan with hundreds of beads takes sustained effort"],
                  ["Bead polishing", "2-3 passes per session, multiple sessions", "Agents typically manage 2-3 passes before running out of context window"],
                  ["Implementation with swarm", "Remarkably fast", "CASS Memory System: 11k lines in ~5 hours with 25 agents"],
                ]}
              />

              <P>CASS itself (a complex Rust program used by thousands of people) was made in around a week, but the human personally only spent a few hours on it. The rest of the time was spent by a swarm of agents implementing and polishing it and writing tests.</P>
            </SubSection>

            <SubSection title="V1 Is Not Everything">
              <P>A common misconception is that you have to do everything in one shot. In this approach, that&apos;s true only for version 1. Once you have a functioning v1, adding new features follows the same process: create a super detailed markdown plan for the new feature, turn it into beads, and implement. The same process that creates the initial version also handles all subsequent iterations.</P>
            </SubSection>

            <SubSection title="Tools Must Be Agent-First">
              <BlockQuote>Every new dev tool in the year of our lord 2025 should have a robot mode designed specifically for agents to use. And it should probably be designed by agents, too. And then you iterate based on the feedback of the agents actually using the tool in real-world scenarios.</BlockQuote>

              <P>Every tool ships with a prepared AGENTS.md blurb. The tool is not complete without documentation that agents can consume. But it goes further: the tools themselves should be designed by agents, for agents, with iterative feedback. If agents do not like the tools, they will not use them without constant nagging.</P>

              <BlockQuote>I make sure the agents enjoy using them and solicit their feedback to improve the tooling. If they don&apos;t like the tools, they won&apos;t use them without constant nagging.</BlockQuote>
            </SubSection>

            <SubSection title="Skills Improving Skills">
              <P>The truly powerful thing is that the flywheel improves <em>itself</em>. Using skills to improve skills, skills to improve tool use, and then feeding the actual experience in the form of session logs (surfaced and searched by CASS) back into the design skill for improving the tool interface to make it more natural and intuitive and powerful for the agents. Then taking that revised tool and improving the skill for using that tool. Rinse and repeat.</P>

              <P>Every tool in the stack was built using the same methodology it now supports. When you improve the extreme-optimization skill, every future optimization pass across every tool benefits. When you improve the idea-wizard skill, every future brainstorming session across every project benefits. The improvements multiply rather than add. That is the flywheel effect in its purest form.</P>
            </SubSection>

            <SubSection title="The Hidden Knowledge Extraction">
              <P>Models have internalized vast amounts of academic CS literature: obscure algorithmic techniques, mathematical proofs, design patterns from papers that only a handful of people ever read. Most of this knowledge never surfaces because nobody asks for it with enough precision. Skills are the mechanism for asking the right questions.</P>

              <P>Without a skill, &quot;optimize this function&quot; gets you generic improvements. With an extreme-optimization skill, the model systematically considers cache-oblivious data structures, SIMD vectorization, branch-free arithmetic, van Emde Boas layout, and benchmarks before and after each change. The skill acts as a key that unlocks specific rooms in the model&apos;s knowledge base.</P>

              <BlockQuote>The knowledge is just sitting there and the models have it. But you need to know how to coax it out of them.</BlockQuote>

              <P>Stack enough cycles and the result is code that looks like it was written by someone who read every obscure CS paper ever published. In a functional sense, it was. The agent served as a lens focusing decades of dispersed academic knowledge onto a single practical target. The skill was the lens prescription.</P>
            </SubSection>

            <SubSection title="Getting Started">
              <P>The complete system is free and 100% open-source. A beginner with a credit card and a laptop can visit the wizard, follow step-by-step instructions to rent a VPS, paste one <code>curl|bash</code> command, type <code>onboard</code>, and start building with AI agents immediately.</P>

              <CodeBlock language="bash" code={`# 1. Rent a VPS (OVH or Contabo, ~$40-56/month, Ubuntu)
# 2. SSH in and run the one-liner
curl -fsSL https://agent-flywheel.com/install.sh | bash

# 3. Reconnect, then learn the workflow
onboard

# 4. Create your first project
acfs newproj my-first-project --interactive

# 5. Spawn agents and start building
ntm spawn my-first-project --cc=2 --cod=1 --gmi=1`} />

              <P>You don&apos;t even need to know much at all about computers; you just need the desire to learn and some grit and determination. And about $500/month for the subscriptions, plus another $50 or so for the cloud server.</P>

              <P highlight>If you want to change the entire direction of your life, it has truly never been easier. If you think you might want to do it, I really recommend just immersing yourself.</P>
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
    <section className="relative overflow-hidden pt-32 pb-20 md:pt-48 md:pb-32 bg-[#020408] border-b border-white/[0.04]">
      <div className="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-[0.03] mix-blend-overlay pointer-events-none" />
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-[600px] bg-[radial-gradient(ellipse_at_top,rgba(255,85,0,0.08),transparent_70%)]" />

      <div className="relative mx-auto text-center px-6 z-10 max-w-5xl">
        <div className="inline-flex items-center gap-3 rounded-full border border-[#FF5500]/20 bg-[#FF5500]/5 px-6 py-2 text-[0.7rem] font-black uppercase tracking-[0.3em] text-[#FF5500] mb-10 shadow-[0_0_20px_rgba(255,85,0,0.15)] backdrop-blur-xl">
          <Sparkles className="h-4 w-4" />
          The Official Methodology
        </div>

        <h1 className="text-5xl sm:text-6xl md:text-8xl font-black text-white tracking-tighter drop-shadow-2xl leading-[1.05]">
          The Agentic Coding <br/><span className="text-[#FF5500]">Flywheel</span>
        </h1>

        <p className="mx-auto mt-10 max-w-3xl text-xl sm:text-2xl text-zinc-400 leading-relaxed font-light">
          A comprehensive guide to creating extraordinary software by orchestrating swarms of AI agents using <Hl>exhaustive markdown plans</Hl>, <Hl>polished beads</Hl>, and the <Hl>Agent Flywheel stack</Hl>. Based on the methodology of Jeffrey Emanuel.
        </p>
      </div>
    </section>
  );
}

// =============================================================================
// FOOTER CTA
// =============================================================================
function FooterCTA() {
  return (
    <section className="relative overflow-hidden rounded-[3rem] border border-[#FF5500]/20 bg-[#0A0D14] py-24 md:py-32 my-32 shadow-[0_50px_100px_-20px_rgba(255,85,0,0.15)] group">
      <div className="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-[0.03] mix-blend-overlay pointer-events-none" />
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-full bg-[radial-gradient(ellipse_at_center,rgba(255,85,0,0.05),transparent_70%)] opacity-0 group-hover:opacity-100 transition-opacity duration-1000" />

      <div className="relative mx-auto text-center px-6 z-10">
        <div className="inline-flex items-center gap-3 rounded-full border border-[#FF5500]/30 bg-[#FF5500]/10 px-6 py-2 text-[0.7rem] font-black uppercase tracking-[0.3em] text-[#FF5500] mb-10 shadow-inner">
          <Rocket className="h-4 w-4" />
          Ready to Start?
        </div>

        <h2 className="text-4xl sm:text-5xl md:text-6xl font-black text-white tracking-tighter drop-shadow-2xl">
          Get the Flywheel <span className="text-[#FF5500]">Stack</span>
        </h2>

        <p className="mx-auto mt-8 max-w-2xl text-lg text-zinc-400 leading-relaxed font-light">
          One command installs all 11 tools, three AI coding agents, and the complete environment.
          <br/><strong>30 minutes to fully configured.</strong>
        </p>

        <div className="mt-12 flex justify-center">
          <a
            href="/wizard/os-selection"
            className="inline-flex items-center justify-center rounded-2xl bg-[#FF5500] px-8 py-4 text-sm font-black text-black uppercase tracking-widest transition-all hover:bg-[#FFBD2E] hover:shadow-[0_0_40px_rgba(255,189,46,0.4)] hover:-translate-y-1 active:scale-95"
          >
            Launch the Setup Wizard
          </a>
        </div>
      </div>
    </section>
  );
}
