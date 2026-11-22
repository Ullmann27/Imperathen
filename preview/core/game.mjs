/**
 * Small, local first-day simulation for the IMPERATHEN browser preview.
 * These saves deliberately have their own format. They are not Unreal saves.
 * Storage#setItem is the single-key commit point. A preceding backup preserves
 * the last accepted state; this is not a multi-tab database transaction.
 */

export const STORAGE_KEYS = Object.freeze({
  save: 'imperathen.preview.save.v1',
  backup: 'imperathen.preview.backup.v1',
  recovery: 'imperathen.preview.recovery.v1',
  settings: 'imperathen.preview.settings.v1',
});

export const DEFAULT_SETTINGS = Object.freeze({
  textScale: 1,
  highContrast: false,
  reducedMotion: false,
  masterVolume: 0,
});

export const ACTIONS = Object.freeze([
  Object.freeze({ id: 'gather_wood', label: 'Holz sammeln', description: 'Sammle sechs Holz aus dem Vorrat am Waldrand.' }),
  Object.freeze({ id: 'build_shelter', label: 'Unterstand errichten', description: 'Verwende vier Holz für deinen ersten trockenen Schlafplatz.' }),
  Object.freeze({ id: 'help_marcus', label: 'Marcus helfen', description: 'Gib Marcus die übrigen zwei Holz für sein undichtes Dach.' }),
]);

const SAVE_FORMAT = 'imperathen-browser-preview';
const SETTINGS_FORMAT = 'imperathen-browser-settings';
const VERSION = 1;
const PHASES = ['arrival', 'gathered', 'sheltered', 'complete'];
const OBJECTIVES = [
  'Ein Dach für die erste Nacht: Sammle Holz am Waldrand.',
  'Du hast genug Holz. Errichte deinen Unterstand.',
  'Dein Schlafplatz ist bereit. Marcus braucht Hilfe am Dach.',
  'Dein erster Tag in Valdora ist festgehalten.',
];
const clone = (value) => value == null ? value : JSON.parse(JSON.stringify(value));
const plain = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
const exactKeys = (value, keys) => plain(value) && Object.keys(value).length === keys.length && keys.every((key) => Object.hasOwn(value, key));
const boundedString = (value, max = 160) => typeof value === 'string' && value.length > 0 && value.length <= max;
const validTime = (value) => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value) && Number.isFinite(Date.parse(value));
const failure = (code, message) => ({ ok: false, code, message });

