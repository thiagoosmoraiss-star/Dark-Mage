// =============================================================================
// HARNESS DE TESTE — roda SOMENTE dentro do navegador controlado pelo Playwright
// (injetado via page.addInitScript antes do jogo carregar). NÃO faz parte do
// jogo e nunca é carregado pelo index.html.
//
// O que ele altera, apenas na página de teste:
//   1. Math.random  -> PRNG com seed fixa (mulberry32), para o mundo e o combate
//                      serem idênticos entre execuções.
//   2. requestAnimationFrame / performance.now -> relógio virtual. Cada "step"
//      avança FRAME_MS de tempo virtual e chama o loop do jogo uma vez, então o
//      número de updates não depende da velocidade da máquina.
// Tudo o mais (lógica, controles, render) é o código original do jogo.
// =============================================================================
(() => {
    const CFG = window.__HARNESS_CONFIG__ || {};
    const FRAME_MS = CFG.frameMs || 16.67;

    let s = (CFG.seed >>> 0) || 1;
    Math.random = function () {
        s = (s + 0x6D2B79F5) | 0;
        let t = Math.imul(s ^ (s >>> 15), 1 | s);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };

    let now = 0;
    let queue = [];
    window.requestAnimationFrame = cb => { queue.push(cb); return queue.length; };
    window.cancelAnimationFrame = () => {};
    performance.now = () => now;

    const H = {
        pending: () => queue.length,
        time: () => now,

        // Um frame completo do loop do jogo (update + render), em tempo virtual.
        step(n = 1) {
            for (let i = 0; i < n; i++) {
                now += FRAME_MS;
                const cbs = queue; queue = [];
                cbs.forEach(cb => cb(now));
            }
        },

        // Frames do loop do jogo SEM desenhar (para sondas de lógica rápidas).
        // O renderFrame global é trocado temporariamente por uma função vazia
        // e restaurado logo depois, mesmo se houver exceção.
        tick(n = 1) {
            const rf = window.renderFrame;
            window.renderFrame = function () {};
            try { H.step(n); } finally { window.renderFrame = rf; }
        },

        // Desenha um frame e devolve a imagem do canvas WebGL (sem o HUD em HTML)
        // e as estatísticas do renderer somadas de todos os passes do frame.
        capture() {
            const info = renderer.info;
            info.autoReset = false;
            info.reset();
            H.step(1);
            const stats = {
                calls: info.render.calls,
                triangles: info.render.triangles,
                points: info.render.points,
                lines: info.render.lines,
                geometries: info.memory.geometries,
                textures: info.memory.textures,
                programs: info.programs ? info.programs.length : null
            };
            info.autoReset = true;
            const img = renderer.domElement.toDataURL('image/png');
            return { img, stats };
        },

        // Altura da MALHA visível do terreno em (x, z), interpolando o triângulo
        // real da PlaneGeometry (diferente de getTerrainHeight, que é analítica).
        meshHeightAt(x, z) {
            const g = terrainMesh.geometry;
            const p = g.attributes.position;
            const idx = g.index.array;
            const gp = g.parameters;
            const gx = gp.widthSegments, gy = gp.heightSegments;
            const sw = gp.width / gx, sh = gp.height / gy;
            const ix = Math.floor((x + gp.width / 2) / sw);
            const iy = Math.floor((z + gp.height / 2) / sh);
            if (ix < 0 || iy < 0 || ix >= gx || iy >= gy) return null;
            const base = (iy * gx + ix) * 6;
            for (let t = 0; t < 2; t++) {
                const a = idx[base + t * 3], b = idx[base + t * 3 + 1], c = idx[base + t * 3 + 2];
                const ax = p.getX(a), az = p.getZ(a), bx = p.getX(b), bz = p.getZ(b), cx = p.getX(c), cz = p.getZ(c);
                const det = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz);
                const l1 = ((bz - cz) * (x - cx) + (cx - bx) * (z - cz)) / det;
                const l2 = ((cz - az) * (x - cx) + (ax - cx) * (z - cz)) / det;
                const l3 = 1 - l1 - l2;
                if (l1 >= -1e-9 && l2 >= -1e-9 && l3 >= -1e-9) {
                    return l1 * p.getY(a) + l2 * p.getY(b) + l3 * p.getY(c);
                }
            }
            return null;
        },

        // Altura da malha via Raycaster (usado só para conferir meshHeightAt).
        raycastHeightAt(x, z) {
            const rc = new THREE.Raycaster(new THREE.Vector3(x, 2000, z), new THREE.Vector3(0, -1, 0));
            const hit = rc.intersectObject(terrainMesh, false)[0];
            return hit ? hit.point.y : null;
        },

        cameraState() {
            const dir = new THREE.Vector3();
            camera.updateMatrixWorld();
            camera.getWorldDirection(dir);
            return {
                position: camera.position.toArray(),
                direction: dir.toArray(),
                fov: camera.fov, near: camera.near, far: camera.far,
                camYaw, camPitch,
                hour: world.hour, nightFactor: world.nightFactor,
                player: [player.x, player.y, player.z]
            };
        }
    };
    window.__harness = H;
})();
