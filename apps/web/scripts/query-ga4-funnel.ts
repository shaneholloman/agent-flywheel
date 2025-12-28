#!/usr/bin/env bun
/**
 * GA4 Funnel Data Query Script
 *
 * Queries GA4 Data API to show wizard and learning hub funnel progression.
 * Uses Application Default Credentials (gcloud auth application-default login).
 *
 * Usage: bun run scripts/query-ga4-funnel.ts
 */

import { BetaAnalyticsDataClient } from '@google-analytics/data';

const PROPERTY_ID = '517085078';

const client = new BetaAnalyticsDataClient();

interface FunnelStep {
  step: number;
  users: number;
  events: number;
  dropoffRate?: number;
}

async function queryWizardFunnel(): Promise<FunnelStep[]> {
  console.log('\n📊 Querying Wizard Funnel Data...\n');

  try {
    // Use the correct dimension name that matches what events send
    const [response] = await client.runReport({
      property: `properties/${PROPERTY_ID}`,
      dateRanges: [{ startDate: '30daysAgo', endDate: 'today' }],
      dimensions: [{ name: 'customEvent:step_number' }],
      metrics: [
        { name: 'activeUsers' },
        { name: 'eventCount' },
      ],
      dimensionFilter: {
        filter: {
          fieldName: 'eventName',
          stringFilter: {
            matchType: 'EXACT',
            value: 'funnel_step_enter',
          },
        },
      },
      orderBys: [
        {
          dimension: { dimensionName: 'customEvent:step_number' },
          desc: false,
        },
      ],
    });

    const steps: FunnelStep[] = [];

    if (response.rows) {
      for (const row of response.rows) {
        const stepNum = parseInt(row.dimensionValues?.[0]?.value || '0', 10);
        const users = parseInt(row.metricValues?.[0]?.value || '0', 10);
        const events = parseInt(row.metricValues?.[1]?.value || '0', 10);

        if (stepNum > 0 && stepNum <= 13) {
          steps.push({ step: stepNum, users, events });
        }
      }
    }

    // Sort by step number
    steps.sort((a, b) => a.step - b.step);

    // Calculate drop-off rates
    for (let i = 1; i < steps.length; i++) {
      const prevUsers = steps[i - 1].users;
      const currUsers = steps[i].users;
      if (prevUsers > 0) {
        steps[i].dropoffRate = ((prevUsers - currUsers) / prevUsers) * 100;
      }
    }

    return steps;
  } catch (error) {
    console.error('Error querying wizard funnel:', error);
    return [];
  }
}

async function queryLessonFunnel(): Promise<FunnelStep[]> {
  console.log('\n📚 Querying Learning Hub Funnel Data...\n');
  console.log('   Note: No lesson tracking events detected yet - learning hub may need traffic.\n');

  try {
    const [response] = await client.runReport({
      property: `properties/${PROPERTY_ID}`,
      dateRanges: [{ startDate: '30daysAgo', endDate: 'today' }],
      dimensions: [{ name: 'customEvent:lesson_id' }],
      metrics: [
        { name: 'activeUsers' },
        { name: 'eventCount' },
      ],
      dimensionFilter: {
        filter: {
          fieldName: 'eventName',
          stringFilter: {
            matchType: 'EXACT',
            value: 'lesson_view',
          },
        },
      },
      orderBys: [
        {
          dimension: { dimensionName: 'customEvent:lesson_id' },
          desc: false,
        },
      ],
    });

    const steps: FunnelStep[] = [];

    if (response.rows) {
      for (const row of response.rows) {
        const lessonId = parseInt(row.dimensionValues?.[0]?.value || '0', 10);
        const users = parseInt(row.metricValues?.[0]?.value || '0', 10);
        const events = parseInt(row.metricValues?.[1]?.value || '0', 10);

        if (lessonId >= 0 && lessonId < 20) {
          steps.push({ step: lessonId, users, events });
        }
      }
    }

    // Sort by lesson number
    steps.sort((a, b) => a.step - b.step);

    // Calculate drop-off rates
    for (let i = 1; i < steps.length; i++) {
      const prevUsers = steps[i - 1].users;
      const currUsers = steps[i].users;
      if (prevUsers > 0) {
        steps[i].dropoffRate = ((prevUsers - currUsers) / prevUsers) * 100;
      }
    }

    return steps;
  } catch (error) {
    console.error('Error querying lesson funnel:', error);
    return [];
  }
}

