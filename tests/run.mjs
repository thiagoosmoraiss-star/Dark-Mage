// =============================================================================
// Testes de regressão — Dark Wizard - Island of Fear
//
//   node run.mjs --update   gera a REFERÊNCIA (tests/baseline/) a partir do jogo atual
//   node run.mjs            compara o jogo atual com a referência (tests/output/<data>/)
//
// Opções:
//   --gpu   usa a GPU da máquina (padrão: SwiftShader, renderização por CPU, que é
//           reproduzível mas NÃO representa desempenho real)
//   --cdn   carrega o Three.js r128 do cdnjs (padrão: cópia local do npm three@0.128.0)
//   --game <arquivo>  testa outra cópia do jogo em vez de ../index.html
//
// Nada aqui altera o index.html. As únicas interferências na página de teste estão
// em harness-page.js (seed do Math.random e relógio virtual) e nas sondas abaixo,
// que posicionam o jogador/câmera e chamam funções do próprio jogo.
// =============================================================================
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const argv = process.argv.slice(2);
const gameArg = argv.indexOf('--game');
// --game <arquivo>: testa outra cópia do jogo (usado para o controle negativo dos testes)
const GAME = gameArg >= 0 ? path.resolve(argv[gameArg + 1]) : path.join(ROOT, 'index.html');
const BASE_DIR = path.join(HERE, 'baseline');
const ARGS = new Set(argv);
const UPDATE = ARGS.has('--update');
const USE_GPU = ARGS.has('--gpu');
const USE_CDN = ARGS.has('--cdn');

const CONFIG = {
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
    seed: 20261015,
    frameMs: 16.67,
    settleFrames: 59,          // frames de lógica antes de cada captura (+1 frame renderizado)
    imageTolerance: { channel: 8, maxFraction: 0.001 }
};
const THREE_LOCAL = path.join(HERE, 'node_modules', 'three', 'build', 'three.min.js');
const HARNESS_SRC = fs.readFileSync(path.join(HERE, 'harness-page.js'), 'utf8');

// -----------------------------------------------------------------------------
// Poses fixas de câmera para capturas
// -----------------------------------------------------------------------------
const POSES = [
    { id: 'v01_vale_dia',      desc: 'Vale central, spawn, 10h',             x: 0,    z: 65,   yaw: 0,              pitch: 0.24, hour: 10 },
    { id: 'v02_por_do_sol',    desc: 'Colinas a leste, 18h36',               x: 600,  z: 600,  yaw: Math.PI / 4,    pitch: 0.2,  hour: 18.6 },
    { id: 'v03_noite',         desc: 'Encosta norte, 23h',                   x: 300,  z: -300, yaw: 0.6,            pitch: 0.3,  hour: 23 },
    { id: 'v04_castelo',       desc: 'Sul do castelo olhando ao norte, 10h', x: -750, z: -560, yaw: 0,              pitch: 0.3,  hour: 10 },
    { id: 'v05_floresta',      desc: 'Selva de Faron, 11h',                  x: 200,  z: 1100, yaw: 0.8,            pitch: 0.22, hour: 11 },
    { id: 'v06_costa',         desc: 'Costa sul olhando o mar, 9h',          x: 0,    z: 2600, yaw: Math.PI,        pitch: 0.25, hour: 9 },
    { id: 'v07_caverna',       desc: 'Arena da caverna (caves[0])',          dim: 'cave', yaw: 0, pitch: 0.3, hour: 12 },
    { id: 'v08_limbo',         desc: 'Arena do Limbo',                       dim: 'limbo', yaw: 0, pitch: 0.3, hour: 12 }
];

// -----------------------------------------------------------------------------
// Infraestrutura
// -----------------------------------------------------------------------------
const consoleErrors = [];
let browser;

async function launch() {
    const args = USE_GPU ? ['--ignore-gpu-blocklist', '--enable-gpu-rasterization']
                         : ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'];
    browser = await chromium.launch({ args });
}

async function newGamePage(label, { initExtra = '', query = '' } = {}) {
    const context = await browser.newContext({ viewport: CONFIG.viewport, deviceScaleFactor: CONFIG.deviceScaleFactor });
    const page = await context.newPage();
    page.on('pageerror', e => consoleErrors.push(`[${label}] pageerror: ${e.message}`));
    page.on('console', m => { if (m.type() === 'error') consoleErrors.push(`[${label}] console.error: ${m.text()}`); });
    await page.route('**/*', route => {
        const u = route.request().url();
        if (u.startsWith('file:')) return route.continue();
        if (u.includes('three.min.js') && !USE_CDN) {
            return route.fulfill({ body: fs.readFileSync(THREE_LOCAL), contentType: 'text/javascript' });
        }
        if (USE_CDN && u.includes('cdnjs.cloudflare.com')) return route.continue();
        return route.abort(); // fontes e outros recursos externos: bloqueados (condição fixa)
    });
    await page.addInitScript(`window.__HARNESS_CONFIG__ = ${JSON.stringify({ seed: CONFIG.seed, frameMs: CONFIG.frameMs })};\n${HARNESS_SRC}\n${initExtra}`);
    await page.goto(pathToFileURL(GAME).href + query, { waitUntil: 'load' });
    await page.waitForFunction(() => window.__harness && window.__harness.pending() > 0, null, { timeout: 60000 });
    await page.evaluate(() => window.__harness.step(1)); // primeiro frame do loop
    return { page, context };
}

