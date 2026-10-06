// Alleen projectstructuur. Dit compileert geen Swift en test geen transcriptie.
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = fileURLToPath(new URL('../', import.meta.url));
const projectText = readFileSync(path.join(projectRoot, 'Stemstroom.xcodeproj/project.pbxproj'), 'utf8');

function parseOpenStep(source) {
  const scanner = /\s+|\/\*[\s\S]*?\*\/|\/\/[^\n]*|"(?:\\.|[^"\\])*"|[{}()=;,]|[^{}\s()=;,"]+/gy;
  const tokens = [];
  let match;
  let end = 0;
  while ((match = scanner.exec(source))) {
    end = scanner.lastIndex;
    if (!/^\s|^\/\*|^\/\//.test(match[0])) tokens.push(match[0]);
  }
  assert.equal(end, source.length, 'Ongeldig teken in project');
  let index = 0;
  function expect(token) {
    assert.equal(tokens[index++], token, `Verwacht ${token}`);
  }
  function value() {
    if (tokens[index] === '{') {
      index++;
      const dictionary = Object.create(null);
      while (tokens[index] !== '}') {
        const key = value();
        assert.equal(typeof key, 'string');
        assert.ok(!(key in dictionary), `Dubbele sleutel: ${key}`);
        expect('=');
        dictionary[key] = value();
        expect(';');
      }
      index++;
      return dictionary;
    }
    if (tokens[index] === '(') {
      index++;
      const values = [];
      while (tokens[index] !== ')') {
        values.push(value());
        if (tokens[index] !== ')') expect(',');
      }
      index++;
      return values;
    }
    const token = tokens[index++];
    assert.ok(token && !/^[{}()=;,]$/.test(token), 'Waarde ontbreekt');
    return token[0] === '"' ? JSON.parse(token) : token;
  }
  const project = value();
  assert.equal(index, tokens.length, 'Extra tokens na het project');
  return project;
}

function checkProject(project) {
  const objects = project.objects;
  function checkReferences(value) {
    if (typeof value === 'string' && /^[A-F0-9]{24}$/.test(value)) {
      assert.ok(objects[value], `Ontbrekend object: ${value}`);
    } else if (value && typeof value === 'object') {
      Object.values(value).forEach(checkReferences);
    }
  }
  checkReferences(project);

  const filenames = new Map();
  function visit(id, directory) {
    const object = objects[id];
    assert.ok(object, `Ontbrekend object: ${id}`);
    if (object.sourceTree === 'BUILT_PRODUCTS_DIR') return;
    assert.equal(object.sourceTree, '<group>');
    // Een PBXGroup zonder path erft volgens het projectformaat de oudermap.
    const ownPath = 'path' in object ? path.join(directory, object.path) : directory;
    if (object.isa === 'PBXGroup') {
      object.children.forEach(child => visit(child, ownPath));
    } else {
      assert.ok(existsSync(ownPath), `Ontbrekend bestand: ${ownPath}`);
      filenames.set(id, ownPath);
    }
  }
  const root = objects[project.rootObject];
  visit(root.mainGroup, projectRoot);
  assert.equal(root.targets.length, 1, 'Precies één appdoel verwacht');
  const target = objects[root.targets[0]];
  assert.equal(target.name, 'Stemstroom');
  const phases = target.buildPhases.map(id => objects[id]);
  const sourcePhase = phases.find(phase => phase.isa === 'PBXSourcesBuildPhase');
  assert.ok(sourcePhase, 'Bronfase ontbreekt');
  const sources = sourcePhase.files.map(id => filenames.get(objects[id].fileRef));
  assert.equal(sources.length, 7, 'Verwacht zeven Swift-bronnen');
  assert.equal(new Set(sources).size, 7, 'Dubbele Swift-bron');
  assert.ok(sources.every(source => typeof source === 'string' && source.endsWith('.swift')));

  const resources = phases.find(phase => phase.isa === 'PBXResourcesBuildPhase');
  assert.ok(resources, 'Resourcefase ontbreekt');
  assert.equal(resources.files.length, 1);
  assert.equal(filenames.get(objects[resources.files[0]].fileRef), path.join(projectRoot, 'App/PrivacyInfo.xcprivacy'));

  const scheme = readFileSync(path.join(projectRoot, 'Stemstroom.xcodeproj/xcshareddata/xcschemes/Stemstroom.xcscheme'), 'utf8');
  assert.ok(scheme.includes(`BlueprintIdentifier="${root.targets[0]}"`), 'Schema verwijst niet naar appdoel');
  return sources.length;
}

// IJk de controle vóór het oordeel over het echte project, zonder bestanden te wijzigen.
assert.throws(() => parseOpenStep(projectText.replace('archiveVersion = 1;', 'archiveVersion = 1')));
const brokenProject = parseOpenStep(projectText);
brokenProject.objects.A20000000000000000000001.path = 'BestaatNiet.swift';
assert.throws(() => checkProject(brokenProject), /Ontbrekend bestand/);

const count = checkProject(parseOpenStep(projectText));
console.log(`Projectstructuur: ${count} unieke Swift-bronnen; alle object- en bestandsverwijzingen geldig.`);
console.log('IJking: 2 bekend-foute projecten afgewezen. Geen Swift-compilatie, YAML-validatie of transcriptietest uitgevoerd.');
