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
          
          <GuideSection id="intro" number="1" title="The Complete Workflow">
            <P highlight>If you have a markdown plan for a new piece of software that you&apos;re getting ready to start implementing with a coding agent such as Claude Code, before starting the actual implementation work, give this a try.</P>
            
            <FlywheelDiagram />

            <P>Paste your entire markdown plan into the ChatGPT 5.2 Pro web app with extended reasoning enabled and use this prompt; when it&apos;s done, paste the complete output from GPT Pro into Claude Code or Codex and tell it to revise the existing plan file in-place using the feedback:</P>
            
            <PromptBlock
              title="Plan Refinement Prompt"
              prompt={`Carefully review this entire plan for me and come up with your best revisions in terms of better architecture, new features, changed features, etc. to make it better, more robust/reliable, more performant, more compelling/useful, etc.

For each proposed change, give me your detailed analysis and rationale/justification for why it would make the project better along with the git-diff style changes relative to the original markdown plan shown below:

<PASTE YOUR EXISTING COMPLETE PLAN HERE>`}
            />

            <P>This has never failed to improve a plan significantly for me. The best part is that you can start a fresh conversation in ChatGPT and do it all again once Claude Code or Codex finishes integrating your last batch of suggested revisions.</P>
            
            <P>After four or five rounds of this, you tend to reach a steady-state where the suggestions become very incremental.</P>

            <ContextHorizonViz />
            
            <BlockQuote>The point of the markdown plan is that you can fit the entire thing in the context window and have models reason about it globally.</BlockQuote>
            
            <SubSection title="Best-of-All-Worlds Synthesis">
              <P>You don&apos;t even need to write the initial markdown plan yourself. You can write that with GPT Pro, just explaining what it is you want to make. I usually also specify the tech stack I want to use (e.g., Typescript, Nextjs 16, React 19, Tailwind, Supabase, Rust/WASM).</P>
              <P>I ask 3 competing LLMs to do the exact same thing and they come up with pretty different plans. Then I show their plans to GPT 5.2 Pro with a prompt like this:</P>
              
              <PromptBlock
                title="Multi-Model Synthesis Prompt"
                prompt={`I asked 3 competing LLMs to do the exact same thing and they came up with pretty different plans which you can read below. I want you to REALLY carefully analyze their plans with an open mind and be intellectually honest about what they did that's better than your plan. Then I want you to come up with the best possible revisions to your plan... that artfully and skillfully blends the 'best of all worlds' to create a true, ultimate, superior hybrid version...`}
              />
              
              <PlanEvolutionStudio />
              
              <P>Different frontier models have different &quot;tastes&quot; and blind spots. Passing a plan through a gauntlet of different models is the cheapest way to buy architectural robustness.</P>
            </SubSection>
          </GuideSection>

          <Divider />

          <GuideSection id="beads" number="2" title="Check Your Beads N Times, Implement Once">
            <P>Before you burn up a lot of tokens with a big agent swarm on a new project, the old woodworking maxim of &quot;Measure twice, cut once!&quot; is worth revising as <strong>&quot;Check your beads N times, implement once,&quot;</strong> where N is basically as many as you can stomach.</P>
            
            <P>Then you&apos;re ready to turn the plan into beads (think of these as epics/tasks/subtasks and associated dependency structure. The name comes from Steve Yegge&apos;s amazing project), which I do with this prompt using Claude Code with Opus 4.5:</P>
            
            <PromptBlock
              title="Plan to Beads Prompt"
              prompt={`OK so please take ALL of that and elaborate on it more and then create a comprehensive and granular set of beads for all this with tasks, subtasks, and dependency structure overlaid, with detailed comments so that the whole thing is totally self-contained and self-documenting (including relevant background, reasoning/justification, considerations, etc.-- anything we&apos;d want our "future self" to know about the goals and intentions and thought process and how it serves the over-arching goals of the project.) Use only the bd tool to create and modify the beads and add the dependencies. Use ultrathink.`}
            />

            <PlanToBeadsViz />

            <P>After it finishes all of that, I then do a round of this prompt (if CC did a compaction at any point, be sure to tell it to re-read your AGENTS.md file):</P>
            
            <PromptBlock
              title="Bead Checking Prompt"
              prompt={`Check over each bead super carefully-- are you sure it makes sense? Is it optimal? Could we change anything to make the system work better for users? If so, revise the beads. It's a lot easier and faster to operate in "plan space" before we start implementing these things! Use ultrathink.`}
            />
            
            <ConvergenceViz />

            <P>I&apos;ve found that you continue to get more and more improvements, even if they&apos;re subtle, the more times you run this in a row with Opus 4.5. I experimented recently with running it 6+ times, and it kept making useful refinements.</P>
            <P>Just remember: planning tokens are a lot fewer and cheaper than implementation tokens. Even a very big, complex markdown plan is shorter than a few substantive code files, let alone a whole project.</P>
          </GuideSection>

          <Divider />

          <GuideSection id="swarm" number="3" title="Swarm Execution & Agent Mail">
            <P>Then you&apos;re ready to start implementing. The fastest way to do that is to start up a big swarm of agents that coordinate using my MCP Agent Mail project.</P>
            
            <P>Then you can simply create a bunch of sessions using Claude Code, Codex, and Gemini-CLI in different windows or panes in tmux (or use my ntm project) and give them the following as their marching orders:</P>
            
            <PromptBlock
              title="Agent Marching Orders"
              prompt={`First read ALL of the AGENTS.md file and README.md file super carefully and understand ALL of both! Then use your code investigation agent mode to fully understand the code, and technical architecture and purpose of the project. Then register with MCP Agent Mail and introduce yourself to the other agents.\n\nBe sure to check your agent mail and to promptly respond if needed to any messages; then proceed meticulously with your next assigned beads, working on the tasks systematically and meticulously and tracking your progress via beads and agent mail messages.\n\nDon't get stuck in "communication purgatory" where nothing is getting done; be proactive about starting tasks that need to be done, but inform your fellow agents via messages when you do so and mark beads appropriately.\n\nWhen you're not sure what to do next, use the bv tool mentioned in AGENTS.md to prioritize the best beads to work on next; pick the next one that you can usefully work on and get started. Make sure to acknowledge all communication requests from other agents and that you are aware of all active agents and their names. Use ultrathink.`}
            />

            <CoordinationTrioViz />
            <AgentMailViz />

            <SubSection title="The Thundering Herd">
              <P>When you start up like 5 of each kind of agent and have them all collaborate in the same shared workspace, you can hit the classic &quot;thundering herd&quot; problem.</P>
              <P>Usually addressed with retry with exponential backoff and jitter, but in this case marking the beads quickly and staggered start is the best.</P>
              
              <SwarmExecutionViz />
              
              <BlockQuote>YOU are the bottleneck. Be the clockwork deity to your agent swarms: design a beautiful and intricate machine, set it running, and then move on to the next project.</BlockQuote>
            </SubSection>
          </GuideSection>

          <Divider />

          <GuideSection id="review" number="4" title="Deep Review & De-slopification">
            <P>If you&apos;ve done a good job creating your beads, the agents will be able to get a decent sized chunk of work done in that first pass. Then, before they start moving to the next bead, I have them review all their work:</P>
            
            <PromptBlock
              title="Fresh Eyes Review"
              prompt={`Great, now I want you to carefully read over all of the new code you just wrote and other existing code you just modified with &quot;fresh eyes&quot; looking super carefully for any obvious bugs, errors, problems, issues, confusion, etc. Carefully fix anything you uncover. Use ultrathink.`}
            />

            <RepresentationLadder />

            <P>When all your beads are completed, you might want to run one of these prompts to polish the UX:</P>

            <PromptBlock
              title="UI/UX Polish"
              prompt={`I still think there are strong opportunities to enhance the UI/UX look and feel and to make everything work better and be more intuitive, user-friendly, visually appealing, polished, slick, and world class in terms of following UI/UX best practices like those used by Stripe, don&apos;t you agree? And I want you to carefully consider desktop UI/UX and mobile UI/UX separately while doing this and hyper-optimize for both separately to play to the specifics of each modality. I&apos;m looking for true world-class visual appeal, polish, slickness, etc. that makes people gasp at how stunning and perfect it is in every way. Use ultrathink.`}
            />

            <P>And then keep doing rounds of deep cross-agent review until they consistently come back clean with no changes made:</P>
            
            <PromptBlock
              title="Deep Cross-Agent Analysis"
              prompt={`Ok can you now turn your attention to reviewing the code written by your fellow agents and checking for any issues, bugs, errors, problems, inefficiencies, security problems, reliability issues, etc. and carefully diagnose their underlying root causes using first-principle analysis and then fix or revise them if necessary? Don't restrict yourself to the latest commits, cast a wider net and go super deep! Use ultrathink.`}
            />
          </GuideSection>

          <Divider />

          <GuideSection id="knuth" number="5" title="The Knuth Post & Recursive Self-Improvement">
            <SubSection title="Skills Improving Skills">
              <P>
                I&apos;m living this every day, and let me tell you, things are accelerating very rapidly indeed.
              </P>
              <P>
                Using skills to improve skills, skills to improve tool use, and then feeding the actual experience in the form of session logs (surfaced and searched by my cass tool and /cass skill) back into the design skill for improving the tool interface to make it more natural and intuitive and powerful for the agents. Then taking that revised tool and improving the skill for using that tool, then rinse and repeat.
              </P>
            </SubSection>

            <SubSection title="Extreme Optimization & Alien Artifacts">
              <P>
                And finding any way I can to squeeze out more token density and agent intuitiveness and ergonomics wherever I can, like porting toon to Rust and seeing how I can add it as an optional output format to every tool&apos;s robot mode.
              </P>
              <P>
                Meanwhile, I&apos;m going over each tool with my extreme optimization skill and applying insane algorithmic lore that Knuth himself probably forgot about already to make things as fast as the metal can go in memory-safe Rust.
              </P>
              <P highlight>
                Now I&apos;m applying this to much bigger and richer targets, not just making small tools for use by agents, but now complex, rich protocols like my Flywheel Connector Protocol, which is practically an alien artifact (same for my process_triage or pt tool, which could cover a dozen PhD theses worth of applied probability), in that it weaves together so many innovative and clever ideas.
              </P>
            </SubSection>

            <SubSection title="Building the Core Infrastructure">
              <P>
                And now I&apos;m even starting to build up my own core infrastructure for Rust. Just because certain libraries and ecosystems like Tokio have all the mindshare, doesn&apos;t mean they&apos;re the best, or even particularly good.
              </P>
              <BlockQuote>
                Design by committee over 10+ years while the language evolves is not a recipe for excellence.
              </BlockQuote>
              <P>
                But people are content to defer to the experts and then they end up with flawed structured concurrency primitives that forgo all the correctness by design that the academics already solved.
              </P>
              <P>
                For instance, check out my asupersync library, which I&apos;m already using to replace all the networking in my other rust tools, for a glimpse at this new clean-room, alien-artifact library future based on all that CS academic research that only a dozen people in the world ever read about.
              </P>
              <P highlight>
                The knowledge is just sitting there and the models have it. But you need to know how to coax it out of them.
              </P>
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
      {/* High-end ambient effects */}
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
          A comprehensive guide to orchestrating swarms of AI agents using <Hl>markdown plans</Hl>, <Hl>beads</Hl>, and the <Hl>ACFS stack</Hl>. Based directly on the writings of Jeffrey Emanuel.
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
