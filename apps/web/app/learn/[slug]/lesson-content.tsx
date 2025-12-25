"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, useCallback } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import rehypeHighlight from "rehype-highlight";
import {
  ArrowLeft,
  ArrowRight,
  BookOpen,
  Check,
  ChevronLeft,
  ChevronRight,
  Clock,
  GraduationCap,
  Home,
  Keyboard,
  Terminal,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import {
  type Lesson,
  LESSONS,
  getNextLesson,
  getPreviousLesson,
  useCompletedLessons,
} from "@/lib/lessonProgress";
import {
  getStepBySlug,
  TOTAL_STEPS as TOTAL_WIZARD_STEPS,
  useCompletedSteps,
} from "@/lib/wizardSteps";
import {
  useConfetti,
  getCompletionMessage,
  CompletionToast,
  FinalCelebrationModal,
} from "@/components/learn/confetti-celebration";

interface Props {
  lesson: Lesson;
  content: string;
}

// Hook for reading progress (scroll percentage)
function useReadingProgress() {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const updateProgress = () => {
      const scrollTop = window.scrollY;
      const docHeight = document.documentElement.scrollHeight - window.innerHeight;
      const scrollPercent = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0;
      setProgress(Math.min(100, Math.max(0, scrollPercent)));
    };

    window.addEventListener("scroll", updateProgress, { passive: true });
    updateProgress(); // Initial call
    return () => window.removeEventListener("scroll", updateProgress);
  }, []);

  return progress;
}

// Reading progress bar component
function ReadingProgressBar({ progress }: { progress: number }) {
  return (
    <div className="fixed left-0 right-0 top-0 z-50 h-1 bg-muted/30">
      <div
        className="h-full bg-gradient-to-r from-primary to-[oklch(0.75_0.18_195)] transition-all duration-150 ease-out"
        style={{ width: `${progress}%` }}
      />
    </div>
  );
}

function LessonSidebar({
  currentLessonId,
  completedLessons,
}: {
  currentLessonId: number;
  completedLessons: number[];
}) {
  return (
    <aside className="sticky top-0 hidden h-screen w-72 shrink-0 overflow-y-auto border-r border-border/50 bg-gradient-to-b from-sidebar/90 via-sidebar/70 to-sidebar/90 backdrop-blur-md lg:block">
      <div className="flex h-full flex-col">
        {/* Header */}
        <div className="flex items-center gap-3 border-b border-border/50 px-6 py-5">
          <Link
            href="/learn"
            className="flex items-center gap-2 transition-opacity hover:opacity-80"
          >
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/20">
              <GraduationCap className="h-4 w-4 text-primary" />
            </div>
            <span className="font-mono text-sm font-bold tracking-tight">
              Learning Hub
            </span>
          </Link>
        </div>

        {/* Lesson list */}
        <nav className="flex-1 px-4 py-4">
          <ul className="space-y-1">
            {LESSONS.map((lesson) => {
              const isCompleted = completedLessons.includes(lesson.id);
              const isCurrent = lesson.id === currentLessonId;

              return (
                <li key={lesson.id}>
                  <Link
                    href={`/learn/${lesson.slug}`}
                    className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-all duration-200 ${
                      isCurrent
                        ? "bg-primary/15 text-primary shadow-[0_0_20px_-5px] shadow-primary/30"
                        : "text-muted-foreground hover:bg-muted/80 hover:text-foreground"
                    }`}
                  >
                    <div
                      className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-mono ${
                        isCompleted
                          ? "bg-[oklch(0.72_0.19_145)] text-white"
                          : isCurrent
                            ? "bg-primary text-primary-foreground"
                            : "bg-muted text-muted-foreground"
                      }`}
                    >
                      {isCompleted ? (
                        <Check className="h-3 w-3" />
                      ) : (
                        lesson.id + 1
                      )}
                    </div>
                    <span className="line-clamp-1">{lesson.title}</span>
                  </Link>
                </li>
              );
            })}
          </ul>
        </nav>

        {/* Footer */}
        <div className="border-t border-border/50 p-4 space-y-2">
          <Button
            asChild
            variant="ghost"
            size="sm"
            className="w-full justify-start text-muted-foreground hover:text-foreground"
          >
            <Link href="/">
              <Home className="mr-2 h-4 w-4" />
              Back to Home
            </Link>
          </Button>
          <div className="flex items-center justify-center gap-1.5 text-[10px] text-muted-foreground/60">
            <Keyboard className="h-3 w-3" />
            <span>Press ? for shortcuts</span>
          </div>
        </div>
      </div>
    </aside>
  );
}

