import { test, expect } from "@playwright/test";

/**
 * Agent Flywheel Wizard Flow E2E Tests
 *
 * These tests verify the complete wizard user journey works correctly,
 * including state persistence, navigation, and edge cases.
 *
 * Button text for each step:
 * - Step 1 (OS Selection): "Continue"
 * - Step 2 (Install Terminal): "I installed it, continue"
 * - Step 3 (Generate SSH Key): "I copied my public key"
 * - Step 4 (Rent VPS): "I rented a VPS"
 * - Step 5 (Create VPS): "Continue to SSH"
 * - Step 6 (SSH Connect): "I'm connected, continue"
 * - Step 7 (Run Installer): "Installation finished"
 * - Step 8 (Reconnect Ubuntu): "I'm connected as ubuntu"
 * - Step 9 (Status Check): "Everything looks good!"
 */

test.describe("Wizard Flow", () => {
  test.beforeEach(async ({ page }) => {
    // Clear localStorage before each test for clean state
    await page.goto("/");
    await page.evaluate(() => localStorage.clear());
  });

  test("should navigate from home to wizard", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Click the primary CTA
    await page.getByRole("link", { name: /start the wizard/i }).click();

    // Should be on step 1 (OS selection)
    await expect(page).toHaveURL("/wizard/os-selection");
    await expect(page.locator("h1").first()).toBeVisible();
    await expect(page.getByRole("heading", { level: 1 }).first()).toContainText(/OS|operating|computer/i);
  });

  test("should complete step 1: OS selection", async ({ page }) => {
    await page.goto("/wizard/os-selection");
    await page.waitForLoadState("networkidle");

    // Page should load without getting stuck
    await expect(page.locator("h1").first()).toBeVisible({ timeout: 10000 });

    // Select macOS
    await page.getByRole('radio', { name: /Mac/i }).click();

    // Wait for Continue button to be visible and clickable
    const continueBtn = page.getByRole('button', { name: /continue/i });
    await expect(continueBtn).toBeVisible();
    await continueBtn.click();

    // Should navigate to step 2
    await expect(page).toHaveURL("/wizard/install-terminal");
  });

  test("should complete step 2: Install terminal", async ({ page }) => {
    // Set up prerequisite state
    await page.goto("/wizard/os-selection");
    await page.waitForLoadState("networkidle");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();

    // Now on step 2
    await expect(page).toHaveURL("/wizard/install-terminal");
    await page.waitForLoadState("networkidle");
    await expect(page.locator("h1").first()).toContainText(/terminal/i);

    // Click continue
    await page.getByRole('button', { name: /continue/i }).click();

    // Should navigate to step 3
    await expect(page).toHaveURL("/wizard/generate-ssh-key");
  });

  test("should complete step 3: Generate SSH key", async ({ page }) => {
    // Set up prerequisite state
    await page.goto("/wizard/os-selection");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();

    // Now on step 3
    await expect(page).toHaveURL("/wizard/generate-ssh-key");
    await expect(page.locator("h1").first()).toContainText(/SSH/i);

    // Click the step 3 specific button
    await page.click('button:has-text("I copied my public key")');

    // Should navigate to step 4
    await expect(page).toHaveURL("/wizard/rent-vps");
  });

  test("should complete step 4: Rent VPS", async ({ page }) => {
    // Set up prerequisite state
    await page.goto("/wizard/os-selection");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await page.click('button:has-text("I copied my public key")');

    // Now on step 4
    await expect(page).toHaveURL("/wizard/rent-vps");
    await expect(page.locator("h1").first()).toContainText(/VPS/i);

    // Click continue
    await page.click('button:has-text("I rented a VPS")');

    // Should navigate to step 5
    await expect(page).toHaveURL("/wizard/create-vps");
  });

  test("should complete step 5: Create VPS with IP address", async ({ page }) => {
    // Set up prerequisite state
    await page.goto("/wizard/os-selection");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await page.click('button:has-text("I copied my public key")');
    await page.click('button:has-text("I rented a VPS")');

    // Now on step 5
    await expect(page).toHaveURL("/wizard/create-vps");

    // Check all checklist items
    const checkboxes = page.locator('button[role="checkbox"]');
    const count = await checkboxes.count();
    for (let i = 0; i < count; i++) {
      await checkboxes.nth(i).click();
    }

    // Enter IP address
    await page.fill('input[placeholder*="192.168"]', "192.168.1.100");

    // Wait for validation
    await expect(page.locator('text="Valid IP address"')).toBeVisible();

    // Click continue
    await page.click('button:has-text("Continue to SSH")');

    // Should navigate to step 6
    await expect(page).toHaveURL("/wizard/ssh-connect");
  });
});

