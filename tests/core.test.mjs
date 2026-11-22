import test from 'node:test';
import assert from 'node:assert/strict';
import { ACTIONS, createGameStore, DEFAULT_SETTINGS, STORAGE_KEYS } from '../preview/core/game.mjs';

class MemoryStorage {
  data = new Map();
  writes = [];
  failKey = null;
  getItem(key) { return this.data.get(key) ?? null; }
  setItem(key, value) {
    if (key === this.failKey) {
      const error = new Error('Test quota reached');
      error.name = 'QuotaExceededError';
      throw error;
    }
    this.data.set(key, String(value));
    this.writes.push(key);
  }
}

function setup(storage = new MemoryStorage(), prefix = 'a') {
  let count = 0;
  let time = Date.parse('2026-11-22T12:00:00Z');
  const store = createGameStore(storage, { id: () => `${prefix}-${++count}`, now: () => new Date(time += 1000) });
  return { store, storage };
}

test('fresh entry has no pretend save and sound starts muted', () => {
  const { store, storage } = setup();
  assert.deepEqual(store.getSettings(), DEFAULT_SETTINGS);
  assert.equal(store.getSettings().masterVolume, 0);
  assert.equal(store.inspectSave().status, 'missing');
  assert.equal(store.inspectSave().canContinue, false);
  assert.equal(store.continueLife().code, 'SAVE_MISSING');
  assert.equal(store.performAction('gather_wood').code, 'NO_ACTIVE_LIFE');
  assert.equal(storage.writes.length, 0);
});

test('first day conserves wood, persists each step and survives a fresh store', () => {
  const { store, storage } = setup();
  const started = store.startNewLife('  Aurelia  ');
  assert.equal(started.ok, true);
  assert.equal(started.state.player.name, 'Aurelia');
  const identity = started.state.player.id;
  assert.equal(started.state.actions.filter((a) => a.enabled).length, 1);
  assert.equal(store.performAction('build_shelter').code, 'ACTION_BLOCKED');
  assert.equal(store.performAction('gather_wood').state.resources.wood, 6);
  assert.equal(store.getState().village.woodSupply, 2);
  assert.equal(store.performAction('build_shelter').state.resources.wood, 2);
  assert.equal(store.getState().shelter.built, true);
  assert.equal(store.performAction('help_marcus').state.resources.wood, 0);
  assert.equal(store.getState().marcus.trust, 10);
  assert.equal(store.getState().day, 1);
  assert.equal(store.getState().phase, 'complete');
  assert.equal(store.getState().actions.some((a) => a.enabled), false);
  // Initial eight = two left at the source + four built + two donated.
  assert.equal(store.getState().village.woodSupply + 4 + 2, 8);
  const reloaded = setup(storage, 'b').store.continueLife();
  assert.equal(reloaded.ok, true);
  assert.equal(reloaded.state.player.id, identity);
  assert.deepEqual(reloaded.state, store.getState());
});

test('repeat actions never grant more goods, trust, time or events', () => {
  const { store, storage } = setup();
  store.startNewLife('Titus');
  for (const action of ACTIONS) {
    assert.equal(store.performAction(action.id).ok, true);
    const before = store.getState();
    const raw = storage.getItem(STORAGE_KEYS.save);
    const writes = storage.writes.length;
    for (let i = 0; i < 4; i += 1) assert.equal(store.performAction(action.id).repeated, true);
    assert.deepEqual(store.getState(), before);
    assert.equal(storage.getItem(STORAGE_KEYS.save), raw);
    assert.equal(storage.writes.length, writes);
  }
  assert.equal(store.getState().journal.length, 4);
  assert.equal(store.getState().revision, 3);
  assert.equal(store.performAction('invented_action').code, 'UNKNOWN_ACTION');
});