export function LessonContent({ lesson, content }: Props) {
  const router = useRouter();
  const [completedLessons, markComplete] = useCompletedLessons();
  const [completedSteps] = useCompletedSteps();
  const readingProgress = useReadingProgress();
  const isCompleted = completedLessons.includes(lesson.id);
  const prevLesson = getPreviousLesson(lesson.id);
  const nextLesson = getNextLesson(lesson.id);
  const isWizardComplete = completedSteps.length === TOTAL_WIZARD_STEPS;
  const [showKeyboardHint, setShowKeyboardHint] = useState(false);
  const [showToast, setShowToast] = useState(false);
  const [toastMessage, setToastMessage] = useState("");
  const [showFinalCelebration, setShowFinalCelebration] = useState(false);
  const { celebrate } = useConfetti();

  const wizardStepSlugByLesson: Record<string, string> = {
    welcome: "launch-onboarding",
    "ssh-basics": "ssh-connect",
    "agent-commands": "accounts",
  };
  const wizardStepSlug = wizardStepSlugByLesson[lesson.slug] ?? "os-selection";
  const wizardStep = getStepBySlug(wizardStepSlug);
  const wizardStepTitle = wizardStep?.title ?? "Setup Wizard";

  const handleMarkComplete = useCallback(() => {
    // Don't re-celebrate if already completed
    if (isCompleted) {
      if (nextLesson) {
        router.push(`/learn/${nextLesson.slug}`);
      }
      return;
    }

    markComplete(lesson.id);
    const isFinalLesson = !nextLesson;

    // Fire confetti
    celebrate(isFinalLesson);

    // Show toast with encouraging message
    setToastMessage(getCompletionMessage(isFinalLesson));
    setShowToast(true);

    // Hide toast after 2.5 seconds
    setTimeout(() => setShowToast(false), 2500);

    if (isFinalLesson) {
      // Show celebration modal for final lesson
      setTimeout(() => setShowFinalCelebration(true), 500);
    } else {
      // Auto-advance to next lesson after brief delay
      setTimeout(() => {
        router.push(`/learn/${nextLesson.slug}`);
      }, 1500);
    }
  }, [lesson.id, markComplete, nextLesson, router, celebrate, isCompleted]);

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Ignore if user is typing in an input
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return;
      }

      // If the keyboard shortcuts overlay is open, treat any key press as "close"
      // to match the UI text and prevent accidental navigation.
      if (showKeyboardHint) {
        setShowKeyboardHint(false);
        return;
      }

      switch (e.key) {
        case "ArrowLeft":
        case "h": // vim-style
          if (prevLesson) {
            router.push(`/learn/${prevLesson.slug}`);
          }
          break;
        case "ArrowRight":
        case "l": // vim-style
          if (nextLesson) {
            router.push(`/learn/${nextLesson.slug}`);
          }
          break;
        case "c":
          if (!isCompleted) {
            handleMarkComplete();
          }
          break;
        case "?":
          setShowKeyboardHint(prev => !prev);
          break;
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [prevLesson, nextLesson, isCompleted, handleMarkComplete, router, showKeyboardHint]);

  return (
    <div className="relative min-h-screen bg-background">
      {/* Reading progress bar */}
      <ReadingProgressBar progress={readingProgress} />

      {/* Keyboard shortcuts hint (press ? to toggle) */}
      {showKeyboardHint && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-background/80 backdrop-blur-sm">
          <div className="mx-4 rounded-2xl border border-border/50 bg-card/95 p-6 shadow-xl">
            <div className="mb-4 flex items-center gap-2 text-primary">
              <Keyboard className="h-5 w-5" />
              <h3 className="font-mono font-bold">Keyboard Shortcuts</h3>
            </div>
            <div className="space-y-3 text-sm">
              <div className="flex justify-between gap-8">
                <span className="text-muted-foreground">Previous lesson</span>
                <span className="font-mono text-foreground">← or h</span>
              </div>
              <div className="flex justify-between gap-8">
                <span className="text-muted-foreground">Next lesson</span>
                <span className="font-mono text-foreground">→ or l</span>
              </div>
              <div className="flex justify-between gap-8">
                <span className="text-muted-foreground">Mark complete</span>
                <span className="font-mono text-foreground">c</span>
              </div>
              <div className="flex justify-between gap-8">
                <span className="text-muted-foreground">Toggle this help</span>
                <span className="font-mono text-foreground">?</span>
              </div>
            </div>
            <button
              onClick={() => setShowKeyboardHint(false)}
              className="mt-4 w-full rounded-lg bg-primary/10 py-2 text-sm text-primary transition-colors hover:bg-primary/20"
            >
              Press any key to close
            </button>
          </div>
        </div>
      )}

      {/* Background effects */}
      <div className="pointer-events-none fixed inset-0 bg-gradient-cosmic opacity-50" />
      <div className="pointer-events-none fixed inset-0 bg-grid-pattern opacity-20" />

      {/* Celebration components */}
      <CompletionToast message={toastMessage} isVisible={showToast} />
      <FinalCelebrationModal
        isOpen={showFinalCelebration}
        onClose={() => setShowFinalCelebration(false)}
        onGoToDashboard={() => {
          setShowFinalCelebration(false);
          router.push("/learn");
        }}
      />

      <div className="relative flex">
        {/* Desktop sidebar */}
        <LessonSidebar
          currentLessonId={lesson.id}
          completedLessons={completedLessons}
        />

        {/* Main content */}
        <main className="flex-1 pb-32 lg:pb-8">
          {/* Mobile header */}
          <div className="sticky top-0 z-20 flex items-center justify-between border-b border-border/50 bg-background/80 px-4 py-3 backdrop-blur-sm lg:hidden">
            <Link
              href="/learn"
              className="flex items-center gap-2 text-muted-foreground"
            >
              <ArrowLeft className="h-4 w-4" />
              <span className="text-sm">All Lessons</span>
            </Link>
            <div className="text-xs text-muted-foreground">
              <span className="font-mono text-primary">{lesson.id + 1}</span> of{" "}
              {LESSONS.length}
            </div>
          </div>

          {/* Content area */}
          <div className="px-6 py-8 md:px-12 md:py-12">
            <div className="mx-auto max-w-2xl">
              {/* Lesson header */}
              <div className="mb-8">
                <div className="mb-4 flex items-center gap-4 text-sm text-muted-foreground">
                  <span className="flex items-center gap-1">
                    <BookOpen className="h-4 w-4" />
                    Lesson {lesson.id + 1}
                  </span>
                  <span className="flex items-center gap-1">
                    <Clock className="h-4 w-4" />
                    {lesson.duration}
                  </span>
                  {isCompleted && (
                    <span className="flex items-center gap-1 text-[oklch(0.72_0.19_145)]">
                      <Check className="h-4 w-4" />
                      Completed
                    </span>
                  )}
                </div>
                <h1 className="text-3xl font-bold tracking-tight">
                  {lesson.title}
                </h1>
                <p className="mt-2 text-lg text-muted-foreground">
                  {lesson.description}
                </p>
              </div>

              {!isWizardComplete && (
                <Card className="mb-8 border-amber-500/30 bg-amber-500/10 p-4">
                  <div className="flex items-start gap-3 text-sm">
                    <Terminal className="mt-0.5 h-4 w-4 text-amber-500" />
                    <div className="space-y-1">
                      <p className="font-medium text-foreground">
                        Not set up yet?
                      </p>
                      <p className="text-muted-foreground">
                        Complete the setup wizard first to get the most out of this lesson.
                      </p>
                      <Link
                        href={`/wizard/${wizardStepSlug}`}
                        className="inline-flex items-center gap-1 text-primary hover:underline"
                      >
                        Go to {wizardStepTitle} →
                      </Link>
                    </div>
                  </div>
                </Card>
              )}

              {/* Markdown content - premium typography */}
              {/* Note: headings are demoted by 1 level (h1->h2, h2->h3, etc.) since lesson.title is the page h1 */}
              <article className="prose prose-invert max-w-none prose-headings:font-bold prose-headings:tracking-tight prose-h1:text-2xl prose-h1:mb-6 prose-h2:mt-10 prose-h2:mb-4 prose-h2:text-xl prose-h3:mt-8 prose-h3:mb-3 prose-h3:text-lg prose-p:text-muted-foreground prose-p:leading-relaxed prose-p:mb-5 prose-a:text-primary prose-a:no-underline hover:prose-a:underline prose-code:rounded prose-code:bg-muted prose-code:px-1.5 prose-code:py-0.5 prose-code:font-mono prose-code:text-sm prose-code:before:content-none prose-code:after:content-none prose-pre:rounded-xl prose-pre:border prose-pre:border-border/50 prose-pre:bg-muted/50 prose-pre:my-6 prose-li:text-muted-foreground prose-li:leading-relaxed prose-ul:my-4 prose-ol:my-4 prose-blockquote:border-l-primary/50 prose-blockquote:bg-primary/5 prose-blockquote:py-1 prose-blockquote:px-4 prose-blockquote:rounded-r-lg prose-blockquote:italic">
                <ReactMarkdown
                  remarkPlugins={[remarkGfm]}
                  rehypePlugins={[rehypeHighlight]}
                  components={{
                    // Demote all headings by 1 level since lesson.title is the page h1
                    h1: ({ children, ...props }) => <h2 {...props}>{children}</h2>,
                    h2: ({ children, ...props }) => <h3 {...props}>{children}</h3>,
                    h3: ({ children, ...props }) => <h4 {...props}>{children}</h4>,
                    h4: ({ children, ...props }) => <h5 {...props}>{children}</h5>,
                    h5: ({ children, ...props }) => <h6 {...props}>{children}</h6>,
                    h6: ({ children, ...props }) => <h6 {...props}>{children}</h6>,
                  }}
                >
                  {content}
                </ReactMarkdown>
              </article>

              {/* Mark complete button */}
              <Card className="mt-12 border-primary/20 bg-primary/5 p-6">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <h3 className="font-semibold">
                      {isCompleted ? "Lesson completed!" : "Finished this lesson?"}
                    </h3>
                    <p className="text-sm text-muted-foreground">
                      {isCompleted
                        ? nextLesson
                          ? "Ready to move on to the next one?"
                          : "You've completed all lessons!"
                        : "Mark it complete to track your progress."}
                    </p>
                  </div>
                  <Button
                    onClick={handleMarkComplete}
                    disabled={isCompleted && !nextLesson}
                    className={
                      isCompleted
                        ? "bg-[oklch(0.72_0.19_145)] hover:bg-[oklch(0.65_0.19_145)]"
                        : ""
                    }
                  >
                    {isCompleted ? (
                      nextLesson ? (
                        <>
                          Next Lesson
                          <ArrowRight className="ml-1 h-4 w-4" />
                        </>
                      ) : (
                        <>
                          <Check className="mr-1 h-4 w-4" />
                          All Done!
                        </>
                      )
                    ) : (
                      <>
                        <Check className="mr-1 h-4 w-4" />
                        Mark Complete
                      </>
                    )}
                  </Button>
                </div>
              </Card>

              {/* Navigation (desktop) */}
              <div className="mt-8 hidden items-center justify-between lg:flex">
                {prevLesson ? (
                  <Button variant="ghost" asChild>
                    <Link href={`/learn/${prevLesson.slug}`}>
                      <ChevronLeft className="mr-1 h-4 w-4" />
                      {prevLesson.title}
                    </Link>
                  </Button>
                ) : (
                  <div />
                )}
                {nextLesson && (
                  <Button asChild>
                    <Link href={`/learn/${nextLesson.slug}`}>
                      {nextLesson.title}
                      <ChevronRight className="ml-1 h-4 w-4" />
                    </Link>
                  </Button>
                )}
              </div>
            </div>
          </div>
        </main>
      </div>

      {/* Mobile navigation - prev | complete | next */}
      <div className="fixed inset-x-0 bottom-0 z-30 border-t border-border/50 bg-background/95 p-4 backdrop-blur-md lg:hidden">
        <div className="flex items-center gap-2">
          {/* Previous button */}
          <Button
            variant="outline"
            size="icon"
            className="h-12 w-12 shrink-0"
            disabled={!prevLesson}
            asChild={!!prevLesson}
          >
            {prevLesson ? (
              <Link href={`/learn/${prevLesson.slug}`} aria-label="Previous lesson">
                <ChevronLeft className="h-5 w-5" />
              </Link>
            ) : (
              <ChevronLeft className="h-5 w-5" />
            )}
          </Button>

          {/* Mark Complete button - prominent in center */}
          <Button
            className={`h-12 flex-1 font-medium ${
              isCompleted
                ? "bg-[oklch(0.72_0.19_145)] hover:bg-[oklch(0.65_0.19_145)]"
                : "bg-primary hover:bg-primary/90"
            }`}
            onClick={handleMarkComplete}
            disabled={isCompleted && !nextLesson}
          >
            {isCompleted ? (
              nextLesson ? (
                <>
                  Next Lesson
                  <ArrowRight className="ml-1 h-4 w-4" />
                </>
              ) : (
                <>
                  <Check className="mr-1 h-4 w-4" />
                  All Done!
                </>
              )
            ) : (
              <>
                <Check className="mr-1 h-4 w-4" />
                Mark Complete
              </>
            )}
          </Button>

          {/* Next button */}
          <Button
            variant="outline"
            size="icon"
            className="h-12 w-12 shrink-0"
            disabled={!nextLesson}
            asChild={!!nextLesson}
          >
            {nextLesson ? (
              <Link href={`/learn/${nextLesson.slug}`} aria-label="Next lesson">
                <ChevronRight className="h-5 w-5" />
              </Link>
            ) : (
              <ChevronRight className="h-5 w-5" />
            )}
          </Button>
        </div>
      </div>
    </div>
  );
}