const sha = buf => crypto.createHash('sha256').update(buf).digest('hex');
const r6 = v => (typeof v === 'number' ? Math.round(v * 1e6) / 1e6 : v);
const roundDeep = o => JSON.parse(JSON.stringify(o, (k, v) => r6(v)));

// -----------------------------------------------------------------------------
// Coleta (mesmas funções para referência e comparação)
// -----------------------------------------------------------------------------
async function collectEnvironment() {
    const { page, context } = await newGamePage('env');
    const env = await page.evaluate(() => {
        const gl = renderer.getContext();
        const ext = gl.getExtension('WEBGL_debug_renderer_info');
        return {
            threeRevision: THREE.REVISION,
            webgl2: renderer.capabilities.isWebGL2,
            glRenderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
            glVendor: ext ? gl.getParameter(ext.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR),
            pixelRatio: renderer.getPixelRatio(),
            drawingBuffer: [renderer.domElement.width, renderer.domElement.height],
            maxTextureSize: renderer.capabilities.maxTextureSize
        };
    });
    env.browser = 'chromium ' + browser.version();
    env.threeSource = USE_CDN ? 'cdnjs r128 (rede)' : 'npm three@0.128.0 (local)';
    env.threeSha256 = USE_CDN ? null : sha(fs.readFileSync(THREE_LOCAL));
    env.gameSha256 = sha(fs.readFileSync(GAME));
    env.mode = USE_GPU ? 'GPU da máquina' : 'SwiftShader (CPU)';
    env.config = CONFIG;
    env.loadConditions = 'contexto novo (localStorage vazio), recursos externos bloqueados exceto Three.js, Math.random com seed, relógio virtual';
    await context.close();
    return env;
}

async function collectWorld() {
    const { page, context } = await newGamePage('world');
    const data = await page.evaluate(() => {
        const H = window.__harness;
        // 1) Hash da altura analítica numa grade 200x200 cobrindo o plano do terreno + arenas
        const vals = [];
        for (let i = 0; i < 200; i++) for (let j = 0; j < 200; j++) {
            const x = -3000 + i * 30.15, z = -3000 + j * 30.15;
            vals.push(Math.round(getTerrainHeight(x, z) * 1e6));
        }
        [[5500, 5500], [-5500, -5500], [5500, -5500]].forEach(([x, z]) => vals.push(Math.round(getTerrainHeight(x, z) * 1e6)));

        // 2) Pontos de interesse (ordem = ordem dos arrays, que o save usa por índice)
        const poi = (arr, extra) => arr.map(o => ({ x: o.x, y: o.y, z: o.z, meshY: H.meshHeightAt(o.x, o.z), ...(extra ? extra(o) : {}) }));
        const pois = {
            shrines: poi(shrines, o => ({ name: o.name })),
            towers: poi(towers, o => ({ name: o.name, topY: o.topY })),
            dungeonPortals: poi(dungeonPortals, o => ({ name: o.name })),
            spawners: poi(spawners, o => ({ type: o.type })),
            chests: poi(chests, o => ({ underwater: o.underwater })),
            caves: poi(caves, o => ({ name: o.name })),
            graces: poi(graces, o => ({ name: o.name })),
            rocks: rocks.map(r => ({ x: r.x, y: r.y, z: r.z, r: r.r, topY: r.topY }))
        };

        // 3) Conferência do medidor de altura da malha contra o Raycaster
        let maxCheckDiff = 0;
        for (let k = 0; k < 30; k++) {
            const x = -2500 + k * 171.3, z = 2400 - k * 157.9;
            const a = H.meshHeightAt(x, z), b = H.raycastHeightAt(x, z);
            if (a !== null && b !== null) maxCheckDiff = Math.max(maxCheckDiff, Math.abs(a - b));
        }

        // 4) Diferença malha visível x altura analítica (informativo para a Fase 1)
        const errs = [];
        for (let i = 0; i < 300; i++) for (let j = 0; j < 300; j++) {
            const x = -2700 + i * 18.07 + 3.3, z = -2700 + j * 18.07 + 7.1;
            if (Math.hypot(x, z) > 2780) continue;
            const m = H.meshHeightAt(x, z);
            if (m !== null) errs.push(Math.abs(getTerrainHeight(x, z) - m));
        }
        errs.sort((a, b) => a - b);
        const q = p => errs[Math.min(errs.length - 1, Math.floor(p * errs.length))];

        // 5) Tabela do nightFactor (0h a 24h, passo 0,5h), usando a função original
        const night = [];
        for (let h = 0; h <= 24; h += 0.5) {
            world.hour = ((h - HOURS_PER_STEP) + 24) % 24;
            updateDayNight();
            night.push({ hourSet: h, hour: world.hour, nightFactor: world.nightFactor });
        }

        return {
            terrainSamples: vals.length,
            terrainHash: vals.join(','),
            pois,
            meshCheckMaxDiff: maxCheckDiff,
            meshVsAnalytic: { samples: errs.length, p50: q(0.5), p90: q(0.9), p99: q(0.99), max: errs[errs.length - 1] },
            night,
            skyKeys: SKY_KEYS,
            constants: { ISLAND_RADIUS, WATER_LEVEL, DAY_LENGTH_SEC, HOURS_PER_STEP }
        };
    });
    await context.close();
    data.terrainHash = sha(data.terrainHash);
    return roundDeep(data);
}

