import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { STORAGE_KEYS } from '../preview/core/game.mjs';

// Run only where local browser execution is permitted. No installation or sandbox overrides.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const artifacts = join(root, 'artifacts/browser');
const port = Number(process.env.IMPERATHEN_PORT ?? 4173);
const url = `http://127.0.0.1:${port}`;
const report = { startedAt: new Date().toISOString(), passed: false, checks: [], pageErrors: [] };
let server, browser, page;
await mkdir(artifacts, { recursive: true });

async function noOverflow(label) {
  const widths = await page.evaluate(() => ({ viewport: innerWidth,
    document: document.documentElement.scrollWidth, body: document.body.scrollWidth }));
  assert.ok(Math.max(widths.document, widths.body) <= widths.viewport + 2,
    `${label}: horizontal overflow ${JSON.stringify(widths)}`);
  report.checks.push(`${label}: no horizontal DOM overflow`);
}

async function picture(name) {
  await page.screenshot({ path: join(artifacts, `${name}.png`), fullPage: true });
}

async function hideIntro() {
  await page.locator('#skip-intro').click();
  await page.locator('#intro').waitFor({ state: 'hidden' });
}

try {
  let playwright;
  try { playwright = createRequire(import.meta.url)('playwright'); }
  catch (error) {
    const modules = process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
    if (modules) {
      try { playwright = createRequire(join(modules, '__browser_check__.cjs'))('playwright'); }
      catch { /* Report the unavailable runtime below; do not install anything. */ }
    }
    if (!playwright) throw new Error(`Installed Playwright runtime not found. No packages or browsers were downloaded. ${error.message}`);
  }
  assert.ok(Number.isInteger(port) && port >= 1024 && port <= 65535, 'Invalid IMPERATHEN_PORT');
  server = spawn(process.execPath, ['tools/serve.mjs'], {
    cwd: root, env: { ...process.env, IMPERATHEN_PORT: String(port) }, stdio: ['ignore', 'pipe', 'pipe']
  });
  await new Promise((ready, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error(`Preview server did not start: ${output}`)), 10000);
    const fail = error => { clearTimeout(timer); reject(error); };
    server.once('error', fail);
    server.once('exit', code => fail(new Error(`Preview server exited (${code}): ${output}`)));
    server.stderr.on('data', chunk => { output = (output + chunk).slice(-4000); });
    server.stdout.on('data', chunk => {
      output = (output + chunk).slice(-4000);
      if (output.includes(`IMPERATHEN preview: ${url}`)) { clearTimeout(timer); ready(); }
    });
  });
  browser = await playwright.chromium.launch({ headless: true, chromiumSandbox: true,
    ...(process.env.IMPERATHEN_CHROMIUM ? { executablePath: process.env.IMPERATHEN_CHROMIUM } : {}) });
  report.browser = browser.version();
  for (const scenario of [{ name: 'desktop', width: 1440, height: 1000, scale: '1' },
    { name: 'mobile-130', width: 360, height: 800, scale: '1.3' }]) {
    const context = await browser.newContext({ viewport: { width: scenario.width, height: scenario.height },
      reducedMotion: 'no-preference', isMobile: scenario.width === 360, hasTouch: scenario.width === 360 });
    page = await context.newPage();
    page.setDefaultTimeout(15000);
    page.on('pageerror', error => report.pageErrors.push(`${scenario.name}: ${error.message}`));
    await page.goto(url, { waitUntil: 'networkidle' });
    await page.locator('#intro').waitFor({ state: 'visible' });
    if (scenario.name === 'desktop') await page.locator('#intro').waitFor({ state: 'hidden', timeout: 15000 });
    else await hideIntro();
    await page.locator('#replay-intro').click();
    await page.locator('#intro').waitFor({ state: 'visible' });
    await page.keyboard.press('Escape');
    await page.locator('#intro').waitFor({ state: 'hidden' });
    report.checks.push(`${scenario.name}: ${scenario.name === 'desktop' ? 'automatic intro completion' : 'intro skip button'} and replay Escape`);
    for (let attempt = 0; attempt < 3; attempt++) {
      await page.locator('#open-settings').click();
      await page.locator('#settings-dialog').waitFor({ state: 'visible' });
      await page.locator('#text-scale').selectOption(scenario.scale);
      await page.locator('#high-contrast').setChecked(attempt === 1);
      await noOverflow(`${scenario.name} settings ${attempt + 1}`);
      if (attempt === 0) await picture(`${scenario.name}-settings`);
      await page.locator('#settings-dialog [data-close]').last().click();
      await page.locator('#settings-dialog').waitFor({ state: 'hidden' });
    }
    await noOverflow(`${scenario.name} menu`);
    await picture(`${scenario.name}-menu`);
    await page.locator('#new-life').click();
    await page.locator('#player-name').fill(`Prüfung ${scenario.name}`);
    await page.locator('#begin-life').click();
    await page.locator('#village-screen').waitFor({ state: 'visible' });
    for (const action of ['gather_wood', 'build_shelter', 'help_marcus']) await page.locator(`[data-action="${action}"]`).click();
    assert.equal(await page.locator('#chapter-progress').innerText(), '3 / 3 Schritte');
    assert.equal(await page.locator('#journal-list li').count(), 4);
    const saved = await page.evaluate(key => localStorage.getItem(key), STORAGE_KEYS.save);
    assert.ok(saved, 'Completed life has no persisted save');
    await noOverflow(`${scenario.name} village`);
    await picture(`${scenario.name}-village`);
    await page.reload({ waitUntil: 'networkidle' });
    await hideIntro();
    assert.equal(await page.locator('#text-scale').inputValue(), scenario.scale);
    await page.locator('#continue-life').click();
    assert.equal(await page.locator('#chapter-progress').innerText(), '3 / 3 Schritte');
    assert.equal(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEYS.save), saved);
    await page.locator('#return-menu').click();
    await page.locator('#new-life').click();
    await page.locator('#player-name').fill('Abgebrochener Neubeginn');
    await page.locator('#replace-save').check();
    await page.keyboard.press('Escape');
    await page.locator('#new-life-dialog').waitFor({ state: 'hidden' });
    assert.equal(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEYS.save), saved, 'Cancel changed the save');
    await page.locator('#continue-life').click();
    assert.equal(await page.locator('#chapter-progress').innerText(), '3 / 3 Schritte');
    await noOverflow(`${scenario.name} resumed after cancel`);
    report.checks.push(`${scenario.name}: settings x3, three actions, reload/continue and cancel preserve progress`);
    await context.close(); page = undefined;
  }
  assert.deepEqual(report.pageErrors, [], 'Uncaught page errors');
  report.passed = true;
} catch (error) {
  report.error = error.stack ?? String(error);
  if (page && !page.isClosed()) await picture('failure').catch(() => {});
  console.error(`Browser check failed or could not run; no visual pass claimed.\n${report.error}`);
  process.exitCode = 1;
} finally {
  await browser?.close().catch(() => {});
  if (server && server.exitCode === null) server.kill('SIGTERM');
  report.finishedAt = new Date().toISOString();
  await writeFile(join(artifacts, 'report.json'), JSON.stringify(report, null, 2) + '\n');
  if (report.passed) console.log(`Browser checks passed; evidence: ${artifacts}`);
}
