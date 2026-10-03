## Web stack vs Godot 4 for a 1-person + AI Steam game (research as of 2026-10-03)

**Recommendation: Godot 4.7.x with the Forward+ renderer.** I tested both stacks in this container. Both work with no GPU and no Windows. Godot gives the best look with no artist, the most rendering features built in, smaller builds and cleaner Steam integration. If you go web, use Babylon.js or Three.js inside Electron with steamworks-ffi-node.

**How I sourced this:**
- The web search limit had already been used up (200/200), and the network blocks most sites, including partner.steamgames.com, godotengine.org, store.steampowered.com and the games press.
- So I used GitHub, the npm registry and SteamDatabase's copy of the Steamworks docs (synced 2026-10-02), plus hands-on tests.
- Anything I could not check is marked **UNVERIFIED**.

### Tests I ran in this container
1. **Godot 4.7.2 install:** downloaded from GitHub releases and runs headless. Templates and binaries are reachable at github.com/godotengine/godot-builds/releases.
2. **Godot Forward+ rendering, no GPU:**
   - It needs a software Vulkan driver (lavapipe from Mesa's `mesa-vulkan-drivers` package).
   - apt can download it, and it works when pointed to with `VK_ICD_FILENAMES`.
   - Run under `xvfb-run`, Godot reported "Vulkan 1.4.318 - Forward+ - llvmpipe" and saved a correct screenshot with shadows.
   - Without lavapipe it falls back to the OpenGL Compatibility renderer, which also renders.
   - **What this means:** the AI can take screenshots and check the visuals itself.
3. **Godot export from Linux:** `godot --headless --export-release` produced a Windows .exe (PE32+ x86-64, 109 MB, about 9 s) and a Linux build (74 MB). No Wine was needed.
4. **Electron 44.5.1 + Three.js r186:**
   - WebGL2 is blocked by default on a software renderer.
   - With `ignore-gpu-blocklist`, `enable-unsafe-swiftshader` and `use-angle=swiftshader` it renders a toon-shaded scene with shadows, and `navigator.gpu` is present.
   - Use those flags only for testing, never in the shipped build.
   - The Electron runtime alone is 283 MB unpacked (123 MB zip).

### Engine comparison
| | Godot 4.7.x | Electron + Three.js / Babylon.js | Tauri | NW.js |
|---|---|---|---|---|
| Version (date) | 4.7.2-stable, tagged 2026-08-16; 4.7 tagged 2026-06-17; 4.8 at dev7 | electron 44.5.1 (2026-09-30), three 0.186.1 (2026-09-24), @babylonjs/core 9.29.0 (2026-10-01), pixi.js 8.22.0, phaser 4.2.1 | @tauri-apps/cli 2.12.1 (2026-09-30) | nw 0.117.0 (2026-09-26) |
| Built-in graphics | Forward+ only: SDFGI/VoxelGI lighting, volumetric fog, SSR, SSIL, TAA, FSR2. SSAO, glow, decals and depth of field also on other renderers. Toon shading built in (`DIFFUSE_TOON`/`SPECULAR_TOON`). Particle systems and compositor effects for custom post-processing | Babylon: default post-processing pipeline, SSAO2, SSR, GPU particles, NodeMaterial, IBL shadows, outline renderer, WebGPU engine. Three: WebGPU renderer + TSL shading language, outline/bloom/SSAO/GTAO/SSR/bokeh passes, plus pmndrs `postprocessing` 6.39.5 and the three.quarks particle library | Uses the system web view: WebView2 on Windows, WebKitGTK on Linux. Rendering quality and features vary by OS (UNVERIFIED on performance) | Chromium, like Electron |
| Steam API | GodotSteam. The GitHub repo says it moved to Codeberg; last GitHub tag v4.22.1, Sep 2025 | **steamworks.js**: last npm release 0.4.0 in Aug 2024, last commit Sep 2025, so it is stale. It ships Windows/Linux/macOS binaries and has `electronEnableSteamOverlay()`. **steamworks-ffi-node** 0.11.3 (2026-09-24): Steamworks SDK 1.64, achievements, cloud saves, workshop, input; overlay is experimental | Rust `steamworks` crate 0.13.1. Steam overlay status UNVERIFIED | greenworks: "best-effort" maintenance, SDK 1.62 |
| Windows build from Linux | Works, tested | @electron/packager 20.3.0 uses `resedit` (pure JS), so probably no Wine needed (my inference from its dependencies). electron-builder uses the host's Wine on Linux | NSIS installer only, "not tested as much", "last resort" per Tauri docs | UNVERIFIED |
| Web demo | Compatibility renderer only on web | Native to the web | – | – |

**Visual verdict (my judgment, based on the feature lists above):**
- Godot Forward+ gives the strongest "looks expensive" result from simple procedural/low-poly shapes with no extra code: GI, fog, glow, TAA and particles are all built in.
- Among the web engines, Babylon is the most complete out of the box.
- Big factory simulations with thousands of entities favour native Godot plus mesh instancing. The performance gap versus JS/Chromium is **UNVERIFIED** (no benchmark run).

### Steam games built with each stack (source checked)
- **Web tech:**
  - shapez (1), a factory game: Electron 16.2.8, per `electron/package.json` in tobspr-games/shapez.io. That repo is no longer maintained; the team moved to shapez 2.
  - Bitburner: Electron with the `@catloversg/steamworks.js` fork.
  - Antimatter Dimensions: has `build:steam-release` and Electron/Steam runtime code.
  - Game Dev Tycoon: NW.js; greenworks was originally written for it.
  - Wayward, Along the Edge, Yeah Jam Fury, Rum & Gun (Electron + greenworks), and The Settlers Online / Anno Online (NW.js), per the greenworks wiki.
  - Beaming, Bulletail, DekaDuck use steamworks-ffi-node, per its README.
- **UNVERIFIED:** CrossCode (ImpactJS + NW.js); Vampire Survivors (Phaser, later moved to Unity); Cookie Clicker on Steam (Electron).
- **Godot** (official showcase in the godot-website repo): Slay the Spire 2, Brotato, Buckshot Roulette, Dome Keeper, Halls of Torment, Luck be a Landlord, Windowkill, Cassette Beasts, Tiny Pasture, Until Then.

### Steam facts (from Steamworks docs copy, synced 2026-10-02)
- **Fee:** $100 USD per app, not refundable. It is paid back "after your product has at least $1,000.00 Adjusted Gross Revenue" from store or in-app sales. Steam wallet funds cannot be used to pay it.
- **Waiting periods for your first titles:**
  - 21 days between paying the app fee and releasing. Older sources say 30 days; the current doc says **21**.
  - The Coming Soon page must be public for "at least two weeks".
  - Tax info check: 10–15 business days.
- **Review:**
  - The store page and the build are reviewed separately, each "typically 3-5 business days".
  - Valve asks you to submit each "at least 7 business days" before you want it live.
  - "Adult Only Sexual Content" titles must submit both together, and review can take longer.
- **AI content disclosure:**
  - AI tools used to work more efficiently (such as coding assistants) are "not the focus" and do not need to be disclosed.
  - Disclosure covers AI-made content that ships with the game and is consumed by players (art, sound, story text, translation).
  - Pre-generated content is reviewed like any other content.
  - Live-generated content must also describe its guardrails.
  - Live-generated AI adult sexual content is not allowed.
  - Whether the disclosure is shown on the store page is **UNVERIFIED** (not found in the current text).
- **Prohibited content:**
  - Blockchain apps that issue or trade crypto or NFTs.
  - Advertising-based business models.
  - Content that breaks payment processor, card network or bank rules, "in particular, certain kinds of adult only content".
  - Content that breaks the law where it is sold.
  - Adult content that is not labelled and age-gated.
- **Gambling:** the docs copy contains no explicit "gambling" rule (zero matches). A ban on real-money gambling or items with real-world value is **UNVERIFIED** here; treat it as prohibited.
- **Steam Deck badges:** Verified, Playable, Unsupported, Unknown. To be Verified:
  - Full controller support in the default configuration.
  - Button prompts that match Deck or Xbox buttons.
  - On-screen keyboard for text input, through the Steamworks API or the game's own controller-friendly entry.
  - A supported resolution (1280x800 preferred, or 1280x720) and a playable framerate by default.
  - Text at least 9 px tall at 1280x800 (12 px recommended).
  - No "unsupported device" warnings, and any launcher must be controller-navigable.
  - Valve tests the game; games without a native Linux build run through Proton.
  - The "Great on Deck" store tab shows only Verified games.
  - The docs list Steam Machine and Steam Frame as "upcoming" hardware.
- **Revenue split** (30%, then 25% above $10M, then 20% above $50M, announced Nov 2018): **UNVERIFIED**. It is not in the public docs; it lives in the Steam Distribution Agreement. US withholding tax ranges from 0–30% depending on tax treaty (verified, tax FAQ).

### Sources
- Steamworks docs copy: https://github.com/SteamDatabase/SteamworksDocumentation (`docs/gettingstarted/appfee.html`, `onboarding.html`, `contentsurvey.html`, `docs/store/review_process.html`, `coming_soon.html`, `docs/steamdeck/compat.html`, `docs/finance/taxfaq.html`, `docs/steamhardware.html`). Originals are under partner.steamgames.com/doc/…
- Godot: https://github.com/godotengine/godot/tags, https://github.com/godotengine/godot-builds/tags, https://github.com/godotengine/godot-docs (stable: `tutorials/rendering/renderers.rst`, `tutorials/editor/command_line_tutorial.rst`, `tutorials/export/exporting_for_windows.rst`, `classes/class_basematerial3d.rst`), https://github.com/godotengine/godot-website/tree/master/collections/_showcase, https://github.com/GodotSteam/GodotSteam
- Web stack: https://github.com/ceifa/steamworks.js, https://github.com/ArtyProf/steamworks-ffi-node, https://github.com/greenheartgames/greenworks/wiki/Apps-games-using-greenworks, https://github.com/tobspr-games/shapez.io, https://github.com/bitburner-official/bitburner-src, https://github.com/IvarK/AntimatterDimensionsSourceCode, https://github.com/electron-userland/electron-builder/blob/master/.changeset/wine-system-toolset.md, https://github.com/tauri-apps/tauri-docs/blob/v2/src/content/docs/distribute/windows-installer.mdx
- Versions: registry.npmjs.org (electron, three, @babylonjs/core, pixi.js, phaser, @tauri-apps/cli, nw, steamworks.js, steamworks-ffi-node, @electron/packager, postprocessing, three.quarks)

### Test files
Everything is in `/tmp/claude-0/-home-user/ef196b27-5c01-5b7b-a40c-9cba9648dbf8/scratchpad/`:
- Godot project, renders and exports: `gd/proj/`, `gd/proj/shot_forward_plus.png`, `gd/proj/build/win/T.exe`, `gd/proj/build/linux/T.x86_64`
- Electron test: `el/app/`, `el/app/shot.png`
- Software Vulkan driver used for the Godot render: `/tmp/lvp/usr/share/vulkan/icd.d/lvp_icd.json`