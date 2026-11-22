import { createGameStore } from './core/game.mjs';

const $ = (selector) => document.querySelector(selector);
const store = createGameStore();
const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
const mainMenu = $('#main-menu');
const village = $('#village-screen');
const intro = $('#intro');
const dialogs = [...document.querySelectorAll('dialog')];
const backgroundSurfaces = [$('.topbar'), mainMenu, village, $('.bottom-bar')];
const phaseLabels = { arrival: 'Ankunft in Valdora', gathered: 'Holz für die erste Nacht', sheltered: 'Ein eigenes Dach', complete: 'Der erste Tag ist festgehalten' };
const introBeats = [
  { eyebrow: 'AM RAND EINES GROSSEN REICHES', line: 'Manche erben ein Reich.', subline: 'Andere beginnen mit nichts.' },
  { eyebrow: 'EIN MORGEN. EIN NAME. EINE ENTSCHEIDUNG.', line: 'Dein Weg steht nicht geschrieben.', subline: 'Was du aufbaust. Wem du vertraust. Was von dir bleibt.' },
  { eyebrow: 'DIE CHRONIK BEGINNT MIT DIR', line: 'IMPERATHEN', subline: 'Jedes Leben hinterlässt Spuren.' },
];

let settings = store.getSettings();
let introActive = false;
let introTimers = [];
let introReturnFocus = null;
let dialogReturnFocus = null;
let toastTimer;
let audio = null;
let gamepadFrame = 0;
let gamepadLast = new Map();
let pointerFrame = 0;
let pendingPointer = null;

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function notify(message, isError = false) {
  clearTimeout(toastTimer);
  const node = $('#notification');
  node.textContent = message;
  node.classList.toggle('error', isError);
  node.hidden = false;
  toastTimer = setTimeout(() => { node.hidden = true; }, isError ? 9000 : 5000);
}

function formError(selector, message = '') {
  const node = $(selector);
  node.textContent = message;
  node.hidden = !message;
}

function reducedMotion() {
  return settings.reducedMotion || motionPreference.matches;
}

function applySettings() {
  settings = store.getSettings();
  document.documentElement.style.setProperty('--font-scale', settings.textScale);
  document.documentElement.classList.toggle('high-contrast', settings.highContrast);
  document.documentElement.classList.toggle('reduce-motion', reducedMotion());
  $('#text-scale').value = String(settings.textScale);
  $('#high-contrast').checked = settings.highContrast;
  $('#reduced-motion').checked = settings.reducedMotion;
  $('#master-volume').value = String(Math.round(settings.masterVolume * 100));
  $('#volume-value').value = `${Math.round(settings.masterVolume * 100)} %`;
  if (reducedMotion()) {
    document.documentElement.style.removeProperty('--parallax-x');
    document.documentElement.style.removeProperty('--parallax-y');
  }
  if (audio) audio.gain.gain.setTargetAtTime(settings.masterVolume * 0.035, audio.context.currentTime, 0.18);
  updateAudioLabel();
}

function setSettings(patch, { activateSound = false } = {}) {
  const result = store.updateSettings(patch);
  applySettings();
  if (!result.ok) {
    formError('#settings-error', result.message);
    notify(result.message, true);
    return false;
  }
  formError('#settings-error');
  if (activateSound && settings.masterVolume > 0) void activateAudio();
  return true;
}

function updateAudioLabel() {
  const enabled = Boolean(audio && settings.masterVolume > 0 && audio.context.state === 'running');
  const button = $('#toggle-audio');
  button.replaceChildren(element('span', '', '♪'), document.createTextNode(enabled ? 'Ton an' : 'Ton aktivieren'));
  button.setAttribute('aria-pressed', String(enabled));
  button.setAttribute('aria-label', enabled ? 'Ton ausschalten' : 'Klangatmosphäre einschalten');
}

