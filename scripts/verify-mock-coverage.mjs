import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const defaultRoot = resolve(scriptDir, '..');
const staticDriver = 'device-ui-mock-suite.ps1';

export function parseDeclaredList(source, name) {
  const match = source.match(new RegExp(
    `${name}\\s*:\\s*string\\[\\]\\s*=\\s*\\[([\\s\\S]*?)\\]`,
  ));
  if (!match) return [];
  return [...match[1].matchAll(/'([^']+)'/g)].map((row) => row[1]);
}

export function missingCoverage(declared, covered) {
  const available = new Set(covered);
  return declared.filter((value, index) =>
    !available.has(value) || declared.indexOf(value) !== index);
}

function collectPairs(source) {
  const pairs = [];
  for (const match of stripPowerShellComments(source).matchAll(
    /Screen\s*=\s*'([^']+)'\s*;\s*State\s*=\s*'([^']+)'/gi,
  )) {
    pairs.push({ screen: match[1], state: match[2] });
  }
  return pairs;
}

function collectNamedValues(source, name) {
  const values = [];
  const expression = new RegExp(
    `(?:${name}\\s*=\\s*|\\s+-${name}\\s+)'([^']+)'`,
    'g',
  );
  for (const match of stripPowerShellComments(source).matchAll(expression)) {
    values.push(match[1]);
  }
  return values;
}

function uniqueValues(values) {
  const seen = new Set();
  const duplicates = [];
  for (const value of values) {
    if (seen.has(value) && !duplicates.includes(value)) duplicates.push(value);
    seen.add(value);
  }
  return duplicates;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function stripPowerShellComments(source) {
  let output = '';
  let quote = '';
  for (let index = 0; index < source.length; index++) {
    const char = source[index];
    const next = source[index + 1];

    if (quote === "'") {
      output += char;
      if (char === "'" && next === "'") {
        output += next;
        index++;
      } else if (char === "'") {
        quote = '';
      }
      continue;
    }
    if (quote === '"') {
      output += char;
      if (char === '`' && next !== undefined) {
        output += next;
        index++;
      } else if (char === '"') {
        quote = '';
      }
      continue;
    }

    if (char === '<' && next === '#') {
      while (index + 1 < source.length &&
          !(source[index] === '#' && source[index + 1] === '>')) {
        if (source[index] === '\n') output += '\n';
        index++;
      }
      index++;
      continue;
    }
    if (char === '#') {
      while (index < source.length && source[index] !== '\n') index++;
      if (source[index] === '\n') output += '\n';
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
      output += char;
      continue;
    }
    output += char;
  }
  return output;
}

function stateArguments(source) {
  const values = [];
  const sanitized = stripPowerShellComments(source);
  const argument = /(?<![\w-])-State(?:\s*:\s*|\s+)(?:'([^']+)'|"([^"]+)")/gi;
  const fixtureState = /\$[\w-]*FixtureState\s*=\s*(?:'([^']+)'|"([^"]+)")/gi;
  const scenarioState = /(?:^|[\r\n])\s*State\s*=\s*(?:'([^']+)'|"([^"]+)")/gi;
  for (const match of sanitized.matchAll(argument)) {
    values.push(match[1] ?? match[2]);
  }
  for (const match of sanitized.matchAll(fixtureState)) {
    values.push(match[1] ?? match[2]);
  }
  for (const match of sanitized.matchAll(scenarioState)) {
    values.push(match[1] ?? match[2]);
  }
  return values;
}

export function driverMentionsState(source, state) {
  const sanitized = stripPowerShellComments(source);
  return collectPairs(source).some((pair) => pair.state === state) ||
    stateArguments(sanitized).includes(state);
}