test.describe("SSH Connect Page - Critical Bug Prevention", () => {
  test("should NOT get stuck on loading spinner when prerequisites are met", async ({ page }) => {
    // This is the critical test for the bug that was fixed
    // Set up localStorage with required data
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
      localStorage.setItem("acfs-vps-ip", "192.168.1.100");
    });

    // Navigate to SSH connect page
    await page.goto("/wizard/ssh-connect");

    // Page should load within 3 seconds - NOT get stuck on spinner
    await expect(page.locator("h1").first()).toBeVisible({ timeout: 3000 });
    await expect(page.locator("h1").first()).toContainText(/SSH/i);

    // The IP should be displayed
    await expect(page.locator('code:has-text("192.168.1.100")').first()).toBeVisible();

    // Continue button should be visible and clickable
    await expect(page.locator('button:has-text("continue")')).toBeVisible();
  });

  test("should redirect to create-vps when IP is missing", async ({ page }) => {
    // Set up only OS, not IP
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
      localStorage.removeItem("acfs-vps-ip");
    });

    // Navigate to SSH connect page
    await page.goto("/wizard/ssh-connect");

    // Should redirect to create-vps (where IP is entered)
    await expect(page).toHaveURL("/wizard/create-vps", { timeout: 5000 });
  });

  test("should redirect to os-selection when OS is missing", async ({ page }) => {
    // Set up only IP, not OS
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.removeItem("acfs-user-os");
      localStorage.setItem("acfs-vps-ip", "192.168.1.100");
    });

    // Navigate to SSH connect page
    await page.goto("/wizard/ssh-connect");

    // Should redirect to os-selection (first step)
    await expect(page).toHaveURL("/wizard/os-selection", { timeout: 5000 });
  });

  test("should handle continue button click correctly", async ({ page }) => {
    // Set up complete state
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
      localStorage.setItem("acfs-vps-ip", "192.168.1.100");
    });

    await page.goto("/wizard/ssh-connect");
    await expect(page.locator("h1").first()).toBeVisible({ timeout: 3000 });

    // Click continue
    await page.click('button:has-text("continue")');

    // Should navigate to run-installer
    await expect(page).toHaveURL("/wizard/run-installer");
  });
});

test.describe("State Persistence", () => {
  test("should persist OS selection across page reloads", async ({ page }) => {
    await page.goto("/wizard/os-selection");
    await page.getByRole('radio', { name: /Windows/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();

    // Reload the page
    await page.reload();

    // Check localStorage
    const os = await page.evaluate(() => localStorage.getItem("acfs-user-os"));
    expect(os).toBe("windows");
  });

  test("should persist VPS IP across page reloads", async ({ page }) => {
    // Set up prerequisite state
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
    });

    await page.goto("/wizard/create-vps");

    // Check all checklist items
    const checkboxes = page.locator('button[role="checkbox"]');
    const count = await checkboxes.count();
    for (let i = 0; i < count; i++) {
      await checkboxes.nth(i).click();
    }

    // Enter IP address
    await page.fill('input[placeholder*="192.168"]', "10.0.0.50");
    await page.click('button:has-text("Continue to SSH")');

    // Check localStorage
    const ip = await page.evaluate(() => localStorage.getItem("acfs-vps-ip"));
    expect(ip).toBe("10.0.0.50");
  });
});

test.describe("Navigation", () => {
  test("should navigate between steps using sidebar", async ({ page, viewport }) => {
    // Skip on mobile where sidebar is hidden
    if (viewport && viewport.width < 768) {
      test.skip();
    }

    await page.goto("/wizard/os-selection");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();

    // Now on step 2, click on step 1 in sidebar
    await page.click('text="Choose Your OS"');

    // Should navigate back to step 1
    await expect(page).toHaveURL("/wizard/os-selection");
  });

  test("should show mobile stepper on small screens", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto("/wizard/os-selection");

    // Mobile header should be visible
    await expect(page.locator('text="Step"')).toBeVisible();
  });

  test("should navigate using back button", async ({ page }) => {
    await page.goto("/wizard/os-selection");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();

    // Now on step 2
    await expect(page).toHaveURL("/wizard/install-terminal");

    // Go back
    await page.goBack();

    // Should be back on step 1
    await expect(page).toHaveURL("/wizard/os-selection");
  });
});

test.describe("IP Address Validation", () => {
  test("should reject invalid IP addresses", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
    });

    await page.goto("/wizard/create-vps");
    await expect(page.locator("h1").first()).toBeVisible();

    // Enter invalid IP
    await page.fill('input[placeholder*="192.168"]', "invalid-ip");
    await page.locator('input[placeholder*="192.168"]').blur();

    // Should show error
    await expect(page.getByText(/Please enter a valid IP address/i)).toBeVisible();
  });

  test("should accept valid IP addresses", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
    });

    await page.goto("/wizard/create-vps");

    // Enter valid IP
    await page.fill('input[placeholder*="192.168"]', "8.8.8.8");

    // Should show success
    await expect(page.locator('text="Valid IP address"')).toBeVisible();
  });

  test("should reject out-of-range IP octets", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
    });

    await page.goto("/wizard/create-vps");

    // Enter IP with invalid octet (256 > 255)
    await page.fill('input[placeholder*="192.168"]', "256.1.1.1");
    await page.locator('input[placeholder*="192.168"]').blur();

    // Should show error
    await expect(page.getByText(/Please enter a valid IP address/i)).toBeVisible();
  });
});