async function activateAudio() {
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  if (!AudioContext) {
    notify('Dieser Browser unterstützt die Klangatmosphäre nicht.', true);
    return;
  }
  try {
    if (!audio) {
      const context = new AudioContext();
      const gain = context.createGain();
      gain.gain.value = 0;
      const filter = context.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.value = 380;
      filter.Q.value = 0.4;
      filter.connect(gain).connect(context.destination);
      const oscillators = [110, 164.81, 220.12].map((frequency, i) => {
        const oscillator = context.createOscillator();
        oscillator.type = 'sine';
        oscillator.frequency.value = frequency;
        const voice = context.createGain();
        voice.gain.value = [0.5, 0.2, 0.14][i];
        oscillator.connect(voice).connect(filter);
        oscillator.start();
        return oscillator;
      });
      audio = { context, gain, oscillators };
    }
    await audio.context.resume();
    audio.gain.gain.setTargetAtTime(settings.masterVolume * 0.035, audio.context.currentTime, 0.6);
    updateAudioLabel();
  } catch {
    notify('Die Klangatmosphäre konnte nicht gestartet werden. Du kannst ohne Ton weiterspielen.', true);
  }
}

function clearIntroTimers() {
  introTimers.forEach(clearTimeout);
  introTimers = [];
}

function renderBeat(index) {
  if (!introActive) return;
  const beat = introBeats[index];
  $('#intro-eyebrow').textContent = beat.eyebrow;
  $('#intro-line').textContent = beat.line;
  $('#intro-subline').textContent = beat.subline;
  document.querySelectorAll('.intro-chapters span').forEach((node, i) => node.classList.toggle('active', i === index));
  const content = $('.intro-content');
  content.classList.remove('changing');
  // Restart only a short presentation animation; no world state is touched.
  requestAnimationFrame(() => { if (introActive) content.classList.add('changing'); });
}

function startIntro({ firstVisit = false } = {}) {
  if (introActive) return;
  if (firstVisit && reducedMotion()) {
    intro.hidden = true;
    return;
  }
  clearIntroTimers();
  introReturnFocus = document.activeElement;
  introActive = true;
  intro.hidden = false;
  intro.classList.remove('is-leaving');
  backgroundSurfaces.forEach((node) => { node.inert = true; });
  renderBeat(0);
  introTimers.push(setTimeout(() => renderBeat(1), 3200), setTimeout(() => renderBeat(2), 6500), setTimeout(finishIntro, 10000));
  $('#skip-intro').focus({ preventScroll: true });
}

function finishIntro() {
  if (!introActive) return;
  introActive = false;
  clearIntroTimers();
  intro.classList.add('is-leaving');
  const done = () => {
    intro.hidden = true;
    backgroundSurfaces.forEach((node) => { node.inert = false; });
    const target = introReturnFocus && introReturnFocus !== document.body && !introReturnFocus.closest('[hidden]')
      ? introReturnFocus : $('#new-life');
    target?.focus({ preventScroll: true });
  };
  if (reducedMotion()) done();
  else introTimers.push(setTimeout(done, 700));
}

function refreshMenu() {
  const saved = store.inspectSave();
  $('#continue-life').disabled = !saved.canContinue;
  $('#continue-detail').textContent = saved.canContinue
    ? `${saved.summary.name} · Tag ${saved.summary.day} · ${phaseLabels[saved.summary.stage] ?? 'Valdora'}`
    : ({ missing: 'Noch kein Spielstand', corrupt: 'Spielstand beschädigt · Spielstände öffnen', unsupported: 'Andere Spielversion · Spielstände öffnen', unavailable: 'Lokaler Speicher nicht erreichbar' }[saved.status]);
}

function showDialog(dialog) {
  if (introActive) finishIntro();
  dialogReturnFocus = document.activeElement;
  dialogs.forEach((other) => { if (other.open) other.close(); });
  dialog.showModal();
}

dialogs.forEach((dialog) => {
  dialog.querySelectorAll('[data-close]').forEach((button) => button.addEventListener('click', () => dialog.close()));
  dialog.addEventListener('close', () => {
    if (!dialogReturnFocus?.closest('[hidden]') && !dialogs.some((item) => item.open)) dialogReturnFocus?.focus({ preventScroll: true });
  });
});