async function collectMechanics() {
    const out = {};
    const { page, context } = await newGamePage('mechanics');
    const ev = (fn, arg) => page.evaluate(fn, arg);

    const place = async (x, z, yaw, pitch = 0.24) => ev(([x, z, yaw, pitch]) => {
        player.x = x; player.z = z; player.y = getTerrainHeight(x, z); player.vy = 0;
        player.onGround = true; player.isClimbing = false; player.isGliding = false;
        player.stamina = player.maxStamina; camYaw = yaw; camPitch = pitch;
        window.__harness.tick(2);
    }, [x, z, yaw, pitch]);
    const state = () => ev(() => ({ x: player.x, y: player.y, z: player.z, onGround: player.onGround,
        isClimbing: player.isClimbing, stamina: player.stamina, ground: getTerrainHeight(player.x, player.z),
        meshY: window.__harness.meshHeightAt(player.x, player.z) }));

    // M1 caminhada (tecla W real do teclado, 180 frames) a partir do spawn
    await place(0, 65, 0);
    await page.keyboard.down('w');
    const walk = [];
    for (let k = 0; k < 6; k++) { await ev(() => window.__harness.tick(30)); walk.push(await state()); }
    await page.keyboard.up('w');
    out.walk = walk;

    // M2 corrida (W + Shift) atravessando encosta
    await place(600, 600, Math.PI / 4);
    await page.keyboard.down('Shift'); await page.keyboard.down('w');
    const sprint = [];
    for (let k = 0; k < 6; k++) { await ev(() => window.__harness.tick(30)); sprint.push(await state()); }
    await page.keyboard.up('w'); await page.keyboard.up('Shift');
    out.sprint = sprint;

    // M3 escalada de torre (towers[0])
    const tw = await ev(() => ({ x: towers[0].x, z: towers[0].z, topY: towers[0].topY }));
    await place(tw.x, tw.z + 8, 0);
    await page.keyboard.down('w');
    let frames = 0, st;
    for (; frames < 1200; frames += 10) { await ev(() => window.__harness.tick(10)); st = await state(); if (st.y >= tw.topY - 1e-6) break; }
    await page.keyboard.up('w');
    await ev(() => window.__harness.tick(5));
    out.climbTower = { topY: tw.topY, framesToTop: frames, reached: st.y >= tw.topY - 1e-6, after: await state() };

    // M4 escalada de pedra (maior pedra escalável)
    const rk = await ev(() => { const r = rocks.slice().sort((a, b) => b.r - a.r)[0]; return { x: r.x, z: r.z, r: r.r, topY: r.topY }; });
    await place(rk.x, rk.z + rk.r + 1.5, 0);
    await page.keyboard.down('w');
    for (frames = 0; frames < 1200; frames += 10) { await ev(() => window.__harness.tick(10)); st = await state(); if (st.y >= rk.topY - 1e-6) break; }
    await page.keyboard.up('w');
    out.climbRock = { rock: rk, framesToTop: frames, reached: st.y >= rk.topY - 1e-6, after: await state() };

    // M5 bloqueio da água sem a Túnica Zora (andar para o mar ao sul)
    await place(0, 2400, Math.PI);
    await page.keyboard.down('w');
    const water = [];
    for (let k = 0; k < 12; k++) { await ev(() => window.__harness.tick(60)); water.push(await state()); }
    await page.keyboard.up('w');
    out.waterBlock = { canSwim: await ev(() => player.canSwim), track: water,
        stopped: Math.abs(water[11].z - water[9].z) < 1e-6, finalDist: Math.hypot(water[11].x, water[11].z) };

    // M6 mira: ponto do centro da tela no terreno, em 3 poses (mesmo raycast do jogo)
    const aimPoses = [[0, 65, 0, 0.24], [0, 65, 0, -0.35], [600, 600, Math.PI / 4, 0.1]];
    out.aim = [];
    for (const [x, z, yaw, pitch] of aimPoses) {
        await place(x, z, yaw, pitch);
        out.aim.push(await ev(() => {
            camera.updateMatrixWorld();
            raycaster.setFromCamera(new THREE.Vector2(0, 0), camera);
            const hit = raycaster.intersectObject(terrainMesh, false)[0];
            return { camera: window.__harness.cameraState(),
                     hit: hit ? hit.point.toArray() : null,
                     analyticAtHit: hit ? getTerrainHeight(hit.point.x, hit.point.z) : null };
        }));
    }

    // M7 disparo real do cajado (useActiveWeapon): origem e direção do projétil
    await place(0, 65, 0, 0.1);
    out.projectile = await ev(() => {
        player.mp = player.maxMp; itemCooldowns[player.equippedWeaponId] = 0;
        const before = projectiles.length;
        camera.updateMatrixWorld();
        window.useActiveWeapon();
        const p = projectiles[projectiles.length - 1];
        const r = { weapon: player.equippedWeaponId, created: projectiles.length - before,
                    origin: p ? p.mesh.position.toArray() : null, velocity: p ? [p.vx, p.vy, p.vz] : null };
        window.__harness.tick(30);
        r.after30 = p ? p.mesh.position.toArray() : null;
        return r;
    });

    // M8 meteoro (triggerSpellById real): ponto de impacto x malha visível
    await place(0, 65, 0, 0.1);
    out.meteor = await ev(() => {
        if (!player.unlockedItems.includes('spell_meteor')) player.unlockedItems.push('spell_meteor');
        player.mp = player.maxMp; itemCooldowns.spell_meteor = 0;
        const n = scene.children.length;
        camera.updateMatrixWorld();
        triggerSpellById('spell_meteor');
        const m = scene.children.length > n ? scene.children[scene.children.length - 1] : null;
        if (!m) return { created: false };
        const x = m.position.x, z = m.position.z, impactY = m.position.y - 85;
        return { created: true, target: [x, impactY, z], meshY: window.__harness.meshHeightAt(x, z), analytic: getTerrainHeight(x, z) };
    });
    await page.waitForTimeout(800); // o meteoro cai com setInterval de tempo real

    // M9 inimigos: altura de um terrestre e um voador recém-criados (spawnEnemy3D real)
    out.enemies = await ev(() => {
        const res = [];
        for (const type of ['bokoblin', 'flying']) {
            const sp = spawners.find(s => s.type === type && !s.destroyed);
            player.x = sp.x + 400; player.z = sp.z; player.y = getTerrainHeight(player.x, player.z);
            const before = enemies.length;
            spawnEnemy3D(sp);
            const en = enemies[enemies.length - 1];
            window.__harness.tick(60);
            res.push({ type, created: enemies.length - before, x: en.x, y: en.y, z: en.z,
                       analytic: getTerrainHeight(en.x, en.z), meshY: window.__harness.meshHeightAt(en.x, en.z) });
        }
        return res;
    });
    await context.close();
    return roundDeep(out);
}

