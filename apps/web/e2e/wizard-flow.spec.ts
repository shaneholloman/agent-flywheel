import { test, expect } from "@playwright/test";

function urlPathWithOptionalQuery(pathname: string): RegExp {
  const escaped = pathname.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`${escaped}(\\?.*)?$`);
}

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
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/os-selection"));
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
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/install-terminal"));
    expect(new URL(page.url()).searchParams.get("os")).toBe("mac");
  });

  test("should complete step 2: Install terminal", async ({ page }) => {
    // Set up prerequisite state
    await page.goto("/wizard/os-selection");
    await page.waitForLoadState("networkidle");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();

    // Now on step 2
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/install-terminal"));
    await page.waitForLoadState("networkidle");
    await expect(page.locator("h1").first()).toContainText(/terminal/i);

    // Click continue
    await page.getByRole('button', { name: /continue/i }).click();

    // Should navigate to step 3
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/generate-ssh-key"));
    expect(new URL(page.url()).searchParams.get("os")).toBe("mac");
  });

  test("should complete step 3: Generate SSH key", async ({ page }) => {
    // Set up prerequisite state
    await page.goto("/wizard/os-selection");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();

    // Now on step 3
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/generate-ssh-key"));
    await expect(page.locator("h1").first()).toContainText(/SSH/i);

    // Click the step 3 specific button
    await page.click('button:has-text("I copied my public key")');

    // Should navigate to step 4
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/rent-vps"));
    expect(new URL(page.url()).searchParams.get("os")).toBe("mac");
  });

  test("should complete step 4: Rent VPS", async ({ page }) => {
    // Set up prerequisite state
    await page.goto("/wizard/os-selection");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await page.click('button:has-text("I copied my public key")');

    // Now on step 4
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/rent-vps"));
    await expect(page.locator("h1").first()).toContainText(/VPS/i);

    // Click continue
    await page.click('button:has-text("I rented a VPS")');

    // Should navigate to step 5
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/create-vps"));
    expect(new URL(page.url()).searchParams.get("os")).toBe("mac");
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
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/create-vps"));
    expect(new URL(page.url()).searchParams.get("os")).toBe("mac");

    // Check all checklist items
    const checkboxes = page.locator('button[role="checkbox"]');
    const count = await checkboxes.count();
    for (let i = 0; i < count; i++) {
      await checkboxes.nth(i).click();
    }

    // Enter IP address (use type() + blur() for cross-browser reliability)
    const ipInput = page.locator('input[placeholder*="192.168"]');
    await ipInput.clear();
    await ipInput.type("192.168.1.100");
    await ipInput.blur();

    // Wait for validation to show success
    await expect(page.locator('text="Valid IP address"')).toBeVisible({ timeout: 10000 });

    // Click continue
    await page.click('button:has-text("Continue to SSH")');

    // Should navigate to step 6
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/ssh-connect"));
    const step6Url = new URL(page.url());
    expect(step6Url.searchParams.get("os")).toBe("mac");
    expect(step6Url.searchParams.get("ip")).toBe("192.168.1.100");
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
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/run-installer"));
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

    // URL query string should also reflect the selection
    expect(new URL(page.url()).searchParams.get("os")).toBe("windows");
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

    // Enter IP address (use type() + blur() for cross-browser reliability)
    const ipInput = page.locator('input[placeholder*="192.168"]');
    await ipInput.clear();
    await ipInput.type("10.0.0.50");
    await ipInput.blur();

    // Wait for validation to show success before clicking continue
    await expect(page.locator('text="Valid IP address"')).toBeVisible({ timeout: 10000 });
    await page.click('button:has-text("Continue to SSH")');

    // Check localStorage
    const ip = await page.evaluate(() => localStorage.getItem("acfs-vps-ip"));
    expect(ip).toBe("10.0.0.50");

    // URL query string should also reflect the IP
    expect(new URL(page.url()).searchParams.get("ip")).toBe("10.0.0.50");
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
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/os-selection"));
    expect(new URL(page.url()).searchParams.get("os")).toBe("mac");
  });

  test("should show mobile stepper on small screens", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto("/wizard/os-selection");
    await page.waitForLoadState("networkidle");

    // Mobile header should show step indicator (text spans elements, so check each part)
    await expect(page.locator('text="Step"').first()).toBeVisible({ timeout: 5000 });
    await expect(page.locator('text="of 10"').first()).toBeVisible();

    // Mobile navigation buttons should be visible at bottom (Back and Next)
    const bottomNav = page.locator(".bottom-nav-safe");
    await expect(bottomNav.getByRole("button", { name: /^Back$/i })).toBeVisible();
    await expect(bottomNav.getByRole("button", { name: /^Next$/i })).toBeVisible();
  });

  test("should navigate using back button", async ({ page }) => {
    await page.goto("/wizard/os-selection");
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();

    // Now on step 2 (URL may include query params)
    await expect(page).toHaveURL(/\/wizard\/install-terminal/);

    // Go back using browser back button
    await page.goBack();

    // Should be back on step 1 (URL may include query params like ?os=mac)
    await expect(page).toHaveURL(/\/wizard\/os-selection/);
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

    const input = page.locator('input[placeholder*="192.168"]');

    // Clear any existing value and type the invalid IP (more reliable than fill across browsers)
    await input.clear();
    await input.type("invalid-ip");
    await input.blur();

    // Should show error (allow extra time for React state updates)
    await expect(page.getByText(/Please enter a valid IP address/i)).toBeVisible({ timeout: 10000 });
  });

  test("should accept valid IP addresses", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
    });

    await page.goto("/wizard/create-vps");
    await expect(page.locator("h1").first()).toBeVisible();

    const input = page.locator('input[placeholder*="192.168"]');

    // Clear any existing value and type the valid IP
    await input.clear();
    await input.type("8.8.8.8");
    await input.blur();

    // Should show success (allow extra time for React state updates)
    await expect(page.locator('text="Valid IP address"')).toBeVisible({ timeout: 10000 });
  });

  test("should reject out-of-range IP octets", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(() => {
      localStorage.setItem("acfs-user-os", "mac");
    });

    await page.goto("/wizard/create-vps");
    await expect(page.locator("h1").first()).toBeVisible();

    const input = page.locator('input[placeholder*="192.168"]');

    // Clear any existing value and type the out-of-range IP
    await input.clear();
    await input.type("256.1.1.1");
    await input.blur();

    // Should show error (allow extra time for React state updates)
    await expect(page.getByText(/Please enter a valid IP address/i)).toBeVisible({ timeout: 10000 });
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

    // Find and click the SimplerGuide toggle - it MUST be visible
    const guideToggle = page.getByRole('button', { name: /make it simpler/i });
    await expect(guideToggle).toBeVisible({ timeout: 5000 });
    await guideToggle.click();

    // After clicking, the subtitle should change to "Click to collapse"
    await expect(page.getByText(/click to collapse/i)).toBeVisible({ timeout: 5000 });
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
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/install-terminal"));
    expect(new URL(page.url()).searchParams.get("os")).toMatch(/^(mac|windows)$/);
  });

  test("should complete entire wizard flow from start to finish", async ({ page }) => {
    // Start fresh
    await page.goto("/");
    await page.evaluate(() => localStorage.clear());
    await page.waitForLoadState("networkidle");

    // Step 1: Home -> OS Selection
    await page.getByRole("link", { name: /start the wizard/i }).click();
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/os-selection"));

    // Step 1: Select OS
    await page.getByRole('radio', { name: /Mac/i }).click();
    await page.getByRole('button', { name: /continue/i }).click();
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/install-terminal"));
    expect(new URL(page.url()).searchParams.get("os")).toBe("mac");

    // Step 2: Install Terminal
    await page.getByRole('button', { name: /continue/i }).click();
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/generate-ssh-key"));

    // Step 3: Generate SSH Key
    await page.click('button:has-text("I copied my public key")');
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/rent-vps"));

    // Step 4: Rent VPS
    await page.click('button:has-text("I rented a VPS")');
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/create-vps"));

    // Step 5: Create VPS
    const checkboxes = page.locator('button[role="checkbox"]');
    const count = await checkboxes.count();
    for (let i = 0; i < count; i++) {
      await checkboxes.nth(i).click();
    }
    // Users often paste IPs with surrounding whitespace - test that trimming works
    // Use type() + blur() for cross-browser reliability
    const ipInput = page.locator('input[placeholder*="192.168"]');
    await ipInput.clear();
    await ipInput.type(" 192.168.1.100 ");
    await ipInput.blur();
    await expect(page.locator('text="Valid IP address"')).toBeVisible({ timeout: 10000 });
    await page.click('button:has-text("Continue to SSH")');
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/ssh-connect"));
    const sshConnectUrl = new URL(page.url());
    expect(sshConnectUrl.searchParams.get("os")).toBe("mac");
    expect(sshConnectUrl.searchParams.get("ip")).toBe("192.168.1.100");

    // Step 6: SSH Connect - THE CRITICAL TEST
    // This should NOT get stuck on a loading spinner
    await expect(page.locator("h1").first()).toBeVisible({ timeout: 3000 });
    await expect(page.locator("h1").first()).toContainText(/SSH/i);
    await page.click('button:has-text("continue")');
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/run-installer"));

    // Step 7: Run Installer
    await expect(page.locator("h1").first()).toContainText(/installer/i);
    await page.click('button:has-text("finished")');
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/reconnect-ubuntu"));

    // Step 8: Reconnect Ubuntu
    await page.click('button:has-text("connected as ubuntu")');
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/status-check"));

    // Step 9: Status Check
    await page.click('button:has-text("Everything looks good")');
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/launch-onboarding"));

    // Step 10: Launch Onboarding - Final step!
    await expect(page.locator("h1").first()).toContainText(/congratulations|set up/i);
  });
});