function showNewLife() {
  const saved = store.inspectSave();
  const blockedMessages = {
    corrupt: 'Dein Spielstand ist beschädigt und wird nicht überschrieben. Prüfe unter „Spielstände“, ob eine Sicherung verfügbar ist.',
    unsupported: 'Dein Spielstand gehört zu einer anderen Version und bleibt unverändert.',
    unavailable: 'Der lokale Speicher ist nicht erreichbar. Ein neues Leben kann erst beginnen, wenn Speichern möglich ist.',
  };
  $('#replace-label').hidden = !saved.canContinue;
  $('#replace-save').checked = false;
  $('#replace-save').required = saved.canContinue;
  $('#begin-life').disabled = Boolean(blockedMessages[saved.status]);
  formError('#new-life-error', blockedMessages[saved.status] ?? '');
  showDialog($('#new-life-dialog'));
  $('#player-name').focus();
}

function renderVillage(state) {
  if (!state) return;
  $('#village-greeting').textContent = state.phase === 'complete'
    ? `${state.player.name}, dein Dach steht. Marcus wird sich an deine Hilfe erinnern. Diesen Anfang kannst du jederzeit wieder aufnehmen.`
    : `${state.player.name}, vor dir liegt Valdora. Für die erste Nacht brauchst du ein Dach. Der Dorfverwalter hat dir einen Bauplatz und Holz aus dem Vorrat am Waldrand zugesagt.`;
  $('#wood-value').textContent = state.resources.wood;
  $('#grain-value').textContent = state.resources.grain;
  $('#day-value').textContent = state.day;
  $('#current-objective').textContent = state.currentObjective;
  $('#shelter-state').textContent = state.shelter.built ? 'Ein Dach für die erste Nacht' : 'Unter freiem Himmel';
  $('#shelter-visual').toggleAttribute('hidden', !state.shelter.built);
  $('#plot-description').textContent = state.shelter.built ? 'Unterkunft errichtet · dein erster Besitz' : 'Genehmigter Grund · Material fehlt';
  $('#chapter-progress').textContent = `${state.dayProgress} / 3 Schritte`;
  const actions = $('#village-actions');
  actions.replaceChildren(...state.actions.map((action, i) => {
    const button = element('button', `village-action${action.completed ? ' completed' : ''}`);
    button.dataset.action = action.id;
    button.disabled = !action.enabled;
    const mark = element('span', '', action.completed ? '✓' : `0${i + 1}`);
    mark.setAttribute('aria-hidden', 'true');
    const label = element('span', '', action.label);
    label.append(element('small', '', action.completed ? 'In deiner Chronik festgehalten' : action.description));
    button.append(mark, label);
    button.addEventListener('click', () => {
      button.disabled = true;
      const result = store.performAction(action.id);
      if (!result.ok) {
        notify(result.message, true);
        renderVillage(store.getState());
        const restored = document.querySelector(`[data-action="${action.id}"]`);
        if (restored && !restored.disabled) restored.focus({ preventScroll: true });
        return;
      }
      renderVillage(result.state);
      refreshMenu();
      notify(result.message);
      const next = document.querySelector('.village-action:not(:disabled)');
      const focusTarget = next ?? $('#current-objective');
      focusTarget.tabIndex = next ? 0 : -1;
      focusTarget.focus({ preventScroll: true });
    });
    return button;
  }));
  $('#journal-list').replaceChildren(...state.journal.map((entry) => {
    const item = element('li');
    item.append(element('h3', '', entry.title), element('p', '', entry.text));
    return item;
  }));
}

function enterVillage(state) {
  renderVillage(state);
  mainMenu.hidden = true;
  village.hidden = false;
  document.body.classList.add('in-village');
  dialogs.forEach((dialog) => { if (dialog.open) dialog.close(); });
  window.scrollTo({ top: 0, behavior: 'instant' });
  $('#village-title').tabIndex = -1;
  $('#village-title').focus({ preventScroll: true });
}

