'use client';

import { useEffect, useCallback, useRef } from 'react';
import { usePathname, useSearchParams } from 'next/navigation';
import Script from 'next/script';
import {
  GA_MEASUREMENT_ID,
  trackSessionStart,
  trackPagePerformance,
  trackScrollDepth,
  trackTimeOnPage,
  getOrCreateUserId,
  setUserProperties,
  sendEvent,
} from '@/lib/analytics';

interface AnalyticsProviderProps {
  children: React.ReactNode;
}

/**
 * Analytics Provider Component
 * Handles GA4 initialization, pageview tracking, and engagement metrics
 */
export function AnalyticsProvider({ children }: AnalyticsProviderProps) {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const scrollDepthsReached = useRef<Set<number>>(new Set());
  const pageStartTime = useRef<number>(0);
  const timeIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Track page views on route change
  useEffect(() => {
    if (!GA_MEASUREMENT_ID) return;

    const url = pathname + (searchParams?.toString() ? `?${searchParams.toString()}` : '');

    // Reset tracking for new page
    scrollDepthsReached.current.clear();
    pageStartTime.current = Date.now();

    // Track pageview
    window.gtag?.('config', GA_MEASUREMENT_ID, {
      page_path: url,
      page_title: document.title,
    });

    // Track page performance after load
    if (document.readyState === 'complete') {
      trackPagePerformance();
    } else {
      window.addEventListener('load', trackPagePerformance, { once: true });
    }

    return () => {
      window.removeEventListener('load', trackPagePerformance);
    };
  }, [pathname, searchParams]);

  // Initialize session tracking on mount
  useEffect(() => {
    if (!GA_MEASUREMENT_ID) return;

    // Get or create user ID
    const userId = getOrCreateUserId();

    // Set user ID for cross-session tracking
    setUserProperties({
      user_id: userId,
      first_visit_date: localStorage.getItem('acfs_first_visit') || new Date().toISOString(),
    });

    // Store first visit date
    if (!localStorage.getItem('acfs_first_visit')) {
      localStorage.setItem('acfs_first_visit', new Date().toISOString());
    }

    // Track enhanced session start
    trackSessionStart();

    // Track returning vs new user
    const visitCount = parseInt(localStorage.getItem('acfs_visit_count') || '0', 10) + 1;
    localStorage.setItem('acfs_visit_count', visitCount.toString());

    setUserProperties({
      visit_count: visitCount,
      is_returning_user: visitCount > 1,
    });
  }, []);

  // Scroll depth tracking
  const handleScroll = useCallback(() => {
    if (!GA_MEASUREMENT_ID) return;

    const scrollTop = window.scrollY;
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;
    const scrollPercent = docHeight > 0 ? Math.round((scrollTop / docHeight) * 100) : 0;

    const milestones = [25, 50, 75, 90, 100] as const;

    for (const milestone of milestones) {
      if (scrollPercent >= milestone && !scrollDepthsReached.current.has(milestone)) {
        scrollDepthsReached.current.add(milestone);
        trackScrollDepth(milestone, pathname);
      }
    }
  }, [pathname]);

  // Set up scroll tracking
  useEffect(() => {
    if (!GA_MEASUREMENT_ID) return;

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, [handleScroll]);

  // Time on page tracking
  useEffect(() => {
    if (!GA_MEASUREMENT_ID) return;

    const timeCheckpoints = [30, 60, 120, 300, 600]; // seconds
    let lastCheckpoint = 0;

    timeIntervalRef.current = setInterval(() => {
      const elapsed = Math.floor((Date.now() - pageStartTime.current) / 1000);

      for (const checkpoint of timeCheckpoints) {
        if (elapsed >= checkpoint && lastCheckpoint < checkpoint) {
          trackTimeOnPage(checkpoint, pathname);
          lastCheckpoint = checkpoint;
        }
      }
    }, 5000); // Check every 5 seconds

    return () => {
      if (timeIntervalRef.current) {
        clearInterval(timeIntervalRef.current);
      }
    };
  }, [pathname]);

  // Track visibility changes (tab switching)
  useEffect(() => {
    if (!GA_MEASUREMENT_ID) return;

    const handleVisibilityChange = () => {
      if (document.hidden) {
        const timeSpent = Math.floor((Date.now() - pageStartTime.current) / 1000);
        sendEvent('page_hidden', {
          page_path: pathname,
          time_spent_seconds: timeSpent,
        });
      } else {
        sendEvent('page_visible', {
          page_path: pathname,
        });
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [pathname]);

  // Track page exit
  useEffect(() => {
    if (!GA_MEASUREMENT_ID) return;

    const handleBeforeUnload = () => {
      const timeSpent = Math.floor((Date.now() - pageStartTime.current) / 1000);

      // Use GA4 gtag with beacon transport (Measurement Protocol api_secret cannot
      // be safely used client-side).
      sendEvent('page_exit', {
        page_path: pathname,
        time_spent_seconds: timeSpent,
        scroll_depths_reached: Array.from(scrollDepthsReached.current),
        transport_type: 'beacon',
      });
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [pathname]);

  if (!GA_MEASUREMENT_ID) {
    return <>{children}</>;
  }

  return (
    <>
      {/* Google Analytics Script */}
      <Script
        src={`https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`}
        strategy="afterInteractive"
      />
      <Script id="google-analytics" strategy="afterInteractive">
        {`
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '${GA_MEASUREMENT_ID}', {
            page_path: window.location.pathname,
            cookie_flags: 'SameSite=None;Secure',
            send_page_view: true,
            allow_google_signals: true,
            allow_ad_personalization_signals: false,
            // Custom dimensions for user segmentation
            custom_map: {
              'dimension1': 'user_type',
              'dimension2': 'wizard_step',
              'dimension3': 'selected_os',
              'dimension4': 'vps_provider',
              'dimension5': 'terminal_app',
            }
          });
        `}
      </Script>
      {children}
    </>
  );
}

export default AnalyticsProvider;
