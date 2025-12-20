'use client';

import Script from 'next/script';
import { useEffect } from 'react';
import { usePathname } from 'next/navigation';
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';

// Environment variables for third-party services
// Note: GA4 is handled by AnalyticsProvider to avoid duplicate scripts
const GTM_ID = process.env.NEXT_PUBLIC_GTM_ID;
const CLARITY_PROJECT_ID = process.env.NEXT_PUBLIC_CLARITY_PROJECT_ID;

/**
 * Third-party scripts manager (non-GA4)
 * Handles: GTM, Microsoft Clarity, Vercel Analytics
 * Note: GA4 is loaded by AnalyticsProvider for comprehensive tracking
 */
export function ThirdPartyScripts() {
  const pathname = usePathname();

  // Track virtual pageviews for GTM on SPA navigation
  useEffect(() => {
    if (GTM_ID && window.dataLayer) {
      window.dataLayer.push({
        event: 'virtual_pageview',
        page_path: pathname,
        page_title: document.title,
      });
    }
  }, [pathname]);

  return (
    <>
      {/* Google Tag Manager - for advanced tag management */}
      {GTM_ID && (
        <Script
          id="gtm-script"
          strategy="afterInteractive"
          dangerouslySetInnerHTML={{
            __html: `
              (function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
              new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
              j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
              'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
              })(window,document,'script','dataLayer','${GTM_ID}');
            `,
          }}
        />
      )}

      {/* Microsoft Clarity - Free heatmaps & session recording (invisible) */}
      {CLARITY_PROJECT_ID && (
        <Script
          id="clarity-script"
          strategy="afterInteractive"
          dangerouslySetInnerHTML={{
            __html: `
              (function(c,l,a,r,i,t,y){
                c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
                t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
                y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
              })(window, document, "clarity", "script", "${CLARITY_PROJECT_ID}");
            `,
          }}
        />
      )}

      {/* Vercel Web Analytics - automatic pageview & event tracking */}
      <Analytics />

      {/* Vercel Speed Insights - Core Web Vitals monitoring */}
      <SpeedInsights />
    </>
  );
}

export default ThirdPartyScripts;