// Non-cryptographic damage detection only; this is not an anti-cheat signature.
function checksum(data) {
  const text = JSON.stringify(data);
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i += 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

function encode(data, format = SAVE_FORMAT) {
  return JSON.stringify({ format, version: VERSION, checksum: checksum(data), data });
}

function validName(value) {
  return typeof value === 'string' && value === value.trim() && [...value].length >= 1 && [...value].length <= 32
    && !/[\p{Cc}\p{Cf}<>]/u.test(value);
}

function validSettings(settings) {
  return exactKeys(settings, Object.keys(DEFAULT_SETTINGS))
    && [1, 1.15, 1.3].includes(settings.textScale)
    && typeof settings.highContrast === 'boolean'
    && typeof settings.reducedMotion === 'boolean'
    && typeof settings.masterVolume === 'number'
    && Number.isFinite(settings.masterVolume) && settings.masterVolume >= 0 && settings.masterVolume <= 1;
}

function validWorld(world) {
  if (!exactKeys(world, ['worldId', 'revision', 'contentVersion', 'player', 'day', 'dayProgress', 'phase', 'resources', 'village', 'shelter', 'marcus', 'completedActions', 'journal', 'createdAt', 'updatedAt'])) return false;
  if (!boundedString(world.worldId) || world.contentVersion !== 'first-day-1' || world.day !== 1) return false;
  if (!exactKeys(world.player, ['id', 'name']) || !boundedString(world.player.id) || !validName(world.player.name)) return false;
  if (!Array.isArray(world.completedActions) || world.completedActions.length > ACTIONS.length) return false;
  const step = world.completedActions.length;
  if (world.completedActions.some((id, i) => id !== ACTIONS[i].id)) return false;
  if (world.revision !== step || world.dayProgress !== step || world.phase !== PHASES[step]) return false;
  if (!exactKeys(world.resources, ['wood', 'grain']) || world.resources.wood !== [0, 6, 2, 0][step] || world.resources.grain !== 2) return false;
  if (!exactKeys(world.village, ['id', 'name', 'woodSupply']) || world.village.id !== 'valdora' || world.village.name !== 'Valdora' || world.village.woodSupply !== (step === 0 ? 8 : 2)) return false;
  if (!exactKeys(world.shelter, ['id', 'built']) || !boundedString(world.shelter.id) || world.shelter.built !== (step >= 2)) return false;
  if (!exactKeys(world.marcus, ['id', 'trust']) || world.marcus.id !== 'marcus' || world.marcus.trust !== (step === 3 ? 10 : 0)) return false;
  if (new Set([world.worldId, world.player.id, world.shelter.id, world.marcus.id]).size !== 4) return false;
  if (!validTime(world.createdAt) || !validTime(world.updatedAt)) return false;
  if (!Array.isArray(world.journal) || world.journal.length !== step + 1) return false;
  if (new Set(world.journal.map((entry) => entry?.id)).size !== world.journal.length) return false;
  return world.journal.every((entry, i) => exactKeys(entry, ['id', 'actionId', 'title', 'text', 'at'])
    && boundedString(entry.id) && entry.actionId === (i === 0 ? 'new_life' : ACTIONS[i - 1].id)
    && boundedString(entry.title, 120) && boundedString(entry.text, 1000) && validTime(entry.at));
}

function decode(raw, format = SAVE_FORMAT, validator = validWorld) {
  if (raw === null) return { status: 'missing', data: null };
  if (typeof raw !== 'string' || raw.length > 1024 * 1024) return { status: 'corrupt', data: null };
  try {
    const document = JSON.parse(raw);
    if (!plain(document)) return { status: 'corrupt', data: null };
    if (document.format !== format || (Number.isInteger(document.version) && document.version !== VERSION)) {
      return { status: 'unsupported', data: null };
    }
    if (!exactKeys(document, ['format', 'version', 'checksum', 'data']) || document.version !== VERSION
      || !validator(document.data) || document.checksum !== checksum(document.data)) {
      return { status: 'corrupt', data: null };
    }
    return { status: 'valid', data: document.data };
  } catch {
    return { status: 'corrupt', data: null };
  }
}

function summary(data) {
  return data ? { name: data.player.name, day: data.day, stage: data.phase, updatedAt: data.updatedAt, progress: data.dayProgress } : null;
}

function view(world) {
  if (!world) return null;
  return {
    ...clone(world),
    currentObjective: OBJECTIVES[world.dayProgress],
    actions: ACTIONS.map((action, index) => ({
      ...action,
      enabled: index === world.dayProgress,
      completed: index < world.dayProgress,
    })),
  };
}

function storageFailure(error) {
  if (['QuotaExceededError', 'NS_ERROR_DOM_QUOTA_REACHED'].includes(error?.name)) {
    return failure('STORAGE_FULL', 'Der Speicher ist voll. Dein bisheriger Stand bleibt erhalten. Schaffe Speicherplatz und versuche es erneut.');
  }
  return failure('STORAGE_UNAVAILABLE', 'Der lokale Speicher ist nicht erreichbar. Erlaube dieser Seite das Speichern und versuche es erneut.');
}

export function createGameStore(storage, { now = () => new Date(), id = () => globalThis.crypto?.randomUUID?.() ?? `local-${Date.now()}-${Math.random().toString(36).slice(2)}` } = {}) {
  let adapter = storage;
  if (adapter === undefined) {
    try { adapter = globalThis.localStorage; } catch { adapter = null; }
  }
  let active = null;
  let expectedRaw = null;
  const listeners = new Set();

  function read(key) {
    try {
      if (!adapter || typeof adapter.getItem !== 'function' || typeof adapter.setItem !== 'function') throw new Error('Storage unavailable');
      return { ok: true, raw: adapter.getItem(key) };
    } catch (error) { return storageFailure(error); }
  }

  function write(key, value) {
    try { adapter.setItem(key, value); return { ok: true }; }
    catch (error) { return storageFailure(error); }
  }

  function timestamp() {
    const value = now();
    const date = value instanceof Date ? value : new Date(value);
    if (!Number.isFinite(date.getTime())) throw new Error('Invalid clock');
    return date.toISOString();
  }

  function notify(type) {
    const event = { type, state: view(active), settings: getSettings() };
    for (const listener of listeners) {
      // A display error must not turn an already committed save into a failure.
      try { listener(clone(event)); } catch { /* Display owns its own errors. */ }
    }
  }

  function inspectKey(key, format, validator) {
    const result = read(key);
    return result.ok ? { ...decode(result.raw, format, validator), raw: result.raw } : { status: 'unavailable', data: null, raw: null };
  }

  function inspectSave() {
    const current = inspectKey(STORAGE_KEYS.save);
    const backup = inspectKey(STORAGE_KEYS.backup);
    return { status: current.status, canContinue: current.status === 'valid', summary: summary(current.data), backup: { status: backup.status, summary: summary(backup.data) } };
  }

  function inspectSettings() {
    const saved = inspectKey(STORAGE_KEYS.settings, SETTINGS_FORMAT, validSettings);
    return { status: saved.status, settings: clone(saved.data ?? DEFAULT_SETTINGS) };
  }

  function getSettings() { return inspectSettings().settings; }

  function updateSettings(patch) {
    if (!plain(patch) || Object.keys(patch).some((key) => !Object.hasOwn(DEFAULT_SETTINGS, key))) {
      return failure('INVALID_SETTINGS', 'Diese Einstellung ist nicht verfügbar.');
    }
    const saved = inspectKey(STORAGE_KEYS.settings, SETTINGS_FORMAT, validSettings);
    if (saved.status === 'unavailable') return storageFailure();
    if (saved.status === 'unsupported') return failure('SETTINGS_UNSUPPORTED', 'Die gespeicherten Einstellungen gehören zu einer anderen Version und werden nicht überschrieben.');
    if (saved.status === 'corrupt') return failure('SETTINGS_CORRUPT', 'Die gespeicherten Einstellungen sind beschädigt und bleiben unverändert.');
    const settings = { ...(saved.data ?? DEFAULT_SETTINGS), ...patch };
    if (!validSettings(settings)) return failure('INVALID_SETTINGS', 'Bitte wähle gültige Werte für Textgröße, Darstellung und Lautstärke.');
    const result = write(STORAGE_KEYS.settings, encode(settings, SETTINGS_FORMAT));
    if (!result.ok) return result;
    notify('settings');
    return { ok: true, settings: clone(settings), message: 'Einstellungen gespeichert.' };
  }

  function saveGuard(status) {
    if (status === 'unavailable') return storageFailure();
    if (status === 'unsupported') return failure('SAVE_UNSUPPORTED', 'Dieser Spielstand gehört zu einer anderen Version. Er bleibt unverändert.');
    if (status === 'corrupt') return failure('SAVE_CORRUPT', 'Dieser Spielstand ist beschädigt. Du kannst einen vorhandenen Sicherungsstand ausdrücklich wiederherstellen.');
    return null;
  }

  function commit(next, previousRaw, { preservePrevious = true } = {}) {
    if (!validWorld(next)) return failure('INVALID_STATE', 'Der neue Stand ist nicht gültig. Der bisherige Stand bleibt erhalten.');
    const latest = read(STORAGE_KEYS.save);
    if (!latest.ok) return latest;
    if (latest.raw !== previousRaw) return failure('SAVE_CONFLICT', 'Der Spielstand wurde in einem anderen Fenster geändert. Lade ihn erneut, bevor du weiterspielst.');
    if (preservePrevious && previousRaw !== null) {
      const existingBackup = inspectKey(STORAGE_KEYS.backup);
      if (existingBackup.status === 'unavailable') return storageFailure();
      if (existingBackup.status === 'unsupported') return failure('BACKUP_UNSUPPORTED', 'Der vorhandene Sicherungsstand gehört zu einer anderen Version und wird nicht überschrieben. Dein aktueller Stand bleibt unverändert.');
      if (existingBackup.status === 'corrupt') return failure('BACKUP_CORRUPT', 'Der vorhandene Sicherungsstand ist beschädigt und wird unverändert aufbewahrt. Dein aktueller Stand wurde nicht verändert.');
      const backupResult = write(STORAGE_KEYS.backup, previousRaw);
      if (!backupResult.ok) return backupResult;
    }
    const raw = encode(next);
    const result = write(STORAGE_KEYS.save, raw);
    if (!result.ok) return result;
    active = clone(next);
    expectedRaw = raw;
    notify('save');
    return { ok: true, state: view(active), message: 'Fortschritt gespeichert.' };
  }

  function startNewLife(name, { replace = false } = {}) {
    const cleaned = typeof name === 'string' ? name.trim().normalize('NFC') : name;
    if (!validName(cleaned)) return failure('INVALID_NAME', 'Bitte wähle einen Namen mit 1 bis 32 Zeichen, ohne Steuerzeichen oder spitze Klammern.');
    const saved = inspectKey(STORAGE_KEYS.save);
    const blocked = saveGuard(saved.status);
    if (blocked) return blocked;
    if (saved.status === 'valid' && replace !== true) return failure('REPLACE_REQUIRED', 'Ein Leben ist bereits gespeichert. Bestätige ausdrücklich, wenn du ein neues beginnen möchtest.');
    try {
      const at = timestamp();
      const world = {
        worldId: id(), revision: 0, contentVersion: 'first-day-1', player: { id: id(), name: cleaned },
        day: 1, dayProgress: 0, phase: 'arrival', resources: { wood: 0, grain: 2 },
        village: { id: 'valdora', name: 'Valdora', woodSupply: 8 },
        shelter: { id: id(), built: false }, marcus: { id: 'marcus', trust: 0 }, completedActions: [],
        journal: [{ id: id(), actionId: 'new_life', title: 'Ankunft in Valdora', text: 'Ein Platz am Dorfrand und zwei Rationen. Dein erster Weg führt zu einem Dach für die Nacht.', at }],
        createdAt: at, updatedAt: at,
      };
      const result = commit(world, saved.raw);
      return result.ok ? { ...result, message: 'Dein neues Leben in Valdora ist gespeichert.' } : result;
    } catch { return failure('START_FAILED', 'Dein neues Leben konnte nicht vorbereitet werden. Der bisherige Stand bleibt erhalten.'); }
  }

  function continueLife() {
    const saved = inspectKey(STORAGE_KEYS.save);
    const blocked = saveGuard(saved.status);
    if (blocked) return blocked;
    if (saved.status === 'missing') return failure('SAVE_MISSING', 'Es ist noch kein Leben gespeichert.');
    active = clone(saved.data);
    expectedRaw = saved.raw;
    notify('load');
    return { ok: true, state: view(active), message: 'Dein gespeichertes Leben wurde geladen.' };
  }

  function performAction(actionId) {
    if (!active) return failure('NO_ACTIVE_LIFE', 'Lade zuerst dein Leben oder beginne ein neues.');
    const index = ACTIONS.findIndex((action) => action.id === actionId);
    if (index < 0) return failure('UNKNOWN_ACTION', 'Diese Handlung ist nicht verfügbar.');
    const saved = read(STORAGE_KEYS.save);
    if (!saved.ok) return saved;
    if (saved.raw !== expectedRaw) return failure('SAVE_CONFLICT', 'Der Spielstand wurde in einem anderen Fenster geändert. Lade ihn erneut, bevor du weiterspielst.');
    if (active.completedActions.includes(actionId)) return { ok: true, repeated: true, state: view(active), message: 'Diese Aufgabe ist bereits erledigt.' };
    if (index !== active.dayProgress) return failure('ACTION_BLOCKED', OBJECTIVES[active.dayProgress]);
    try {
      const next = clone(active);
      const at = timestamp();
      let entry;
      if (actionId === 'gather_wood') {
        next.village.woodSupply -= 6;
        next.resources.wood += 6;
        entry = { title: 'Holz für die Nacht', text: 'Du hast sechs Holz gesammelt. Zwei bleiben am Waldrand. Vier reichen für einen Unterstand.' };
      } else if (actionId === 'build_shelter') {
        next.resources.wood -= 4;
        next.shelter.built = true;
        entry = { title: 'Ein eigenes Dach', text: 'Vier Holz wurden verbaut. Dein Unterstand steht; zwei Holz sind noch übrig.' };
      } else {
        next.resources.wood -= 2;
        next.marcus.trust += 10;
        entry = { title: 'Die erste Verbindung', text: 'Marcus repariert mit deinen zwei Holz sein Dach. Er merkt sich deine Hilfe. Dein erster Tag ist festgehalten.' };
      }
      next.completedActions.push(actionId);
      next.dayProgress += 1;
      next.revision += 1;
      next.phase = PHASES[next.dayProgress];
      next.updatedAt = at;
      next.journal.push({ id: id(), actionId, ...entry, at });
      const result = commit(next, expectedRaw);
      return result.ok ? { ...result, repeated: false, message: `${entry.title}. Fortschritt gespeichert.` } : result;
    } catch { return failure('ACTION_FAILED', 'Die Handlung konnte nicht abgeschlossen werden. Dein bisheriger Stand bleibt erhalten.'); }
  }

  function restoreBackup() {
    const backup = inspectKey(STORAGE_KEYS.backup);
    if (backup.status !== 'valid') return failure('BACKUP_UNAVAILABLE', 'Es ist kein lesbarer Sicherungsstand vorhanden.');
    const current = inspectKey(STORAGE_KEYS.save);
    if (current.status === 'unavailable') return storageFailure();
    if (current.status === 'unsupported') return saveGuard(current.status);
    if (current.status === 'corrupt') {
      const archive = read(STORAGE_KEYS.recovery);
      if (!archive.ok) return archive;
      if (archive.raw !== null && archive.raw !== current.raw) return failure('RECOVERY_OCCUPIED', 'Eine frühere beschädigte Datei wird bereits aufbewahrt. Sie wird nicht überschrieben; die Wiederherstellung bleibt angehalten.');
      const preserved = write(STORAGE_KEYS.recovery, current.raw);
      if (!preserved.ok) return preserved;
    }
    const result = commit(backup.data, current.raw, { preservePrevious: current.status === 'valid' });
    return result.ok ? { ...result, message: current.status === 'corrupt' ? 'Sicherungsstand wiederhergestellt. Die beschädigte Originaldatei bleibt separat aufbewahrt.' : 'Sicherungsstand wiederhergestellt.' } : result;
  }

  function resetForMenu() {
    active = null;
    expectedRaw = null;
    notify('menu');
    return { ok: true, state: null };
  }

  function subscribe(listener) {
    if (typeof listener !== 'function') throw new TypeError('Listener must be a function');
    listeners.add(listener);
    return () => listeners.delete(listener);
  }

  return Object.freeze({ getSettings, inspectSettings, updateSettings, inspectSave, startNewLife, continueLife, performAction, restoreBackup, resetForMenu, getState: () => view(active), subscribe });
}