test('returning to the menu and cancelling a new life leave the original untouched', () => {
  const { store, storage } = setup();
  store.startNewLife('Lucia');
  store.performAction('gather_wood');
  const raw = storage.getItem(STORAGE_KEYS.save);
  const backup = storage.getItem(STORAGE_KEYS.backup);
  for (let i = 0; i < 6; i += 1) {
    assert.equal(store.resetForMenu().ok, true);
    assert.equal(store.getState(), null);
    assert.equal(store.startNewLife('Marcus').code, 'REPLACE_REQUIRED');
    assert.equal(store.continueLife().ok, true);
  }
  assert.equal(storage.getItem(STORAGE_KEYS.save), raw);
  assert.equal(storage.getItem(STORAGE_KEYS.backup), backup);
});

test('confirmed replacement keeps the previous life as a recoverable backup', () => {
  const { store, storage } = setup();
  store.startNewLife('Lucia');
  store.performAction('gather_wood');
  const old = storage.getItem(STORAGE_KEYS.save);
  assert.equal(store.startNewLife('Titus', { replace: true }).ok, true);
  assert.equal(storage.getItem(STORAGE_KEYS.backup), old);
  assert.equal(store.getState().player.name, 'Titus');
  assert.equal(store.inspectSave().backup.summary.name, 'Lucia');
  assert.equal(store.restoreBackup().state.player.name, 'Lucia');
  assert.equal(store.inspectSave().backup.summary.name, 'Titus');
});

test('quota failure during the backup or commit never advances the in-memory world', () => {
  for (const failedKey of [STORAGE_KEYS.backup, STORAGE_KEYS.save]) {
    const { store, storage } = setup();
    store.startNewLife('Lucia');
    const before = store.getState();
    const raw = storage.getItem(STORAGE_KEYS.save);
    storage.failKey = failedKey;
    const result = store.performAction('gather_wood');
    assert.equal(result.ok, false);
    assert.equal(result.code, 'STORAGE_FULL');
    assert.deepEqual(store.getState(), before);
    assert.equal(storage.getItem(STORAGE_KEYS.save), raw);
    storage.failKey = null;
    assert.equal(store.performAction('gather_wood').ok, true);
    assert.equal(store.getState().resources.wood, 6);
  }
});

test('a failed first save cannot create a playable unsaved world', () => {
  const { store, storage } = setup();
  storage.failKey = STORAGE_KEYS.save;
  assert.equal(store.startNewLife('Lucia').code, 'STORAGE_FULL');
  assert.equal(store.getState(), null);
  assert.equal(store.inspectSave().status, 'missing');
});

test('corrupt primary saves stay unchanged until explicit backup recovery', () => {
  const { store, storage } = setup();
  store.startNewLife('Lucia');
  store.performAction('gather_wood');
  const backup = storage.getItem(STORAGE_KEYS.backup);
  const damaged = '{broken save';
  storage.setItem(STORAGE_KEYS.save, damaged);
  const fresh = setup(storage, 'b').store;
  assert.equal(fresh.inspectSave().status, 'corrupt');
  assert.equal(fresh.inspectSave().canContinue, false);
  assert.equal(fresh.continueLife().code, 'SAVE_CORRUPT');
  assert.equal(fresh.startNewLife('Titus', { replace: true }).code, 'SAVE_CORRUPT');
  assert.equal(storage.getItem(STORAGE_KEYS.save), damaged);
  assert.equal(fresh.restoreBackup().ok, true);
  assert.equal(storage.getItem(STORAGE_KEYS.recovery), damaged);
  assert.equal(storage.getItem(STORAGE_KEYS.save), backup);
  assert.equal(fresh.getState().resources.wood, 0);
});

