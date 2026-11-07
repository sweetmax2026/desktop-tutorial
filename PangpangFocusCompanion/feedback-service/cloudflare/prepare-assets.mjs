import { mkdirSync, copyFileSync } from 'node:fs';
const publicDir = new URL('./public/', import.meta.url);
mkdirSync(publicDir, {recursive:true});
for (const file of ['admin.html','admin.css','admin.js']) copyFileSync(new URL('../'+file,import.meta.url),new URL(file,publicDir));
copyFileSync(new URL('./support.html',import.meta.url),new URL('support.html',publicDir));
copyFileSync(new URL('../../Resources/PrivacyPolicy.txt',import.meta.url),new URL('privacy.txt',publicDir));
console.log('Prepared public admin/support assets and privacy policy; no config, credentials or user data copied.');