async function collectSave(fixture) {
    const out = {};
    // S1 ida e volta: alterar estado, salvar, recarregar, conferir
    {
        const { page, context } = await newGamePage('save-roundtrip');
        const saved = await page.evaluate(() => {
            player.gold = 1234; player.crystals = 7; player.lvl = 3; player.points = 2;
            chests[3].opened = true; shrines[2].discovered = true; towers[1].activated = true;
            spawners[5].destroyed = true; dungeonPortals[0].defeated = true;
            world.hour = 15.5;
            saveGame(true);
            return localStorage.getItem(SAVE_KEY);
        });
        await page.reload({ waitUntil: 'load' });
        await page.waitForFunction(() => window.__harness && window.__harness.pending() > 0);
        out.roundtrip = await page.evaluate(() => ({
            gold: player.gold, crystals: player.crystals, lvl: player.lvl, points: player.points,
            chest3: chests[3].opened, shrine2: shrines[2].discovered, tower1: towers[1].activated,
            spawner5: spawners[5].destroyed, portal0: dungeonPortals[0].defeated, hour: world.hour,
            hotbar: player.hotbar.slice()
        }));
        out.fixture = saved;
        await context.close();
    }
    // S2 compatibilidade: carregar o save gerado pela versão de referência
    const fx = fixture || out.fixture;
    {
        const init = `try { localStorage.setItem('aethelgard_3d_v20', ${JSON.stringify(fx)}); } catch (e) {}`;
        const { page, context } = await newGamePage('save-fixture', { initExtra: init });
        out.fixtureLoad = await page.evaluate(() => ({
            gold: player.gold, crystals: player.crystals, lvl: player.lvl, points: player.points,
            chest3: chests[3].opened, shrine2: shrines[2].discovered, tower1: towers[1].activated,
            spawner5: spawners[5].destroyed, portal0: dungeonPortals[0].defeated, hour: world.hour,
            hotbar: player.hotbar.slice()
        }));
        await context.close();
    }
    return roundDeep(out);
}