function continueLife() {
  const result = store.continueLife();
  refreshMenu();
  if (!result.ok) {
    notify(result.message, true);
    if ($('#saves-dialog').open) renderSaves();
    return;
  }
  enterVillage(result.state);
}

function returnToMenu() {
  store.resetForMenu();
  village.hidden = true;
  mainMenu.hidden = false;
  document.body.classList.remove('in-village');
  refreshMenu();
  window.scrollTo({ top: 0, behavior: 'instant' });
  $('#continue-life').focus({ preventScroll: true });
}

function formatTime(value) {
  const date = new Date(value);
  return Number.isFinite(date.getTime()) ? new Intl.DateTimeFormat('de-AT', { dateStyle: 'medium', timeStyle: 'short' }).format(date) : 'Zeitpunkt unbekannt';
}

function renderSaves() {
  const saved = store.inspectSave();
  const container = $('#save-content');
  container.replaceChildren();
  const card = element('section', `save-card${saved.canContinue ? '' : ' empty'}`);
  if (saved.canContinue) {
    card.append(element('span', 'overline', 'DEIN AKTUELLES LEBEN'), element('h3', '', saved.summary.name), element('p', '', `Tag ${saved.summary.day} · ${phaseLabels[saved.summary.stage] ?? 'Valdora'}`), element('p', '', `Gespeichert am ${formatTime(saved.summary.updatedAt)}`));
    const load = element('button', 'solid-button', 'Dieses Leben fortsetzen →');
    load.addEventListener('click', continueLife);
    card.append(load);
  } else {
    const descriptions = {
      missing: ['Noch ungeschrieben.', 'Beginne ein neues Leben. Deine ersten Entscheidungen werden hier festgehalten.'],
      corrupt: ['Spielstand beschädigt.', 'Der gespeicherte Stand konnte nicht sicher gelesen werden. Er bleibt erhalten und wird nicht als neues Spiel geöffnet.'],
      unsupported: ['Andere Spielversion.', 'Dieser Stand gehört zu einer nicht unterstützten Version und wird nicht überschrieben.'],
      unavailable: ['Speicher nicht erreichbar.', 'Erlaube diesem Browser das lokale Speichern, um dein Leben sicher fortzusetzen.'],
    };
    const [title, copy] = descriptions[saved.status] ?? ['Nicht verfügbar.', 'Bitte versuche es erneut.'];
    card.append(element('span', 'empty-mark', '◇'), element('h3', '', title), element('p', '', copy));
  }
  container.append(card);
  if (saved.backup.status === 'valid') {
    const backup = element('section', 'backup-card');
    backup.append(element('h3', '', 'Vorheriger Sicherungsstand'), element('p', '', `${saved.backup.summary.name} · Tag ${saved.backup.summary.day} · ${formatTime(saved.backup.summary.updatedAt)}`), element('p', '', 'Wiederherstellen ersetzt den aktuellen Fortschritt durch diesen vorherigen Stand. Ein beschädigtes Original wird vorher gesichert.'));
    const confirm = element('label', 'check-row');
    const checkbox = element('input');
    checkbox.type = 'checkbox';
    confirm.append(checkbox, element('span', '', 'Ich möchte ausdrücklich zu diesem Sicherungsstand zurückkehren.'));
    const restore = element('button', 'outline-button', 'Sicherungsstand wiederherstellen');
    restore.disabled = true;
    checkbox.addEventListener('change', () => { restore.disabled = !checkbox.checked || saved.status === 'unsupported' || saved.status === 'unavailable'; });
    restore.addEventListener('click', () => {
      if (!checkbox.checked) return;
      const result = store.restoreBackup();
      notify(result.message, !result.ok);
      refreshMenu();
      renderSaves();
      if (result.ok && !village.hidden) renderVillage(result.state);
    });
    backup.append(confirm, restore);
    container.append(backup);
  }
}

