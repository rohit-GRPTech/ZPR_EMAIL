import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import * as abaplint from '@abaplint/core';
import Ajv2020 from 'ajv/dist/2020.js';

const root = path.resolve(import.meta.dirname, '..');
const src = path.join(root, 'src');
const read = name => fs.readFileSync(path.join(src, name), 'utf8');
const catalog = JSON.parse(read('zpr_email.sajc.json'));
const template = JSON.parse(read('zpr_email.sajt.json'));
const log = JSON.parse(read('zpr_email.aplo.json'));
const ajv = new Ajv2020({allErrors:true, strict:false});
for (const kind of ['aplo','sajc','sajt']) {
  const schema = JSON.parse(fs.readFileSync(path.join(root,'tests/schemas',`${kind}-v1.json`),'utf8'));
  const validate = ajv.compile(schema);
  assert(validate(JSON.parse(read(`zpr_email.${kind}.json`))), JSON.stringify(validate.errors));
}
assert.equal(catalog.generalInformation.className, 'ZCL_PR_EMAIL_JOB');
assert.equal(template.generalInformation.catalogName, 'ZPR_EMAIL');
assert(log.subobjects.some(x => x.name === 'DISPATCH'));
assert(template.parameters.singleValueParameters.some(x => x.name === 'DRY_RUN' && x.value === 'X'));
const job = read('zcl_pr_email_job.clas.abap');
const params = [...job.split('ENDCLASS.')[0].matchAll(/^\s*DATA (\w+) TYPE/gmi)].map(x => x[1].toUpperCase());
assert.deepEqual(catalog.parameters.map(x => x.name).sort(), params.sort());
assert.equal(catalog.parameters.find(x => x.name === 'DRY_RUN').screenElement, 'checkbox');
assert(!catalog.parameters.find(x => x.name === 'APPROVAL_TASKS').mandatory);
for (const p of [...template.parameters.singleValueParameters, ...template.parameters.valueRangesParameters]) {
  assert(params.includes(p.name), `Template parameter ${p.name} missing in class`);
}
for (const file of fs.readdirSync(src).filter(x => x.endsWith('.clas.abap'))) {
  const xml = read(file.replace('.abap', '.xml'));
  assert(xml.includes(`<CLSNAME>${file.split('.')[0].toUpperCase()}</CLSNAME>`), `${file}: missing class metadata`);
}
const reg = new abaplint.Registry();
for (const file of fs.readdirSync(src).filter(x => /\.(abap|xml|asddls)$/.test(x))) {
  reg.addFile(new abaplint.MemoryFile(file, read(file)));
}
reg.parse();
let statements = 0;
for (const obj of reg.getObjects()) {
  if (!obj.getABAPFiles) continue;
  for (const file of obj.getABAPFiles()) {
    for (const statement of file.getStatements()) {
      statements++;
      assert(!(statement.get() instanceof abaplint.Unknown),
        `${file.getFilename()}:${statement.getStart().getRow()}: unparsed ABAP: ${statement.concatTokens()}`);
    }
  }
}
console.log(`Package references and ${statements} ABAP statements parsed. SAP API signatures/release contracts require ADT activation.`);