async function collectMemory() {
    const { page, context } = await newGamePage('memory');
    const res = await page.evaluate(() => {
        const H = window.__harness;
        player.x = 0; player.z = 65; camYaw = 0; camPitch = 0.1;
        H.tick(2); H.capture();
        const g0 = renderer.info.memory.geometries, c0 = scene.children.length;
        const SHOTS = 20;
        for (let i = 0; i < SHOTS; i++) {
            player.mp = player.maxMp; itemCooldowns[player.equippedWeaponId] = 0;
            window.useActiveWeapon();
            H.capture();     // desenha 1 frame para a geometria nova ir para a GPU
            H.tick(100);     // projétil dura 90 frames
        }
        return { shots: SHOTS, geometriesBefore: g0, sceneChildrenBefore: c0 };
    });
    await page.waitForTimeout(600); // flashRing é removido por setTimeout (tempo real)
    const after = await page.evaluate(() => { window.__harness.capture(); return {
        geometriesAfter: renderer.info.memory.geometries, sceneChildrenAfter: scene.children.length,
        projectilesAlive: projectiles.length }; });
    await context.close();
    const r = { ...res, ...after };
    r.geometriesPerShot = (r.geometriesAfter - r.geometriesBefore) / r.shots;
    return r;
}

function shootPose(page, pose) {
    return page.evaluate(([pose, settle]) => {
        const H = window.__harness;
        if (pose.dim === 'cave') enterCaveDimension(caves[0]);
        else if (pose.dim === 'limbo') enterLimboDimension();
        else { player.x = pose.x; player.z = pose.z; player.y = getTerrainHeight(pose.x, pose.z); player.vy = 0; player.onGround = true; }
        camYaw = pose.yaw; camPitch = pose.pitch; world.hour = pose.hour;
        H.tick(settle);
        const shot = H.capture();
        return { ...shot, camera: H.cameraState() };
    }, [pose, CONFIG.settleFrames]);
}

// Testes do overlay de diagnóstico (?debug=1). Só rodam no modo comparação.
async function collectDebug(imgDir) {
    const out = {};
    // D01 sem o parâmetro: nada instalado
    {
        const { page, context } = await newGamePage('debug-off');
        await page.evaluate(() => window.__harness.step(30));
        out.off = await page.evaluate(() => ({
            panel: !!document.getElementById('debug-overlay'),
            api: typeof window.__debugOverlay,
            wrapped: !!window.renderFrame.__debugOriginal,
            autoReset: renderer.info.autoReset
        }));
        await context.close();
    }
    // D02/D03/D05 com ?debug=1
    {
        const { page, context } = await newGamePage('debug-on', { query: '?debug=1' });
        out.on = await page.evaluate(() => {
            const H = window.__harness;
            H.step(130);   // ~2,2 s de tempo virtual a 16,67 ms/frame
            const D = window.__debugOverlay;
            const s = D ? { ...D.stats } : null;
            const autoResetAfterFrame = renderer.info.autoReset;
            const cap = H.capture();   // contagem independente do mesmo frame
            return {
                api: !!D, wrapped: !!window.renderFrame.__debugOriginal,
                panel: !!document.getElementById('debug-overlay'),
                stats: s, autoResetAfterFrame,
                overlayCalls: D.stats.calls, overlayTris: D.stats.triangles,
                harnessCalls: cap.stats.calls, harnessTris: cap.stats.triangles,
                gpuName: D.gpuName
            };
        });
        await page.waitForTimeout(400); // painel redesenha a cada 250 ms (tempo real)
        out.on.panelText = await page.evaluate(() => document.getElementById('debug-overlay').textContent);

        out.contract = await page.evaluate(() => {
            const wrap = window.__debugOverlay.wrapRender;
            const info = renderer.info;
            const r = {};
            const fake = function (a, b) { return { self: this, a, b, n: arguments.length }; };
            const w = wrap(fake);
            const ctx = { tag: 'ctx' };
            const ret = w.call(ctx, 1, 'x', 3);
            r.returnsValue = ret.self === ctx && ret.a === 1 && ret.b === 'x' && ret.n === 3;
            r.keepsOriginal = w.__debugOriginal === fake;
            const boom = new Error('boom');
            info.autoReset = true;
            try { wrap(() => { throw boom; })(); r.rethrows = false; } catch (e) { r.rethrows = e === boom; }
            r.autoResetRestoredAfterThrow = info.autoReset === true;
            info.autoReset = false;
            wrap(() => 1)();
            r.autoResetRestoredFalse = info.autoReset === false;
            info.autoReset = true;
            r.liveWrapperKeepsGameFunction = typeof window.renderFrame.__debugOriginal === 'function'
                && window.renderFrame.__debugOriginal.name === 'renderFrame';
            // custo do wrapper (Date.now, pois performance.now é virtual no teste)
            const noop = function () {};
            const wn = wrap(noop);
            const N = 200000;
            let t = Date.now(); for (let i = 0; i < N; i++) noop(); const raw = Date.now() - t;
            t = Date.now(); for (let i = 0; i < N; i++) wn(); const wrapped = Date.now() - t;
            r.overheadMicrosPerCall = (wrapped - raw) * 1000 / N;
            return r;
        });
        await context.close();
    }
    // D04 com ?debug=1 o canvas renderizado tem que ser idêntico à referência
    {
        const { page, context } = await newGamePage('debug-render', { query: '?debug=1' });
        const r = await shootPose(page, POSES[0]);
        fs.writeFileSync(path.join(imgDir, `debug_${POSES[0].id}.png`), Buffer.from(r.img.split(',')[1], 'base64'));
        await page.screenshot({ path: path.join(imgDir, `debug_${POSES[0].id}__tela_com_hud.png`) });
        out.render = { camera: roundDeep(r.camera), stats: r.stats };
        await context.close();
    }
    return out;
}