export function stripPowerShellFunctionBodies(source) {
  const sanitized = stripPowerShellComments(source);
  let output = '';
  let cursor = 0;
  const declaration = /\bfunction\s+[\w-]+\s*(?:\([^)]*\))?\s*\{/gi;
  let match;
  while ((match = declaration.exec(sanitized))) {
    if (match.index < cursor) continue;
    output += sanitized.slice(cursor, match.index);
    let depth = 1;
    let quote = '';
    let index = match.index + match[0].length;
    for (; index < sanitized.length && depth > 0; index++) {
      const char = sanitized[index];
      const next = sanitized[index + 1];
      if (quote === "'") {
        if (char === "'" && next === "'") index++;
        else if (char === "'") quote = '';
      } else if (quote === '"') {
        if (char === '`') index++;
        else if (char === '"') quote = '';
      } else if (char === "'" || char === '"') {
        quote = char;
      } else if (char === '{') {
        depth++;
      } else if (char === '}') {
        depth--;
      }
    }
    cursor = index;
    declaration.lastIndex = cursor;
  }
  return output + sanitized.slice(cursor);
}

export function analyzeInteractionDriver(source) {
  const sourceWithoutComments = stripPowerShellComments(source);
  const commands = stripPowerShellFunctionBodies(source);
  return {
    hasInteractionCommand:
      /\buiInput\s+(?:click|inputText|text|keyEvent|swipe|drag|touch)\b/i.test(commands) ||
      /(?<![\w-])(?:Invoke-(?:Click|Tap|Control)|Send-(?:Token|Message))\b/i.test(commands),
    hasAssertionCommand:
      /(?<![\w-])Query-Node\b/i.test(commands) ||
      /\bdevice-ui-(?:layout|material)-assert\.py\b/i.test(commands) ||
      /\bAssert-[A-Za-z][\w-]*\b/i.test(commands),
    referencedStates: [...new Set(stateArguments(sourceWithoutComments))],
  };
}

export function validateMockFeatureManifest(
  manifest,
  declaredScreens,
  declaredStates,
  driverSources,
  e2eText,
) {
  const failures = [];
  const invalidFeatures = new Set();
  const featureIds = [];
  const registeredScreens = [];
  const registeredStates = [];
  const features = Array.isArray(manifest?.features) ? manifest.features : [];

  if (manifest?.schemaVersion !== 1) {
    failures.push('Mock feature manifest schemaVersion must be 1');
  }
  if (!features.length) failures.push('Mock feature manifest has no features');

  for (const [index, feature] of features.entries()) {
    const id = typeof feature?.id === 'string' ? feature.id.trim() : '';
    const featureName = id || `#${index + 1}`;
    const arrays = {};
    for (const field of ['screens', 'states', 'drivers', 'e2eIds']) {
      const value = feature?.[field];
      if (!Array.isArray(value) || value.length === 0 ||
          value.some((entry) => typeof entry !== 'string' || !entry.trim())) {
        failures.push(`${featureName}: ${field} must be a non-empty string array`);
        invalidFeatures.add(featureName);
        arrays[field] = [];
      } else {
        arrays[field] = value;
      }
    }

    if (!id) {
      failures.push(`${featureName}: id is required`);
      invalidFeatures.add(featureName);
    } else {
      featureIds.push(id);
    }

    const screens = arrays.screens;
    const states = arrays.states;
    const drivers = arrays.drivers;
    registeredScreens.push(...screens);
    registeredStates.push(...states);

    for (const screen of screens) {
      if (!declaredScreens.includes(screen)) {
        failures.push(`${featureName}: unknown screen ${screen}`);
        invalidFeatures.add(featureName);
      }
    }

    for (const state of states) {
      if (!declaredStates.includes(state)) {
        failures.push(`${featureName}: unknown state ${state}`);
        invalidFeatures.add(featureName);
      }
      const referenced = drivers.some((driver) =>
        typeof driverSources[driver] === 'string' &&
        driverMentionsState(driverSources[driver], state));
      if (!referenced) {
        failures.push(`${featureName}: state ${state} has no selected driver reference`);
        invalidFeatures.add(featureName);
      }
    }

    for (const driver of drivers) {
      if (typeof driverSources[driver] !== 'string') {
        failures.push(`${featureName}: driver not found: ${driver}`);
        invalidFeatures.add(featureName);
      }
    }

    if (feature?.requiresInteraction === true) {
      const interactionDrivers = drivers.filter((driver) =>
        driver !== staticDriver && typeof driverSources[driver] === 'string');
      if (!interactionDrivers.length) {
        failures.push(
          `${featureName}: interactive feature has no interaction driver (non-static driver required)`,
        );
        invalidFeatures.add(featureName);
      }
      for (const driver of interactionDrivers) {
        const analysis = analyzeInteractionDriver(driverSources[driver]);
        if (!analysis.hasInteractionCommand) {
          failures.push(
            `${featureName}: interaction driver ${driver} has no interaction command`,
          );
          invalidFeatures.add(featureName);
        }
        if (!analysis.hasAssertionCommand) {
          failures.push(
            `${featureName}: interaction driver ${driver} has no assertion command`,
          );
          invalidFeatures.add(featureName);
        }
        if (!analysis.referencedStates.some((state) => states.includes(state))) {
          failures.push(
            `${featureName}: interaction driver ${driver} does not reference a feature state`,
          );
          invalidFeatures.add(featureName);
        }
      }
    }

    for (const e2eId of arrays.e2eIds) {
      const row = new RegExp(`\\|\\s*${escapeRegExp(e2eId)}\\s*\\|`);
      if (!row.test(e2eText)) {
        failures.push(`${featureName}: E2E table entry not found: ${e2eId}`);
        invalidFeatures.add(featureName);
      }
    }
  }

  for (const duplicate of uniqueValues(featureIds)) {
    failures.push(`duplicate feature id: ${duplicate}`);
  }

  const missingScreens = missingCoverage(declaredScreens, registeredScreens);
  const missingStates = missingCoverage(declaredStates, registeredStates);
  for (const screen of missingScreens) {
    failures.push(`screen missing from Mock feature manifest: ${screen}`);
  }
  for (const state of missingStates) {
    failures.push(`state missing from Mock feature manifest: ${state}`);
  }

  return {
    ok: failures.length === 0,
    features: {
      covered: featureIds.filter((id) => !invalidFeatures.has(id)).length,
      total: features.length,
      missing: [...invalidFeatures],
    },
    screens: {
      covered: declaredScreens.length - missingScreens.length,
      total: declaredScreens.length,
      missing: missingScreens,
    },
    states: {
      covered: declaredStates.length - missingStates.length,
      total: declaredStates.length,
      missing: missingStates,
    },
    failures,
  };
}