test.describe("Query Param Fallback", () => {
  test("should honor ?os=windows when localStorage is empty", async ({ page }) => {
    await page.goto("/wizard/install-terminal?os=windows");
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/install-terminal"));
    await expect(page.locator("h1").first()).toContainText(/terminal/i);

    // Windows-specific content should render without redirecting.
    // Use .first() because "Windows Terminal" appears multiple times (heading, link, description)
    await expect(page.getByText(/Windows Terminal/i).first()).toBeVisible();
  });

  test("should honor ?os and ?ip on deep-link to ssh-connect", async ({ page }) => {
    await page.goto("/wizard/ssh-connect?os=mac&ip=192.168.1.100");
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/ssh-connect"));
    await expect(page.locator("h1").first()).toContainText(/SSH/i);
    await expect(page.locator('code:has-text("192.168.1.100")').first()).toBeVisible();
  });
});

test.describe("No localStorage (query-only resilience)", () => {
  test("should complete the wizard when localStorage is unavailable", async ({ page }, testInfo) => {
    await page.addInitScript(() => {
      const throwing = () => {
        throw new Error("localStorage blocked");
      };
      Storage.prototype.getItem = throwing;
      Storage.prototype.setItem = throwing;
      Storage.prototype.removeItem = throwing;
      Storage.prototype.clear = throwing;
    });

    // Step 1: pick an OS
    await page.goto("/wizard/os-selection");
    await expect(page.locator("h1").first()).toBeVisible();

    // On mobile, auto-detect is disabled, so Continue should start disabled.
    if (/Mobile/i.test(testInfo.project.name)) {
      await expect(page.getByRole("button", { name: /^continue$/i })).toBeDisabled();
    }

    await page.getByRole("radio", { name: /Mac/i }).click();
    await page.getByRole("button", { name: /^continue$/i }).click();
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/install-terminal"));
    expect(new URL(page.url()).searchParams.get("os")).toBe("mac");

    // Step 2 -> Step 3
    await page.getByRole("button", { name: /continue/i }).click();
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/generate-ssh-key"));

    // Step 3 -> Step 4
    await page.click('button:has-text("I copied my public key")');
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/rent-vps"));

    // Step 4 -> Step 5
    await page.click('button:has-text("I rented a VPS")');
    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/create-vps"));

    // Step 5 -> Step 6 (IP stored in URL)
    const checkboxes = page.locator('button[role="checkbox"]');
    const count = await checkboxes.count();
    for (let i = 0; i < count; i++) {
      await checkboxes.nth(i).click();
    }

    const ipInput = page.locator('input[placeholder*="192.168"]');
    await ipInput.clear();
    await ipInput.type("10.10.10.10");
    await ipInput.blur();
    await expect(page.locator('text="Valid IP address"')).toBeVisible({ timeout: 10000 });
    await page.click('button:has-text("Continue to SSH")');

    await expect(page).toHaveURL(urlPathWithOptionalQuery("/wizard/ssh-connect"));
    const url = new URL(page.url());
    expect(url.searchParams.get("os")).toBe("mac");
    expect(url.searchParams.get("ip")).toBe("10.10.10.10");
    await expect(page.locator('code:has-text("10.10.10.10")').first()).toBeVisible();
  });
});