test('recovery fails safely if the damaged original cannot be preserved', () => {
  const { store, storage } = setup();
  store.startNewLife('Lucia');
  store.performAction('gather_wood');
  storage.setItem(STORAGE_KEYS.save, '{damaged');
  storage.failKey = STORAGE_KEYS.recovery;
  assert.equal(store.restoreBackup().code, 'STORAGE_FULL');
  assert.equal(storage.getItem(STORAGE_KEYS.save), '{damaged');
  storage.failKey = null;
  storage.setItem(STORAGE_KEYS.recovery, '{older damaged original');
  assert.equal(store.restoreBackup().code, 'RECOVERY_OCCUPIED');
  assert.equal(storage.getItem(STORAGE_KEYS.recovery), '{older damaged original');
  assert.equal(storage.getItem(STORAGE_KEYS.save), '{damaged');
});

test('unknown and newer save formats are never overwritten, including recovery', () => {
  for (const change of [(doc) => { doc.version = 2; }, (doc) => { doc.format = 'future-unreal-save'; }]) {
    const { store, storage } = setup();
    store.startNewLife('Lucia');
    store.performAction('gather_wood');
    const document = JSON.parse(storage.getItem(STORAGE_KEYS.save));
    change(document);
    const newer = JSON.stringify(document);
    storage.setItem(STORAGE_KEYS.save, newer);
    const fresh = setup(storage, 'b').store;
    assert.equal(fresh.inspectSave().status, 'unsupported');
    assert.equal(fresh.continueLife().code, 'SAVE_UNSUPPORTED');
    assert.equal(fresh.startNewLife('Titus', { replace: true }).code, 'SAVE_UNSUPPORTED');
    assert.equal(fresh.restoreBackup().code, 'SAVE_UNSUPPORTED');
    assert.equal(storage.getItem(STORAGE_KEYS.save), newer);
  }
});

test('damaged data, forged values and damaged backups cannot be resumed', () => {
  const { store, storage } = setup();
  store.startNewLife('Lucia');
  const document = JSON.parse(storage.getItem(STORAGE_KEYS.save));
  document.data.resources.wood = 9000;
  storage.setItem(STORAGE_KEYS.save, JSON.stringify(document));
  storage.setItem(STORAGE_KEYS.backup, '[]');
  assert.equal(store.inspectSave().status, 'corrupt');
  assert.equal(store.inspectSave().backup.status, 'corrupt');
  assert.equal(store.restoreBackup().code, 'BACKUP_UNAVAILABLE');
});

test('corrupt and future backups are preserved only when a commit would overwrite them', () => {
  for (const state of ['corrupt', 'unsupported']) {
    const { store, storage } = setup();
    store.startNewLife('Lucia');
    const main = storage.getItem(STORAGE_KEYS.save);
    const before = store.getState();
    const future = JSON.parse(main);
    future.version = 2;
    const backup = state === 'corrupt' ? '{damaged backup' : JSON.stringify(future);
    storage.setItem(STORAGE_KEYS.backup, backup);
    const writes = storage.writes.length;
    const result = store.performAction('gather_wood');
    assert.equal(result.code, state === 'corrupt' ? 'BACKUP_CORRUPT' : 'BACKUP_UNSUPPORTED');
    assert.equal(storage.getItem(STORAGE_KEYS.save), main);
    assert.equal(storage.getItem(STORAGE_KEYS.backup), backup);
    assert.deepEqual(store.getState(), before);
    assert.equal(storage.writes.length, writes);

    // A first-ever main save does not rotate or overwrite an existing backup.
    const freshStorage = new MemoryStorage();
    freshStorage.setItem(STORAGE_KEYS.backup, backup);
    const fresh = setup(freshStorage, 'fresh').store;
    assert.equal(fresh.startNewLife('Titus').ok, true);
    assert.equal(freshStorage.getItem(STORAGE_KEYS.backup), backup);
  }
});

test('another window changing the save causes an explicit conflict, not lost progress', () => {
  const { store: first, storage } = setup();
  first.startNewLife('Lucia');
  const second = setup(storage, 'b').store;
  second.continueLife();
  second.performAction('gather_wood');
  const changed = storage.getItem(STORAGE_KEYS.save);
  assert.equal(first.performAction('gather_wood').code, 'SAVE_CONFLICT');
  assert.equal(storage.getItem(STORAGE_KEYS.save), changed);
  assert.equal(first.continueLife().state.resources.wood, 6);
  assert.equal(first.performAction('gather_wood').repeated, true);
});