async function queryOverviewMetrics(): Promise<void> {
  console.log('\n📈 Querying Overview Metrics...\n');

  try {
    const [response] = await client.runReport({
      property: `properties/${PROPERTY_ID}`,
      dateRanges: [{ startDate: '30daysAgo', endDate: 'today' }],
      metrics: [
        { name: 'activeUsers' },
        { name: 'sessions' },
        { name: 'screenPageViews' },
        { name: 'averageSessionDuration' },
        { name: 'bounceRate' },
      ],
    });

    if (response.rows && response.rows[0]) {
      const row = response.rows[0];
      console.log('  Overview (Last 30 Days):');
      console.log('  ─'.repeat(25));
      console.log(`  Active Users:     ${row.metricValues?.[0]?.value || 'N/A'}`);
      console.log(`  Sessions:         ${row.metricValues?.[1]?.value || 'N/A'}`);
      console.log(`  Page Views:       ${row.metricValues?.[2]?.value || 'N/A'}`);
      const avgDuration = parseFloat(row.metricValues?.[3]?.value || '0');
      console.log(`  Avg Session:      ${Math.floor(avgDuration / 60)}m ${Math.floor(avgDuration % 60)}s`);
      const bounceRate = parseFloat(row.metricValues?.[4]?.value || '0') * 100;
      console.log(`  Bounce Rate:      ${bounceRate.toFixed(1)}%`);
    }
  } catch (error) {
    console.error('Error querying overview:', error);
  }
}

async function queryConversions(): Promise<void> {
  console.log('\n🎯 Querying Conversion Events...\n');

  try {
    const [response] = await client.runReport({
      property: `properties/${PROPERTY_ID}`,
      dateRanges: [{ startDate: '30daysAgo', endDate: 'today' }],
      dimensions: [{ name: 'eventName' }],
      metrics: [
        { name: 'eventCount' },
        { name: 'activeUsers' },
      ],
      dimensionFilter: {
        filter: {
          fieldName: 'eventName',
          inListFilter: {
            values: [
              'wizard_start',
              'wizard_complete',
              'vps_created',
              'installer_run',
              'learning_hub_started',
              'lesson_funnel_complete',
              'conversion',
            ],
          },
        },
      },
      orderBys: [
        { metric: { metricName: 'eventCount' }, desc: true },
      ],
    });

    if (response.rows) {
      console.log('  Conversion Events (Last 30 Days):');
      console.log('  ─'.repeat(35));
      console.log('  Event                      Count    Users');
      console.log('  ─'.repeat(35));

      for (const row of response.rows) {
        const eventName = row.dimensionValues?.[0]?.value || '';
        const count = row.metricValues?.[0]?.value || '0';
        const users = row.metricValues?.[1]?.value || '0';
        console.log(`  ${eventName.padEnd(26)} ${count.padStart(5)}    ${users.padStart(5)}`);
      }
    }
  } catch (error) {
    console.error('Error querying conversions:', error);
  }
}

function printFunnelChart(steps: FunnelStep[], title: string, maxSteps: number): void {
  if (steps.length === 0) {
    console.log(`  No data available for ${title}`);
    return;
  }

  const maxUsers = Math.max(...steps.map(s => s.users));
  const barWidth = 40;

  console.log(`  ${title}:`);
  console.log('  ─'.repeat(35));
  console.log('  Step   Users    Drop-off   Funnel');
  console.log('  ─'.repeat(35));

  for (let i = 1; i <= maxSteps; i++) {
    const step = steps.find(s => s.step === i);
    const users = step?.users || 0;
    const dropoff = step?.dropoffRate;

    const barLength = maxUsers > 0 ? Math.round((users / maxUsers) * barWidth) : 0;
    const bar = '█'.repeat(barLength) + '░'.repeat(barWidth - barLength);

    const dropoffStr = dropoff !== undefined ? `${dropoff.toFixed(1)}%` : '-';

    console.log(
      `  ${String(i).padStart(4)}   ${String(users).padStart(5)}    ${dropoffStr.padStart(7)}   ${bar}`
    );
  }

  // Summary stats
  const firstStep = steps.find(s => s.step === 1);
  const lastStep = steps.find(s => s.step === maxSteps);
  if (firstStep && lastStep) {
    const overallConversion = firstStep.users > 0
      ? ((lastStep.users / firstStep.users) * 100).toFixed(1)
      : '0';
    console.log('  ─'.repeat(35));
    console.log(`  Overall Conversion: ${overallConversion}% (${lastStep.users}/${firstStep.users} users)`);
  }
}

async function main() {
  console.log('═'.repeat(60));
  console.log('📊 ACFS GA4 Funnel Analytics Report');
  console.log('═'.repeat(60));
  console.log(`\nProperty ID: ${PROPERTY_ID}`);
  console.log('Date Range: Last 30 days\n');

  try {
    // Query overview metrics
    await queryOverviewMetrics();

    // Query conversions
    await queryConversions();

    // Query and display wizard funnel
    const wizardSteps = await queryWizardFunnel();
    printFunnelChart(wizardSteps, 'Wizard Funnel (13 Steps)', 13);

    // Query and display lesson funnel
    const lessonSteps = await queryLessonFunnel();
    printFunnelChart(lessonSteps, 'Learning Hub Funnel (20 Lessons)', 20);

    console.log('\n═'.repeat(60));
    console.log('✅ Report complete!');
    console.log('═'.repeat(60));

  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error);

    if (errorMessage.includes('Could not load the default credentials')) {
      console.error('\n❌ Authentication required!');
      console.error('\nPlease run:');
      console.error('  gcloud auth application-default login');
      console.error('\nThen retry this script.');
    } else {
      console.error('\n❌ Error:', errorMessage);
    }
    process.exit(1);
  }
}

main().catch(console.error);
