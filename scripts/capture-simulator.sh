#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' 'Een echte iOS-simulatorschermafbeelding vereist macOS en Xcode.' >&2
  exit 1
fi

# Node is aanwezig op de gekozen GitHub-runner. Elke simctl-opdracht heeft een timeout.
node --input-type=module - "$project_dir" <<'JS'
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

const root = process.argv[2];
const output = path.join(root, 'build/screenshots');
const app = path.join(root, 'build/DerivedData/Build/Products/Release-iphonesimulator/Stemstroom.app');
const bundle = 'be.personal.Stemstroom';
const deadline = Date.now() + 300_000;
const diagnosticDeadline = deadline + 60_000;
const report = ['Native simulatorcontrole; geen microfoon-, herkennings- of duurtest.', `Gestart: ${new Date().toISOString()}`];
mkdirSync(output, { recursive: true });
const reportPath = path.join(output, 'simulator-report.txt');
function saveReport() { writeFileSync(reportPath, report.join('\n') + '\n'); }
saveReport();

function run(command, args, limit = 30_000, diagnostic = false) {
  const remaining = (diagnostic ? diagnosticDeadline : deadline) - Date.now();
  if (remaining <= 0) throw new Error('De simulatorcontrole overschreed vijf minuten.');
  console.log(`> ${command} ${args.join(' ')}`);
  const result = spawnSync(command, args, {
    cwd: root, encoding: 'utf8', timeout: Math.min(limit, remaining), maxBuffer: 10 * 1024 * 1024,
  });
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) {
    throw new Error(`${command} ${args.join(' ')}: ${result.error.message}; stdout: ${result.stdout}; stderr: ${result.stderr}`);
  }
  if (result.status !== 0) throw new Error(`${command} eindigde met status ${result.status}: ${result.stdout}`);
  return result.stdout;
}
function version(value) {
  if (!/^\d+(\.\d+)*$/.test(value)) throw new Error(`Onverwachte systeemversie: ${value}`);
  return value.split('.').map(Number);
}
function supports(runtime, minimum) {
  const left = version(runtime);
  const right = version(minimum);
  for (let index = 0; index < Math.max(left.length, right.length); index++) {
    const runtimePart = index < left.length ? left[index] : 0;
    const minimumPart = index < right.length ? right[index] : 0;
    if (runtimePart !== minimumPart) return runtimePart > minimumPart;
  }
  return true;
}

let device;
let bootedHere = false;
try {
  if (!existsSync(app)) throw new Error('De gebouwde simulatorapp ontbreekt. Voer eerst build-ios.sh uit.');
  // Alleen de lokale simulatorapp krijgt een ad-hoc-handtekening; geen team of certificaat nodig.
  run('/usr/bin/codesign', ['--force', '--sign', '-', '--timestamp=none', app]);
  run('/usr/bin/codesign', ['--verify', '--strict', app]);
  const minimum = run('/usr/libexec/PlistBuddy', ['-c', 'Print :MinimumOSVersion', path.join(app, 'Info.plist')]).trim();
  const runtimes = JSON.parse(run('xcrun', ['simctl', 'list', 'runtimes', '--json'])).runtimes
    .filter(runtime => runtime.isAvailable && runtime.identifier.includes('.iOS-'))
    .sort((left, right) => right.version.localeCompare(left.version, 'en', { numeric: true }));
  const devices = JSON.parse(run('xcrun', ['simctl', 'list', 'devices', 'available', '--json'])).devices;
  let selectedRuntime;
  for (const runtime of runtimes) {
    if (!runtime.isAvailable || !runtime.identifier.includes('.iOS-') || !supports(runtime.version, minimum)) continue;
    if (!(runtime.identifier in devices)) continue;
    device = devices[runtime.identifier].find(candidate => candidate.isAvailable && candidate.name.startsWith('iPhone'));
    if (device) { selectedRuntime = runtime; break; }
  }
  if (!device) throw new Error(`Geen beschikbare iPhone-simulator met iOS ${minimum} of nieuwer.`);
  report.push(`Toestel: ${device.name}`, `UDID: ${device.udid}`, `Runtime: ${selectedRuntime.name} (${selectedRuntime.version})`);
  saveReport();
  if (device.state !== 'Booted') {
    run('xcrun', ['simctl', 'boot', device.udid], 45_000);
    bootedHere = true;
  }
  run('xcrun', ['simctl', 'bootstatus', device.udid, '-b'], 120_000);
  run('xcrun', ['simctl', 'install', device.udid, app], 45_000);
  const launch = run('xcrun', ['simctl', 'launch', '--terminate-running-process', device.udid, bundle, '-AppleLanguages', '(nl)', '-AppleLocale', 'nl_BE'], 90_000);
  report.push(`Startresultaat: ${launch.trim()}`);
  await delay(5_000);
  const processes = run('xcrun', ['simctl', 'spawn', device.udid, 'launchctl', 'list']);
  if (!processes.split('\n').some(line => /^\d+\s/.test(line.trim()) && line.includes(`UIKitApplication:${bundle}`))) {
    throw new Error('De app heeft na het starten geen actief simulatorproces.');
  }
  const screenshot = path.join(output, 'Stemstroom.png');
  run('xcrun', ['simctl', 'io', device.udid, 'screenshot', '--type=png', screenshot]);
  const png = readFileSync(screenshot);
  if (png.length < 24 || !png.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
    throw new Error('Het resultaat is geen geldige PNG-header.');
  }
  const width = png.readUInt32BE(16);
  const height = png.readUInt32BE(20);
  if (width === 0 || height === 0) throw new Error('De schermafbeelding heeft geen afmetingen.');
  report.push(`Schermafbeelding: Stemstroom.png (${width} × ${height})`, 'Vastgelegd; visuele inspectie nog vereist. Opname is niet gestart.');
} catch (error) {
  report.push(`Niet voltooid: ${error.message}`);
  console.error(error.message);
  process.exitCode = 1;
  saveReport();
  if (device) {
    // Bewaar de echte toestand vóór shutdown: dit kan een vergrendel- of crashscherm zijn.
    try {
      run('xcrun', ['simctl', 'io', device.udid, 'screenshot', '--type=png', path.join(output, 'Simulator-bij-fout.png')], 20_000, true);
      report.push('Diagnostische screenshot: Simulator-bij-fout.png; dit bewijst geen werkend appscherm.');
    } catch (diagnosticError) { report.push(`Screenshot bij fout: ${diagnosticError.message}`); }
    for (const [filename, args, limit] of [
      ['simulator-processen.txt', ['simctl', 'spawn', device.udid, 'launchctl', 'list'], 10_000],
      ['simulator-log.txt', ['simctl', 'spawn', device.udid, 'log', 'show', '--last', '3m', '--style', 'compact', '--predicate', 'process == "Stemstroom" OR (process == "SpringBoard" AND eventMessage CONTAINS "Stemstroom") OR eventMessage CONTAINS "be.personal.Stemstroom"'], 15_000],
    ]) {
      try { writeFileSync(path.join(output, filename), run('xcrun', args, limit, true)); }
      catch (diagnosticError) { report.push(`${filename}: ${diagnosticError.message}`); }
    }
  }
} finally {
  if (bootedHere) {
    try { run('xcrun', ['simctl', 'shutdown', device.udid], 10_000, true); }
    catch (error) { report.push(`Opruimen simulator: ${error.message}`); }
  }
  saveReport();
  console.log(report.join('\n'));
}
JS