test('settings persist across restart and reject invalid or unknown input', () => {
  const { store, storage } = setup();
  const settings = { textScale: 1.3, highContrast: true, reducedMotion: true, masterVolume: 0.35 };
  assert.equal(store.updateSettings(settings).ok, true);
  assert.deepEqual(setup(storage, 'b').store.getSettings(), settings);
  const before = storage.getItem(STORAGE_KEYS.settings);
  for (const patch of [{ masterVolume: -1 }, { masterVolume: NaN }, { textScale: 100 }, { reducedMotion: 'yes' }, { hiddenOption: true }]) {
    assert.equal(store.updateSettings(patch).code, 'INVALID_SETTINGS');
    assert.equal(storage.getItem(STORAGE_KEYS.settings), before);
  }
  storage.failKey = STORAGE_KEYS.settings;
  assert.equal(store.updateSettings({ masterVolume: 0 }).code, 'STORAGE_FULL');
  assert.deepEqual(store.getSettings(), settings);
});

test('unknown and corrupt settings are reported and preserved', () => {
  const { store, storage } = setup();
  store.updateSettings({ highContrast: true });
  const document = JSON.parse(storage.getItem(STORAGE_KEYS.settings));
  document.version = 2;
  const future = JSON.stringify(document);
  storage.setItem(STORAGE_KEYS.settings, future);
  assert.equal(store.inspectSettings().status, 'unsupported');
  assert.equal(store.updateSettings({ highContrast: false }).code, 'SETTINGS_UNSUPPORTED');
  assert.equal(storage.getItem(STORAGE_KEYS.settings), future);
  storage.setItem(STORAGE_KEYS.settings, '{broken');
  assert.equal(store.inspectSettings().status, 'corrupt');
  assert.equal(store.updateSettings({ highContrast: false }).code, 'SETTINGS_CORRUPT');
  assert.equal(storage.getItem(STORAGE_KEYS.settings), '{broken');
});

test('blocked browser storage produces honest errors instead of pretend progress', () => {
  const blocked = createGameStore({ getItem() { throw new Error('Permission denied'); }, setItem() { throw new Error('Permission denied'); } });
  assert.equal(blocked.inspectSave().status, 'unavailable');
  assert.equal(blocked.startNewLife('Lucia').code, 'STORAGE_UNAVAILABLE');
  assert.equal(blocked.continueLife().code, 'STORAGE_UNAVAILABLE');
  assert.equal(blocked.updateSettings({ highContrast: true }).code, 'STORAGE_UNAVAILABLE');
  assert.equal(blocked.getState(), null);
});

test('names are normalized and validated before any write', () => {
  const { store, storage } = setup();
  for (const name of ['', '   ', 'a'.repeat(33), 'A\nB', 'A\u202eB', '<script>', null]) {
    assert.equal(store.startNewLife(name).code, 'INVALID_NAME');
    assert.equal(storage.writes.length, 0);
  }
  assert.equal(store.startNewLife('  Aure\u0301lia  ').state.player.name, 'Aurélia');
});

test('returned snapshots and failing listeners cannot mutate or invalidate committed state', () => {
  const { store } = setup();
  const notifications = [];
  const unsubscribe = store.subscribe((event) => notifications.push(event.type));
  store.subscribe(() => { throw new Error('Display failed'); });
  assert.equal(store.startNewLife('Lucia').ok, true);
  const exposed = store.getState();
  exposed.resources.wood = 1000;
  exposed.actions[0].enabled = false;
  assert.equal(store.getState().resources.wood, 0);
  assert.equal(store.getState().actions[0].enabled, true);
  assert.equal(store.performAction('gather_wood').ok, true);
  unsubscribe();
  store.resetForMenu();
  assert.deepEqual(notifications, ['save', 'save']);
});