async function collectCaptures(outDir) {
    const caps = {};
    fs.mkdirSync(outDir, { recursive: true });
    for (const pose of POSES) {
        const { page, context } = await newGamePage(pose.id);
        const r = await shootPose(page, pose);
        const png = Buffer.from(r.img.split(',')[1], 'base64');
        fs.writeFileSync(path.join(outDir, `${pose.id}.png`), png);
        await page.screenshot({ path: path.join(outDir, `${pose.id}__tela_com_hud.png`) });
        caps[pose.id] = { desc: pose.desc, pose, camera: roundDeep(r.camera), stats: r.stats, sha256: sha(png) };
        await context.close();
    }
    return caps;
}

async function compareImages(aPath, bPath, diffPath) {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    const a = 'data:image/png;base64,' + fs.readFileSync(aPath).toString('base64');
    const b = 'data:image/png;base64,' + fs.readFileSync(bPath).toString('base64');
    const r = await page.evaluate(async ([a, b, tol]) => {
        const load = src => new Promise((ok, err) => { const i = new Image(); i.onload = () => ok(i); i.onerror = err; i.src = src; });
        const [ia, ib] = await Promise.all([load(a), load(b)]);
        if (ia.width !== ib.width || ia.height !== ib.height) return { sizeMismatch: true };
        const w = ia.width, h = ia.height;
        const cv = document.createElement('canvas'); cv.width = w; cv.height = h;
        const c = cv.getContext('2d');
        c.drawImage(ia, 0, 0); const da = c.getImageData(0, 0, w, h).data;
        c.drawImage(ib, 0, 0); const db = c.getImageData(0, 0, w, h).data;
        const out = c.createImageData(w, h);
        let diffPx = 0, sum = 0;
        for (let i = 0; i < da.length; i += 4) {
            const d = Math.max(Math.abs(da[i] - db[i]), Math.abs(da[i + 1] - db[i + 1]), Math.abs(da[i + 2] - db[i + 2]));
            sum += d;
            const bad = d > tol;
            if (bad) diffPx++;
            out.data[i] = bad ? 255 : da[i] * 0.3; out.data[i + 1] = bad ? 0 : da[i + 1] * 0.3; out.data[i + 2] = bad ? 0 : da[i + 2] * 0.3; out.data[i + 3] = 255;
        }
        c.putImageData(out, 0, 0);
        return { diffFraction: diffPx / (w * h), meanAbsDiff: sum / (w * h), diffPng: cv.toDataURL('image/png') };
    }, [a, b, CONFIG.imageTolerance.channel]);
    await ctx.close();
    if (r.diffPng) { fs.writeFileSync(diffPath, Buffer.from(r.diffPng.split(',')[1], 'base64')); delete r.diffPng; }
    return r;
}

// -----------------------------------------------------------------------------
// Comparação e relatório
// -----------------------------------------------------------------------------
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);

function firstDiff(a, b, p = '') {
    if (eq(a, b)) return null;
    if (typeof a !== 'object' || typeof b !== 'object' || a === null || b === null) return `${p || '(raiz)'}: ${JSON.stringify(a)} → ${JSON.stringify(b)}`;
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
        const d = firstDiff(a[k], b[k], p ? `${p}.${k}` : k);
        if (d) return d;
    }
    return null;
}