$('#new-life').addEventListener('click', showNewLife);
$('#continue-life').addEventListener('click', continueLife);
$('#open-saves').addEventListener('click', () => { renderSaves(); showDialog($('#saves-dialog')); });
$('#open-settings').addEventListener('click', () => { applySettings(); formError('#settings-error'); showDialog($('#settings-dialog')); });
$('#return-menu').addEventListener('click', returnToMenu);
$('#replay-intro').addEventListener('click', () => startIntro());
$('#skip-intro').addEventListener('click', finishIntro);
$('.brand-mark').addEventListener('click', (event) => { event.preventDefault(); if (!village.hidden) returnToMenu(); else $('#new-life').focus(); });
$('.skip-link').addEventListener('click', (event) => { event.preventDefault(); if (introActive) finishIntro(); else if (!village.hidden) returnToMenu(); else $('#new-life').focus(); });
$('#new-life-form').addEventListener('submit', (event) => {
  event.preventDefault();
  if (!event.currentTarget.reportValidity()) return;
  const result = store.startNewLife($('#player-name').value, { replace: $('#replace-save').checked });
  if (!result.ok) { formError('#new-life-error', result.message); return; }
  formError('#new-life-error');
  refreshMenu();
  enterVillage(result.state);
  notify(result.message);
});
$('#text-scale').addEventListener('change', (event) => setSettings({ textScale: Number(event.target.value) }));
$('#high-contrast').addEventListener('change', (event) => setSettings({ highContrast: event.target.checked }));
$('#reduced-motion').addEventListener('change', (event) => setSettings({ reducedMotion: event.target.checked }));
$('#master-volume').addEventListener('input', (event) => setSettings({ masterVolume: Number(event.target.value) / 100 }, { activateSound: true }));
$('#toggle-audio').addEventListener('click', () => {
  if (audio && settings.masterVolume > 0 && audio.context.state === 'running') setSettings({ masterVolume: 0 });
  else if (setSettings({ masterVolume: settings.masterVolume || 0.35 })) void activateAudio();
});

document.addEventListener('keydown', (event) => {
  if (introActive && ['Escape', 'Enter', ' '].includes(event.key)) { event.preventDefault(); finishIntro(); return; }
  if (event.key === 'Escape' && !dialogs.some((dialog) => dialog.open) && !village.hidden) { event.preventDefault(); returnToMenu(); }
  const inMenu = !mainMenu.hidden && !introActive && !dialogs.some((dialog) => dialog.open);
  if (inMenu && ['ArrowDown', 'ArrowUp'].includes(event.key)) {
    event.preventDefault();
    const options = [...mainMenu.querySelectorAll('button:not(:disabled)')];
    const index = options.indexOf(document.activeElement);
    const next = event.key === 'ArrowDown' ? (index + 1) % options.length : (index <= 0 ? options.length - 1 : index - 1);
    options[next]?.focus();
  }
});

motionPreference.addEventListener?.('change', applySettings);
window.addEventListener('storage', () => {
  applySettings();
  refreshMenu();
  if ($('#saves-dialog').open) renderSaves();
  if (!village.hidden) notify('Der gespeicherte Stand wurde in einem anderen Fenster geändert. Kehre zum Menü zurück und lade ihn erneut.', true);
});
window.addEventListener('pointermove', (event) => {
  if (reducedMotion() || event.pointerType !== 'mouse' || document.hidden || innerWidth < 760) return;
  pendingPointer = { x: (event.clientX / innerWidth - 0.5) * -6, y: (event.clientY / innerHeight - 0.5) * -3 };
  if (pointerFrame) return;
  pointerFrame = requestAnimationFrame(() => {
    if (pendingPointer) {
      document.documentElement.style.setProperty('--parallax-x', `${pendingPointer.x}px`);
      document.documentElement.style.setProperty('--parallax-y', `${pendingPointer.y}px`);
    }
    pointerFrame = 0;
  });
}, { passive: true });