test.describe("Command Card Copy Functionality", () => {
  test("should show copy button on command cards", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
      localStorage.setItem("acfs-vps-ip", "192.168.1.100");
    });

    await page.goto("/wizard/ssh-connect");
    await expect(page.locator("h1").first()).toBeVisible({ timeout: 3000 });

    // Find a command card with copy button
    await expect(page.getByRole('button', { name: /copy/i }).first()).toBeVisible();
  });
});

test.describe("Beginner Guide", () => {
  test("should expand SimplerGuide on click", async ({ page }) => {
    await page.goto("/wizard/os-selection");
    await page.waitForLoadState("networkidle");

    // Find and click the SimplerGuide toggle
    const guideToggle = page.getByRole('button', { name: /make it simpler/i });
    if (await guideToggle.isVisible()) {
      await guideToggle.click();

      // After clicking, the subtitle should change to "Click to collapse"
      await expect(page.getByText(/click to collapse/i)).toBeVisible();
    }
  });
});

test.describe("Complete Wizard Flow Integration", () => {
  test("should continue from OS selection using detected OS (desktop only)", async ({ page }, testInfo) => {
    test.skip(/Mobile/i.test(testInfo.project.name), "Auto-detect is disabled on mobile");

    await page.goto("/wizard/os-selection");
    await page.evaluate(() => localStorage.clear());
    await page.reload();
    await page.waitForLoadState("networkidle");

    // On desktop projects, the OS should be auto-detected and the Continue button enabled.
    await expect(page.getByRole("button", { name: /^continue$/i })).toBeEnabled();
    await page.getByRole("button", { name: /^continue$/i }).click();
    await expect(page).toHaveURL("/wizard/install-terminal");
  });

  test("should complete entire wizard flow from start to finish", async ({ page }) => {
    // Start fresh
    await page.goto("/");
    await page.evaluate(() => localStorage.clear());
    await page.waitForLoadState("networkidle");

    // Step 1: Home -> OS Selection
    await page.getByRole("link", { name: /start the wizard/i }).click();
    await expect(page).toHaveURL("/wizard/os-selection");

    // Step 1: Select OS
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await expect(page).toHaveURL("/wizard/install-terminal");

    // Step 2: Install Terminal
    await page.getByRole('button', { name: /continue/i }).click();
    await expect(page).toHaveURL("/wizard/generate-ssh-key");

    // Step 3: Generate SSH Key
    await page.click('button:has-text("I copied my public key")');
    await expect(page).toHaveURL("/wizard/rent-vps");

    // Step 4: Rent VPS
    await page.click('button:has-text("I rented a VPS")');
    await expect(page).toHaveURL("/wizard/create-vps");

    // Step 5: Create VPS
    const checkboxes = page.locator('button[role="checkbox"]');
    const count = await checkboxes.count();
    for (let i = 0; i < count; i++) {
      await checkboxes.nth(i).click();
    }
    // Users often paste IPs with surrounding whitespace/newlines.
    await page.fill('input[placeholder*="192.168"]', " 192.168.1.100 ");
    await expect(page.locator('text="Valid IP address"')).toBeVisible();
    await page.click('button:has-text("Continue to SSH")');
    await expect(page).toHaveURL("/wizard/ssh-connect");

    // Step 6: SSH Connect - THE CRITICAL TEST
    // This should NOT get stuck on a loading spinner
    await expect(page.locator("h1").first()).toBeVisible({ timeout: 3000 });
    await expect(page.locator("h1").first()).toContainText(/SSH/i);
    await page.click('button:has-text("continue")');
    await expect(page).toHaveURL("/wizard/run-installer");

    // Step 7: Run Installer
    await expect(page.locator("h1").first()).toContainText(/installer/i);
    await page.click('button:has-text("finished")');
    await expect(page).toHaveURL("/wizard/reconnect-ubuntu");

    // Step 8: Reconnect Ubuntu
    await page.click('button:has-text("connected as ubuntu")');
    await expect(page).toHaveURL("/wizard/status-check");

    // Step 9: Status Check
    await page.click('button:has-text("Everything looks good")');
    await expect(page).toHaveURL("/wizard/launch-onboarding");

    // Step 10: Launch Onboarding - Final step!
    await expect(page.locator("h1").first()).toContainText(/congratulations|set up/i);
  });
});
