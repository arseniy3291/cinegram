'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const esbuild = require('esbuild');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../..');
(async () => {
  const app = path.join(root, 'apps/ios/CineGram');
  const resources = path.join(app, 'WebAssets');
  // Resources is reserved by Apple's iOS bundle layout.
  await fs.rm(path.join(app, 'Resources'), { recursive: true, force: true });
  await fs.mkdir(resources, { recursive: true });
  await fs.cp(path.join(root, 'public'), path.join(resources, 'public'), { recursive: true });
  // Native startup must not wait for Telegram or remote font services.
  const nativeIndex = path.join(resources, 'public/index.html');
  for (const name of ['ipad.css', 'iphone-glass.css', 'iphone-glass.js']) {
    await fs.copyFile(path.join(root, 'apps/ios/Support', name), path.join(resources, 'public', name));
  }
  const html = await fs.readFile(nativeIndex, 'utf8');
  await fs.writeFile(nativeIndex, html
    .replace('</head>', '<link rel=\"stylesheet\" href=\"/ipad.css\"/>\n<link rel=\"stylesheet\" href=\"/iphone-glass.css\"/>\n</head>')
    .replace('</body>', '<script src=\"/iphone-glass.js\"></script>\n</body>')
    .replace(/<script\b[^>]*\bsrc=["']https:\/\/telegram\.org\/js\/telegram-web-app\.js["'][^>]*>\s*<\/script>/gi, '')
    .replace(/<link\b[^>]*\bhref=["']https:\/\/fonts\.(?:googleapis|gstatic)\.com[^"']*["'][^>]*>/gi, ''));
  const helper = path.join(root, 'apps/bundle/ios-shield-helper.cjs');
  await esbuild.build({ entryPoints: [path.join(root, 'providers/adblock.js')], outfile: helper,
    bundle: true, platform: 'node', target: 'node22', format: 'cjs', nodePaths: [path.join(root, 'apps/node_modules')] });
  const { buildClientShieldScript } = require(helper);
  const mediaBridge = await fs.readFile(path.join(root, 'apps/ios/Support/native-media.js'), 'utf8');
  await fs.writeFile(path.join(resources, 'shield.html'), buildClientShieldScript('https://cinegram-origin.invalid/__SOURCE__') + '<script data-name="cinegram-native-media">' + mediaBridge + '</script>');
  await fs.rm(helper);
  const key = process.env.CINEGRAM_KP_KEY;
  if (!key) throw new Error('Set CINEGRAM_KP_KEY before preparing iOS resources.');
  await fs.writeFile(path.join(resources, 'config.json'), JSON.stringify({ metadataKey: key }));
  const icons = path.join(app, 'Assets.xcassets/AppIcon.appiconset');
  await fs.mkdir(icons, { recursive: true });
  await sharp(path.join(root, 'public/cinegram-icon.svg'), { density: 768 }).resize(1024,1024)
    .flatten({ background: '#080808' }).removeAlpha().png().toFile(path.join(icons, 'AppIcon.png'));
  await fs.writeFile(path.join(icons, 'Contents.json'), JSON.stringify({ images: [{ filename: 'AppIcon.png', idiom: 'universal', platform: 'ios', size: '1024x1024' }], info: { author: 'xcode', version: 1 } }, null, 2));
  await fs.writeFile(path.join(app, 'Assets.xcassets/Contents.json'), JSON.stringify({ info: { author: 'xcode', version: 1 } }));
  console.log('iOS resources prepared');
})().catch(error => { console.error(error); process.exitCode = 1; });