// Standard Gamepad mapping: D-pad/left stick moves focus; A confirms; B returns.
// Naming still uses the device's text input, just like the keyboard path.
function gamepadInput(intent) {
  if (intent === 'back') {
    if (introActive) finishIntro();
    else if (dialogs.some((dialog) => dialog.open)) dialogs.find((dialog) => dialog.open).close();
    else if (!village.hidden) returnToMenu();
    return;
  }
  if (introActive) { if (intent === 'confirm') finishIntro(); return; }
  const scope = dialogs.find((dialog) => dialog.open) ?? (village.hidden ? mainMenu : village);
  const options = [...scope.querySelectorAll('button:not(:disabled), input:not(:disabled), select:not(:disabled)')].filter((node) => !node.closest('[hidden]') && node.getClientRects().length);
  const active = document.activeElement;
  if (intent === 'confirm') {
    if (options.includes(active)) { if (active.tagName === 'INPUT' && active.type === 'text') active.focus(); else active.click(); }
    else options[0]?.focus();
  } else if (intent === 'left' || intent === 'right') {
    const change = intent === 'right' ? 1 : -1;
    if (active?.type === 'range') {
      active.value = String(Math.max(Number(active.min), Math.min(Number(active.max), Number(active.value) + change * 5)));
      active.dispatchEvent(new Event('input', { bubbles: true }));
    } else if (active?.tagName === 'SELECT') {
      active.selectedIndex = Math.max(0, Math.min(active.options.length - 1, active.selectedIndex + change));
      active.dispatchEvent(new Event('change', { bubbles: true }));
    }
  } else {
    const index = options.indexOf(active);
    const next = intent === 'down' ? (index + 1) % options.length : (index <= 0 ? options.length - 1 : index - 1);
    options[next]?.focus();
  }
}

function pollGamepads() {
  gamepadFrame = 0;
  if (document.hidden) return;
  const pads = navigator.getGamepads?.() ?? [];
  let connected = false;
  for (const pad of pads) {
    if (!pad || pad.mapping !== 'standard') continue;
    connected = true;
    const current = {
      confirm: pad.buttons[0]?.pressed,
      back: pad.buttons[1]?.pressed,
      up: pad.buttons[12]?.pressed || pad.axes[1] < -0.6,
      down: pad.buttons[13]?.pressed || pad.axes[1] > 0.6,
      left: pad.buttons[14]?.pressed || pad.axes[0] < -0.6,
      right: pad.buttons[15]?.pressed || pad.axes[0] > 0.6,
    };
    const previous = gamepadLast.get(pad.index) ?? {};
    for (const [intent, pressed] of Object.entries(current)) if (pressed && !previous[intent]) gamepadInput(intent);
    gamepadLast.set(pad.index, current);
  }
  if (connected) gamepadFrame = requestAnimationFrame(pollGamepads);
}
window.addEventListener('gamepadconnected', () => { if (!gamepadFrame) gamepadFrame = requestAnimationFrame(pollGamepads); });
window.addEventListener('gamepaddisconnected', (event) => gamepadLast.delete(event.gamepad.index));
document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    if (audio?.context.state === 'running') void audio.context.suspend();
    if (gamepadFrame) cancelAnimationFrame(gamepadFrame);
    gamepadFrame = 0;
  } else {
    updateAudioLabel();
    if (!gamepadFrame) gamepadFrame = requestAnimationFrame(pollGamepads);
  }
});
window.addEventListener('pagehide', () => {
  clearIntroTimers();
  clearTimeout(toastTimer);
  if (gamepadFrame) cancelAnimationFrame(gamepadFrame);
  if (pointerFrame) cancelAnimationFrame(pointerFrame);
  gamepadFrame = 0;
  pointerFrame = 0;
  if (audio) {
    audio.oscillators.forEach((oscillator) => oscillator.stop());
    void audio.context.close();
    audio = null;
  }
});
window.addEventListener('pageshow', (event) => {
  if (!event.persisted) return;
  if (introActive) finishIntro();
  else if (!intro.hidden) {
    intro.hidden = true;
    backgroundSurfaces.forEach((node) => { node.inert = false; });
  }
  applySettings();
  refreshMenu();
});

applySettings();
refreshMenu();
startIntro({ firstVisit: true });