async function main() {
    if (!fs.existsSync(GAME)) throw new Error('index.html não encontrado em ' + GAME);
    if (!USE_CDN && !fs.existsSync(THREE_LOCAL)) throw new Error('Rode "npm install" em tests/ (falta three@0.128.0 local) ou use --cdn');
    await launch();
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    const outDir = UPDATE ? BASE_DIR : path.join(HERE, 'output', stamp);
    const imgDir = path.join(outDir, 'img');
    fs.mkdirSync(imgDir, { recursive: true });

    const baseline = UPDATE ? null : JSON.parse(fs.readFileSync(path.join(BASE_DIR, 'baseline.json'), 'utf8'));
    const t0 = Date.now();
    const result = {};
    result.environment = await collectEnvironment();
    result.world = await collectWorld();
    result.mechanics = await collectMechanics();
    result.save = await collectSave(baseline ? baseline.save.fixture : null);
    result.memory = await collectMemory();
    result.captures = await collectCaptures(imgDir);
    if (!UPDATE) result.debug = await collectDebug(imgDir);
    result.consoleErrors = consoleErrors.slice();
    result.durationSec = Math.round((Date.now() - t0) / 1000);

    if (UPDATE) {
        fs.writeFileSync(path.join(outDir, 'baseline.json'), JSON.stringify(result, null, 2));
        console.log(`Referência gravada em ${outDir} (${result.durationSec}s).`);
        console.log(`Erros de console: ${consoleErrors.length}`);
        await browser.close();
        return;
    }

    // ---------------- comparação ----------------
    const T = [];
    const add = (id, name, kind, status, detail) => T.push({ id, name, kind, status, detail });
    const sameEnv = baseline.environment.glRenderer === result.environment.glRenderer
        && baseline.environment.browser === result.environment.browser
        && baseline.environment.threeSha256 === result.environment.threeSha256;
    const regress = (id, name, a, b) => {
        const d = firstDiff(a, b);
        add(id, name, 'simulado (regressão)', d ? 'REPROVADO' : 'APROVADO', d ? 'Primeira diferença: ' + d : 'Idêntico à referência');
    };

    add('T01', 'Sem erros de JavaScript no carregamento e nas sondas', 'simulado', consoleErrors.length === 0 ? 'APROVADO' : 'REPROVADO',
        consoleErrors.length ? consoleErrors.slice(0, 5).join(' | ') : '0 erros');
    regress('T02', 'Altura do terreno (hash de 40.003 amostras)', baseline.world.terrainHash, result.world.terrainHash);
    regress('T03', 'Pontos de interesse: quantidade, ordem e posição', baseline.world.pois, result.world.pois);
    regress('T04', 'Tabela do nightFactor 0h–24h', baseline.world.night, result.world.night);
    regress('T05', 'SKY_KEYS e constantes do mundo', [baseline.world.skyKeys, baseline.world.constants], [result.world.skyKeys, result.world.constants]);
    regress('T06', 'Caminhada (W) a partir do spawn', baseline.mechanics.walk, result.mechanics.walk);
    regress('T07', 'Corrida (W+Shift) em encosta', baseline.mechanics.sprint, result.mechanics.sprint);
    regress('T08', 'Escalada da torre', baseline.mechanics.climbTower, result.mechanics.climbTower);
    regress('T09', 'Escalada da maior pedra', baseline.mechanics.climbRock, result.mechanics.climbRock);
    regress('T10', 'Bloqueio de água sem Túnica Zora', baseline.mechanics.waterBlock, result.mechanics.waterBlock);
    regress('T11', 'Mira (raycast do centro da tela) em 3 poses', baseline.mechanics.aim, result.mechanics.aim);
    regress('T12', 'Disparo do cajado: origem e direção', baseline.mechanics.projectile, result.mechanics.projectile);
    regress('T13', 'Meteoro: ponto de impacto', baseline.mechanics.meteor, result.mechanics.meteor);
    regress('T14', 'Inimigos terrestre e voador: altura', baseline.mechanics.enemies, result.mechanics.enemies);
    {
        const rt = result.save.roundtrip;
        const ok = rt.gold === 1234 && rt.crystals === 7 && rt.lvl === 3 && rt.points === 2 && rt.chest3 && rt.shrine2 && rt.tower1 && rt.spawner5 && rt.portal0;
        add('T15', 'Save: salvar e recarregar', 'simulado', ok ? 'APROVADO' : 'REPROVADO', JSON.stringify(rt));
    }
    regress('T16', 'Save da versão de referência carrega igual', baseline.save.fixtureLoad, result.save.fixtureLoad);
    regress('T17', 'Memória após 20 disparos (igual à referência)', baseline.memory, result.memory);
    add('T18', 'Saúde: vazamento de geometria por disparo', 'medição', result.memory.geometriesPerShot === 0 ? 'APROVADO' : 'REPROVADO',
        `${result.memory.geometriesPerShot} geometria(s) não liberada(s) por disparo (defeito pré-existente; correção prevista na Fase 6)`);

    for (const pose of POSES) {
        const id = pose.id;
        const b = path.join(BASE_DIR, 'img', `${id}.png`), a = path.join(imgDir, `${id}.png`);
        const camOk = eq(baseline.captures[id].camera, result.captures[id].camera);
        if (!sameEnv) {
            add(id.toUpperCase().slice(0, 3), `Captura: ${pose.desc}`, 'visual', 'INCONCLUSIVO',
                'Ambiente de renderização diferente da referência (GPU/navegador/Three.js): imagens não são comparáveis pixel a pixel');
            continue;
        }
        const r = await compareImages(b, a, path.join(imgDir, `${id}__diff.png`));
        const ok = camOk && !r.sizeMismatch && r.diffFraction <= CONFIG.imageTolerance.maxFraction;
        add(id.toUpperCase().slice(0, 3), `Captura: ${pose.desc}`, 'visual (render real do jogo, câmera simulada)', ok ? 'APROVADO' : 'REPROVADO',
            r.sizeMismatch ? 'tamanho diferente' : `${(r.diffFraction * 100).toFixed(4)}% pixels diferentes, diferença média ${r.meanAbsDiff.toFixed(3)}, câmera ${camOk ? 'igual' : 'DIFERENTE'}`);
    }

    {
        const d = result.debug;
        add('D01', 'Sem ?debug: overlay ausente e renderFrame original', 'simulado',
            (!d.off.panel && d.off.api === 'undefined' && !d.off.wrapped && d.off.autoReset === true) ? 'APROVADO' : 'REPROVADO', JSON.stringify(d.off));
        const on = d.on, st = on.stats || {};
        const okOn = on.api && on.wrapped && on.panel && on.autoResetAfterFrame === true
            && Math.abs(st.fps - 60) < 0.2 && Math.abs(st.frameAvg - CONFIG.frameMs) < 0.05
            && on.overlayCalls === on.harnessCalls && on.overlayTris === on.harnessTris && on.overlayCalls > 0
            && /FPS/.test(on.panelText) && !!on.gpuName;
        add('D02', 'Com ?debug=1: painel ativo e números coerentes', 'simulado (relógio virtual)', okOn ? 'APROVADO' : 'REPROVADO',
            `FPS ${st.fps && st.fps.toFixed(2)} (esperado 60,00), frame ${st.frameAvg && st.frameAvg.toFixed(3)} ms (esperado ${CONFIG.frameMs}), draw calls overlay ${on.overlayCalls} = medição independente ${on.harnessCalls}, tris ${on.overlayTris} = ${on.harnessTris}, autoReset restaurado ${on.autoResetAfterFrame}, GPU "${on.gpuName}"`);
        const c = d.contract;
        const okC = c.returnsValue && c.keepsOriginal && c.rethrows && c.autoResetRestoredAfterThrow && c.autoResetRestoredFalse && c.liveWrapperKeepsGameFunction;
        add('D03', 'Wrapper de renderFrame: this, argumentos, retorno, exceção e estado', 'simulado', okC ? 'APROVADO' : 'REPROVADO', JSON.stringify({ ...c, overheadMicrosPerCall: undefined }));
        const b = path.join(BASE_DIR, 'img', `${POSES[0].id}.png`), a = path.join(imgDir, `debug_${POSES[0].id}.png`);
        if (!sameEnv) add('D04', 'Com ?debug=1 a imagem 3D é idêntica à referência', 'visual', 'INCONCLUSIVO', 'ambiente diferente da referência');
        else {
            const r = await compareImages(b, a, path.join(imgDir, `debug_${POSES[0].id}__diff.png`));
            const camOk = eq(baseline.captures[POSES[0].id].camera, d.render.camera);
            add('D04', 'Com ?debug=1 a imagem 3D é idêntica à referência', 'visual (render real, câmera simulada)',
                camOk && r.diffFraction === 0 ? 'APROVADO' : 'REPROVADO', `${(r.diffFraction * 100).toFixed(4)}% pixels diferentes, diferença média ${r.meanAbsDiff.toFixed(3)}, câmera ${camOk ? 'igual' : 'DIFERENTE'}`);
        }
        // critério: < 5 µs por frame (0,03% de um frame de 60 FPS)
        add('D05', 'Custo do wrapper por frame (< 5 µs)', 'medição (CPU deste ambiente)', c.overheadMicrosPerCall < 5 ? 'APROVADO' : 'REPROVADO',
            `${c.overheadMicrosPerCall.toFixed(3)} µs por chamada (1 chamada por frame; um frame a 60 FPS = 16.667 µs)`);
    }

    const report = { environment: result.environment, sameEnvironmentAsBaseline: sameEnv, tests: T, result };
    fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify(report, null, 2));
    const md = ['# Relatório de regressão', '', `Data: ${stamp}`, `Ambiente: ${result.environment.mode} — ${result.environment.glRenderer}`,
        `Mesmo ambiente da referência: ${sameEnv ? 'sim' : 'NÃO'}`, '', '| ID | Teste | Tipo | Status | Detalhe |', '|---|---|---|---|---|',
        ...T.map(t => `| ${t.id} | ${t.name} | ${t.kind} | ${t.status} | ${String(t.detail).replace(/\|/g, '/')} |`)].join('\n');
    fs.writeFileSync(path.join(outDir, 'report.md'), md);
    console.log(md);
    console.log(`\nRelatório: ${path.join(outDir, 'report.md')} (${result.durationSec}s)`);
    await browser.close();
}

main().catch(async e => { console.error(e); if (browser) await browser.close(); process.exit(1); });
