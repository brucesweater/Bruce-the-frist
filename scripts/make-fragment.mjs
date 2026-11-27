// Turns the single-file build (dist-single/index.html) into an HTML fragment:
// the title, styles and scripts without the <html>/<head>/<body> wrapper, for
// hosts that supply their own document skeleton (such as a shared preview page).
import { readFileSync, writeFileSync } from 'node:fs';

const html = readFileSync('dist-single/index.html', 'utf8');
const pick = (re) => [...html.matchAll(re)].map((m) => m[0]);

const title = pick(/<title>[\s\S]*?<\/title>/g)[0] ?? '<title>Admit Compass</title>';
const description = pick(/<meta name="description"[^>]*>/g)[0] ?? '';
const styles = pick(/<style\b[^>]*>[\s\S]*?<\/style>/g);
const scripts = pick(/<script\b[^>]*>[\s\S]*?<\/script>/g);
const classic = scripts.filter((s) => !/type="module"/.test(s));
const modules = scripts.filter((s) => /type="module"/.test(s));

const fragment = [
  title,
  '<meta name="claude:viewport-fit-sides" content="cover">',
  description,
  ...classic,
  ...styles,
  '<div id="root"></div>',
  ...modules,
]
  .filter(Boolean)
  .join('\n');

writeFileSync('dist-single/admit-compass.html', fragment);
console.log(`dist-single/admit-compass.html: ${(fragment.length / 1024).toFixed(0)} KB`);
