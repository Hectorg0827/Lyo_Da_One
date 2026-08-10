import { cpSync, existsSync, mkdirSync, rmSync, copyFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const openNextDir = join(root, '.open-next');
const distDir = join(root, 'dist');
const serverDir = join(distDir, 'server');
const workerFile = join(serverDir, 'worker.js');

if (!existsSync(join(openNextDir, 'worker.js'))) {
  throw new Error('Missing .open-next/worker.js. Run npm run build:worker first.');
}

rmSync(distDir, { recursive: true, force: true });
mkdirSync(serverDir, { recursive: true });

cpSync(openNextDir, serverDir, { recursive: true });
copyFileSync(workerFile, join(serverDir, 'index.js'));

const assetsDir = join(serverDir, 'assets');
if (existsSync(assetsDir)) {
  cpSync(assetsDir, join(distDir, 'assets'), { recursive: true });
}