export function verifyMockCoverage(root = defaultRoot) {
  const fixturePath = join(
    root,
    'harmony/entry/src/main/ets/services/NativeUiFixture.ets',
  );
  const fixture = readFileSync(fixturePath, 'utf8');
  const screens = parseDeclaredList(fixture, 'screens');
  const states = parseDeclaredList(fixture, 'states');
  const suitePath = join(root, 'scripts/device-ui-mock-suite.ps1');
  const suite = readFileSync(suitePath, 'utf8');
  const suitePairs = collectPairs(suite);

  const scriptNames = readdirSync(join(root, 'scripts'))
    .filter((name) => name.startsWith('device-ui-') &&
      name.endsWith('-e2e.ps1'));
  const interactionSources = scriptNames.map((name) =>
    readFileSync(join(root, 'scripts', name), 'utf8'));
  const allDriverSources = [suite, ...interactionSources];
  const driverSources = {
    [staticDriver]: suite,
  };
  scriptNames.forEach((name, index) => {
    driverSources[name] = interactionSources[index];
  });

  const suiteScreens = suitePairs.map((pair) => pair.screen);
  const suiteStates = suitePairs.map((pair) => pair.state);
  const interactionScreens = allDriverSources.flatMap((source) =>
    collectNamedValues(source, 'Screen'));
  const interactionStates = allDriverSources.flatMap((source) =>
    collectNamedValues(source, 'State'));

  const missingScreens = missingCoverage(screens, suiteScreens);
  const missingStates = missingCoverage(states,
    [...suiteStates, ...interactionStates]);
  const failures = [];

  if (!screens.length) failures.push('no fixture screens were declared');
  if (!states.length) failures.push('no fixture states were declared');
  if (missingScreens.length) {
    failures.push(`screens without device capture: ${missingScreens.join(', ')}`);
  }
  if (missingStates.length) {
    failures.push(`states without capture or interaction: ${missingStates.join(', ')}`);
  }

  const manifestPath = join(
    root,
    'docs/testing/mock-feature-manifest.json',
  );
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const testingDir = join(root, 'docs/testing');
  const e2eText = readdirSync(testingDir)
    .filter((name) => name.endsWith('.md'))
    .map((name) => readFileSync(join(testingDir, name), 'utf8'))
    .join('\n');
  const featureResult = validateMockFeatureManifest(
    manifest,
    screens,
    states,
    driverSources,
    e2eText,
  );
  failures.push(...featureResult.failures);

  const entryProfile = readFileSync(
    join(root, 'harmony/entry/build-profile.json5'), 'utf8');
  const exampleProfile = readFileSync(
    join(root, 'harmony/build-profile.example.json5'), 'utf8');
  const buildScript = readFileSync(
    join(root, 'scripts/build-harmony.ps1'), 'utf8');
  const mockScript = readFileSync(
    join(root, 'scripts/device-ui-mock.ps1'), 'utf8');
  const communityCapabilities = readFileSync(
    join(root, 'harmony/entry/src/community/ProductCapabilities.ets'), 'utf8');
  const storeCapabilities = readFileSync(
    join(root, 'harmony/entry/src/store/ProductCapabilities.ets'), 'utf8');
  const mockCapabilities = readFileSync(
    join(root, 'harmony/entry/src/mock/ProductCapabilities.ets'), 'utf8');

  if (!entryProfile.includes('"name": "mock"') ||
      !entryProfile.includes('./src/mock')) {
    failures.push('entry build profile is missing the mock target');
  }
  if (!exampleProfile.includes('"name": "mock"')) {
    failures.push('example build profile is missing the mock product');
  }
  if (!/ValidateSet\('community','default','store','mock'\)/.test(buildScript)) {
    failures.push('build-harmony.ps1 does not accept the mock product');
  }
  if (!mockScript.includes('-Product mock')) {
    failures.push('device-ui-mock.ps1 does not build the mock product');
  }
  if (!mockScript.includes(
    'entry-mock-signed.hap',
  )) {
    failures.push('device-ui-mock.ps1 does not use the mock HAP');
  }
  for (const source of [communityCapabilities, storeCapabilities]) {
    if (!/supportsMockFixtures:\s*boolean\s*=\s*false/.test(source)) {
      failures.push('community/store capability must not auto-select fixtures');
    }
  }
  if (!/supportsMockFixtures:\s*boolean\s*=\s*true/.test(mockCapabilities)) {
    failures.push('mock capability must auto-select fixtures');
  }

  return {
    ok: failures.length === 0,
    screens: {
      covered: screens.length - missingScreens.length,
      total: screens.length,
      missing: missingScreens,
    },
    states: {
      covered: states.length - missingStates.length,
      total: states.length,
      missing: missingStates,
    },
    features: featureResult.features,
    registry: {
      screens: featureResult.screens,
      states: featureResult.states,
    },
    suitePairs: suitePairs.length,
    interactionDrivers: scriptNames,
    failures: [...new Set(failures)],
  };
}

function printResult(result) {
  const screenPercent = result.screens.total
    ? result.screens.covered * 100 / result.screens.total : 0;
  const statePercent = result.states.total
    ? result.states.covered * 100 / result.states.total : 0;
  const featurePercent = result.features.total
    ? result.features.covered * 100 / result.features.total : 0;
  console.log(`Mock mapping coverage - screens: ${result.screens.covered}/${result.screens.total} (${screenPercent.toFixed(0)}%)`);
  console.log(`Mock mapping coverage - states: ${result.states.covered}/${result.states.total} (${statePercent.toFixed(0)}%)`);
  console.log(`Mock mapping coverage - registered features: ${result.features.covered}/${result.features.total} (${featurePercent.toFixed(0)}%)`);
  console.log(`Static capture pairs: ${result.suitePairs}`);
  console.log(`Interaction drivers: ${result.interactionDrivers.join(', ')}`);
  if (!result.ok) {
    for (const failure of result.failures) console.error(`- ${failure}`);
    process.exitCode = 1;
    return;
  }
  console.log('Mock feature mapping coverage: 100% (registration only; execution requires evidence validation)');
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  printResult(verifyMockCoverage());
}
