import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {Transpiler} from '@abaplint/transpiler';

const root = path.resolve(import.meta.dirname, '..');
const generated = path.join(root, 'tests/generated');
fs.mkdirSync(generated, {recursive:true});
const files = [];
for (const file of fs.readdirSync(path.join(root,'src'))) {
  if (/^(zif_pr_email_types|zcl_pr_email_policy|zcl_pr_email_html)\./.test(file) && /\.(abap|xml)$/.test(file)) {
    files.push({filename:file, contents:fs.readFileSync(path.join(root,'src',file),'utf8')});
  }
}
for (const file of fs.readdirSync(path.join(root,'tests/runtime'))) {
  files.push({filename:file, contents:fs.readFileSync(path.join(root,'tests/runtime',file),'utf8')});
}
const result = await new Transpiler({addCommonJS:true}).runRaw(files);
for (const obj of result.objects) fs.writeFileSync(path.join(generated,obj.filename),obj.chunk.getCode());
fs.writeFileSync(path.join(generated,'_top.mjs'),result.initializationScript);
fs.writeFileSync(path.join(generated,'init.mjs'),result.initializationScript2);
fs.writeFileSync(path.join(generated,'unit.mjs'),result.unitTestScript);
console.log('Executing the ABAP policy and HTML unit tests through the ABAP transpiler.');
await import(pathToFileURL(path.join(generated,'init.mjs')).href);
// The JS runtime lacks SAP currency formatting/TCURX. Limit this adapter to
// the two-decimal INR/blank fixtures; never claim currency customizing tested.
const formatting = globalThis.abap.templateFormatting.bind(globalThis.abap);
globalThis.abap.templateFormatting = (value, options) => {
  if (options?.currency !== undefined) {
    const currency = String(options.currency.get?.() ?? options.currency).trim();
    if (!['', 'INR'].includes(currency)) throw new Error(`Currency fixture unsupported: ${currency}`);
    const {currency: ignored, ...remaining} = options;
    return formatting(value, {...remaining, decimals:2});
  }
  return formatting(value, options);
};
console.log('Currency formatting uses a two-decimal fixture adapter; verify actual currencies in SAP.');
await import(pathToFileURL(path.join(generated,'unit.mjs')).href);
