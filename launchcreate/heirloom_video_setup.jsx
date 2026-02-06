/**
 * Heirloom Video Production Setup Script
 *
 * After Effects ExtendScript (.jsx) that automatically sets up the complete
 * video production project with 28 compositions (1 App Store Preview,
 * 10 App Store Screenshots, 5 Website Heroes, 12 Ads), 19 capture
 * placeholders, and render queue presets.
 *
 * Usage:
 * 1. Open After Effects
 * 2. File → Scripts → Run Script File...
 * 3. Select this file
 * 4. Import actual captures to /Captures/ folder
 * 5. Alt+drag captures onto matching placeholder layers
 */

(function() {
    "use strict";

    // ============================================================
    // CONFIGURATION
    // ============================================================

    var CONFIG = {
        // App Store Preview dimensions (iPhone 15 Pro Max)
        appStore: {
            width: 1290,
            height: 2796,
            fps: 30,
            duration: 30
        },
        // Ad dimensions (standard vertical video)
        ads: {
            width: 1080,
            height: 1920,
            fps: 30,
            duration: 15
        },
        // Safe zones (pixels from edge)
        safeZones: {
            top: 150,      // Status bar
            bottom: 100,   // Home indicator
            sides: 40      // Left/right margins
        },
        // Brand colors
        colors: {
            background: [0.98, 0.96, 0.93],  // Warm cream (#FAF5ED)
            safeZone: [1, 0, 0.5]            // Magenta for guides
        }
    };

    // Capture placeholder definitions
    var CAPTURES = {
        "CAP_02":  { color: [1, 0.9, 0.2],     duration: 5, category: "Credits/premium" },
        "CAP_03":  { color: [0.2, 0.8, 0.2],   duration: 8, category: "Share/Import" },
        "CAP_03B": { color: [0.3, 0.7, 0.3],   duration: 5, category: "Share/Import" },
        "CAP_04":  { color: [0.2, 0.4, 0.9],   duration: 6, category: "P2P sharing" },
        "CAP_04B": { color: [0.3, 0.5, 0.8],   duration: 4, category: "P2P sharing" },
        "CAP_05":  { color: [0.6, 0.2, 0.8],   duration: 6, category: "Privacy/visibility" },
        "CAP_07B": { color: [1, 0.5, 0.1],     duration: 6, category: "Collections/detail" },
        "CAP_08":  { color: [0.9, 0.2, 0.2],   duration: 4, category: "Attestation/ownership" },
        "CAP_09":  { color: [0.8, 0.3, 0.3],   duration: 4, category: "Attestation/ownership" },
        "CAP_10":  { color: [0.2, 0.8, 0.9],   duration: 5, category: "AI/generation" },
        "CAP_11":  { color: [0.25, 0.75, 0.25],duration: 5, category: "Share/Import" },
        "CAP_12":  { color: [0.35, 0.75, 0.35],duration: 8, category: "Share/Import" },
        "CAP_13":  { color: [0.55, 0.25, 0.75],duration: 5, category: "Privacy/visibility" },
        "CAP_15":  { color: [0.95, 0.55, 0.15],duration: 8, category: "Collections/detail" },
        "CAP_17":  { color: [0.2, 0.6, 0.6],   duration: 6, category: "Scan" },
        "CAP_18":  { color: [0.25, 0.55, 0.55],duration: 5, category: "Scan" },
        "CAP_20":  { color: [0.25, 0.75, 0.85],duration: 6, category: "AI/generation" },
        "CAP_21":  { color: [0.95, 0.85, 0.25],duration: 5, category: "Credits/premium" },
        "CAP_22":  { color: [0.3, 0.5, 0.9],   duration: 6, category: "Voice/AI" }
    };

    // Ad composition configurations
    var AD_CONFIGS = [
        {
            name: "V01_SCREENSHOTS_GRAVEYARD",
            duration: 15,
            hookType: "Camera roll chaos",
            captures: ["CAP_03", "CAP_12", "CAP_11"],
            hookText: "Your camera roll is a recipe graveyard",
            ctaText: "Download Heirloom"
        },
        {
            name: "V02_EVEN_ASMR",
            duration: 15,
            hookType: "ASMR video playing",
            captures: ["CAP_03", "CAP_12", "CAP_13"],
            hookText: "Even your ASMR cooking videos deserve better",
            ctaText: "Download Heirloom"
        },
        {
            name: "V03_COOKBOOK_PAGE",
            duration: 15,
            hookType: "Cookbook flip",
            captures: ["CAP_17", "CAP_18", "CAP_07B", "CAP_08"],
            hookText: "That cookbook page deserves a better home",
            ctaText: "Download Heirloom"
        },
        {
            name: "V04_SCREENSHOT_A_RECIPE",
            duration: 15,
            hookType: "Screenshot action",
            captures: ["CAP_03", "CAP_12", "CAP_13"],
            hookText: "Stop screenshotting recipes",
            ctaText: "Download Heirloom"
        },
        {
            name: "V05_PRIVATE_BY_DEFAULT",
            duration: 15,
            hookType: "Grid of collections",
            captures: ["CAP_07B", "CAP_04", "CAP_05"],
            hookText: "Your recipes are private by default",
            ctaText: "Download Heirloom"
        },
        {
            name: "V06_SHARE_THAT_STICKS",
            duration: 15,
            hookType: "iMessage bubbles",
            captures: ["CAP_04", "CAP_04B", "CAP_07B"],
            hookText: "Share recipes that actually stick",
            ctaText: "Download Heirloom"
        },
        {
            name: "V07_GENERATOR",
            duration: 15,
            hookType: "Fridge/ingredients",
            captures: ["CAP_20", "CAP_10"],
            hookText: "What's in your fridge?",
            ctaText: "Download Heirloom"
        },
        {
            name: "V08_RANGE_MONTAGE",
            duration: 15,
            hookType: "Quick cuts montage",
            captures: ["CAP_12", "CAP_18", "CAP_07B"],
            hookText: "Save from anywhere",
            ctaText: "Download Heirloom"
        },
        {
            name: "V09_GRANDMAS_RECIPE",
            duration: 30,  // Extended version
            hookType: "Warm emotional",
            captures: ["CAP_22", "CAP_18", "CAP_07B"],
            hookText: "Grandma's recipes deserve to live forever",
            ctaText: "Download Heirloom"
        },
        {
            name: "V10_FREE_CREDITS",
            duration: 15,
            hookType: "Save action",
            captures: ["CAP_03", "CAP_02", "CAP_21"],
            hookText: "50 free credits to start saving recipes",
            ctaText: "Download Heirloom"
        },
        {
            name: "V11_RESPECT_CREATORS",
            duration: 15,
            hookType: "Attestation prompt",
            captures: ["CAP_08", "CAP_12", "CAP_13"],
            hookText: "Respect recipe creators",
            ctaText: "Download Heirloom"
        },
        {
            name: "V12_PUBLIC_ONLY_WHEN_YOURS",
            duration: 15,
            hookType: "Ownership check",
            captures: ["CAP_09", "CAP_05"],
            hookText: "Share publicly only when it's truly yours",
            ctaText: "Download Heirloom"
        }
    ];

    // App Store Screenshot composition configurations
    var SCREENSHOT_CONFIGS = [
        {
            name: "SS_01_COLLECTIONS_HOME",
            headline: "Your Recipe Box",
            subhead: "All your favorites, organized your way",
            capture: "CAP_07B",
            bgColor: [0.96, 0.90, 0.85]  // cream-to-terracotta
        },
        {
            name: "SS_02_SAVE_FROM_LINK",
            headline: "Save in One Tap",
            subhead: "From any link, video, or cookbook",
            capture: "CAP_03",
            bgColor: [0.88, 0.94, 0.88]  // sage green
        },
        {
            name: "SS_03_VIDEO_IMPORT",
            headline: "Videos Become Recipes",
            subhead: "TikTok, Instagram, YouTube \u2014 instant",
            capture: "CAP_12",
            bgColor: [0.96, 0.82, 0.78]  // coral-to-pink
        },
        {
            name: "SS_04_SCAN_COOKBOOK",
            headline: "Scan Any Cookbook",
            subhead: "Point, shoot, done",
            capture: "CAP_17",
            bgColor: [0.90, 0.82, 0.72]  // warm brown
        },
        {
            name: "SS_05_READ_RECIPE",
            headline: "Speak Your Recipe",
            subhead: "Dictate \u2014 Heirloom writes it down",
            capture: "CAP_22",
            bgColor: [0.82, 0.88, 0.96]  // soft blue
        },
        {
            name: "SS_06_AI_GENERATE",
            headline: "Make Something New",
            subhead: "Tell us what you have \u2014 get a recipe",
            capture: "CAP_20",
            bgColor: [0.90, 0.84, 0.96]  // purple-to-gold
        },
        {
            name: "SS_07_SHARE",
            headline: "Share Recipes That Stick",
            subhead: "Friends keep them forever",
            capture: "CAP_04",
            bgColor: [0.96, 0.90, 0.80]  // warm orange
        },
        {
            name: "SS_08_PRIVATE",
            headline: "Private by Default",
            subhead: "You control what\u2019s shared",
            capture: "CAP_05",
            bgColor: [0.82, 0.92, 0.85]  // deep green-to-cream
        },
        {
            name: "SS_09_ATTRIBUTION",
            headline: "Credit Where It\u2019s Due",
            subhead: "Track where recipes come from",
            capture: "CAP_13",
            bgColor: [0.96, 0.92, 0.78]  // warm gold
        },
        {
            name: "SS_10_PREMIUM",
            headline: "Start Free, Go Premium",
            subhead: "50 trial credits included. Unlimited with Premium.",
            capture: "CAP_02",
            bgColor: [0.96, 0.94, 0.85]  // gold-to-cream
        }
    ];

    // Website hero video composition configurations
    var HERO_CONFIGS = [
        {
            name: "HERO_LP1_SAVE",
            duration: 15,
            captures: ["CAP_03", "CAP_03B", "CAP_11"],
            route: "/"
        },
        {
            name: "HERO_LP2_SHARE",
            duration: 12,
            captures: ["CAP_04", "CAP_04B"],
            route: "/lp/share"
        },
        {
            name: "HERO_LP_VIDEO",
            duration: 15,
            captures: ["CAP_12", "CAP_13"],
            route: "/lp/video"
        },
        {
            name: "HERO_LP_SCAN",
            duration: 12,
            captures: ["CAP_17", "CAP_18"],
            route: "/lp/scan"
        },
        {
            name: "HERO_LP_GENERATE",
            duration: 12,
            captures: ["CAP_20", "CAP_10"],
            route: "/lp/generate"
        }
    ];

    // ============================================================
    // GLOBAL REFERENCES
    // ============================================================

    var folders = {};
    var blockComps = {};

    // ============================================================
    // UTILITY FUNCTIONS
    // ============================================================

    /**
     * Create a folder in the project panel, handling nesting
     */
    function createFolder(name, parent) {
        var folder = app.project.items.addFolder(name);
        if (parent) {
            folder.parentFolder = parent;
        }
        return folder;
    }

    /**
     * Apply ease out expression to a property
     */
    function applyEaseOut(prop, startVal, endVal, duration) {
        var expr = [
            "// Ease out animation",
            "var startTime = inPoint;",
            "var duration = " + duration + ";",
            "var startVal = " + JSON.stringify(startVal) + ";",
            "var endVal = " + JSON.stringify(endVal) + ";",
            "var t = (time - startTime) / duration;",
            "t = Math.min(Math.max(t, 0), 1);",
            "// Ease out cubic",
            "t = 1 - Math.pow(1 - t, 3);",
            "linear(t, 0, 1, startVal, endVal);"
        ].join("\n");

        try {
            prop.expression = expr;
        } catch (e) {
            // Fallback: set keyframes manually
            prop.setValueAtTime(0, startVal);
            prop.setValueAtTime(duration, endVal);
        }
    }

    /**
     * Add text animation (fade + slide up)
     */
    function applyTextAnimation(textLayer) {
        var animDuration = 8 / 30;  // 8 frames at 30fps

        // Opacity animation
        var opacity = textLayer.property("Transform").property("Opacity");
        opacity.setValueAtTime(textLayer.inPoint, 0);
        opacity.setValueAtTime(textLayer.inPoint + animDuration, 100);

        // Position animation (slide up 8px)
        var position = textLayer.property("Transform").property("Position");
        var startPos = position.value;
        position.setValueAtTime(textLayer.inPoint, [startPos[0], startPos[1] + 8]);
        position.setValueAtTime(textLayer.inPoint + animDuration, startPos);

        // Apply ease out to keyframes
        try {
            var opacityKeys = opacity.keyframes;
            var posKeys = position.keyframes;

            // Set ease on second keyframe
            var easeIn = new KeyframeEase(0, 33);
            var easeOut = new KeyframeEase(0, 75);

            opacity.setTemporalEaseAtKey(2, [easeIn], [easeOut]);
            position.setTemporalEaseAtKey(2, [easeIn, easeIn], [easeOut, easeOut]);
        } catch (e) {
            // Easing may not be available, continue without
        }
    }

    /**
     * Add a colored solid placeholder
     */
    function addPlaceholder(comp, captureId, startTime, duration, width, height) {
        var capConfig = CAPTURES[captureId];
        if (!capConfig) {
            alert("Warning: Unknown capture ID: " + captureId);
            capConfig = { color: [0.5, 0.5, 0.5], duration: 5, category: "Unknown" };
        }

        var useDuration = duration || capConfig.duration;

        var solid = comp.layers.addSolid(
            capConfig.color,
            captureId,
            width || comp.width,
            height || comp.height,
            1,
            useDuration
        );

        solid.startTime = startTime;
        solid.outPoint = startTime + useDuration;

        // Add comment with category
        solid.comment = capConfig.category;

        return solid;
    }

    /**
     * Add text layer with standard styling
     */
    function addTextLayer(comp, text, startTime, duration, yPosition) {
        var textLayer = comp.layers.addText(text);

        // Set timing
        textLayer.startTime = startTime;
        textLayer.outPoint = startTime + duration;

        // Style the text
        var textProp = textLayer.property("Source Text");
        var textDoc = textProp.value;

        textDoc.resetCharStyle();
        textDoc.fontSize = 72;
        textDoc.fillColor = [0.1, 0.1, 0.1];  // Near black

        // Try fonts in order of preference (use PostScript names)
        var fontOptions = ["SFProDisplay-Regular", "HelveticaNeue", "Helvetica", "Arial"];
        for (var f = 0; f < fontOptions.length; f++) {
            try {
                textDoc.font = fontOptions[f];
                break;
            } catch (e) {
                // Font not available, try next
            }
        }

        textDoc.justification = ParagraphJustification.CENTER_JUSTIFY;

        textProp.setValue(textDoc);

        // Center horizontally, position at specified Y
        var position = textLayer.property("Transform").property("Position");
        position.setValue([comp.width / 2, yPosition || comp.height * 0.15]);

        // Apply animation
        applyTextAnimation(textLayer);

        return textLayer;
    }

    /**
     * Add safe zone guides to a composition
     */
    function addSafeZoneGuides(comp) {
        var guideColor = CONFIG.colors.safeZone;
        var sz = CONFIG.safeZones;

        // Create shape layer for guides
        var guideLayer = comp.layers.addShape();
        guideLayer.name = "SAFE_ZONE_GUIDES";
        guideLayer.guideLayer = true;

        var contents = guideLayer.property("Contents");

        // Helper to add rectangle
        function addGuideRect(name, x, y, width, height) {
            var group = contents.addProperty("ADBE Vector Group");
            group.name = name;

            var rect = group.property("Contents").addProperty("ADBE Vector Shape - Rect");
            var rectPath = rect.property("ADBE Vector Rect Size");
            rectPath.setValue([width, height]);

            var rectPos = rect.property("ADBE Vector Rect Position");
            rectPos.setValue([x - comp.width/2 + width/2, y - comp.height/2 + height/2]);

            var stroke = group.property("Contents").addProperty("ADBE Vector Graphic - Stroke");
            stroke.property("Color").setValue(guideColor);
            stroke.property("Stroke Width").setValue(2);

            var fill = group.property("Contents").addProperty("ADBE Vector Graphic - Fill");
            fill.property("Opacity").setValue(0);
        }

        // Top safe zone
        addGuideRect("Top Safe", 0, 0, comp.width, sz.top);

        // Bottom safe zone
        addGuideRect("Bottom Safe", 0, comp.height - sz.bottom, comp.width, sz.bottom);

        // Left safe zone
        addGuideRect("Left Safe", 0, sz.top, sz.sides, comp.height - sz.top - sz.bottom);

        // Right safe zone
        addGuideRect("Right Safe", comp.width - sz.sides, sz.top, sz.sides, comp.height - sz.top - sz.bottom);

        // Move guides to top, then lock
        guideLayer.moveToBeginning();
        guideLayer.locked = true;

        return guideLayer;
    }

    /**
     * Add transition markers to a layer
     */
    function addTransitionMarker(layer, time, comment) {
        var marker = new MarkerValue(comment || "Transition");
        marker.duration = 8 / 30;  // 8 frames
        layer.property("Marker").setValueAtTime(time, marker);
    }

    // ============================================================
    // PHASE 1: PROJECT STRUCTURE
    // ============================================================

    function createProjectStructure() {
        app.beginUndoGroup("Create Project Structure");

        // Root folders
        folders.captures = createFolder("Captures");
        folders.compositions = createFolder("Compositions");
        folders.assets = createFolder("Assets");
        folders.exports = createFolder("Exports");

        // Composition subfolders
        folders.blocks = createFolder("_Blocks", folders.compositions);
        folders.appStore = createFolder("App Store", folders.compositions);
        folders.screenshots = createFolder("Screenshots", folders.compositions);
        folders.heroes = createFolder("Website Heroes", folders.compositions);
        folders.ads = createFolder("Ads", folders.compositions);

        // Asset subfolders
        folders.logo = createFolder("Logo", folders.assets);
        folders.endCard = createFolder("End Card", folders.assets);
        folders.appStoreBadge = createFolder("App Store Badge", folders.assets);

        app.endUndoGroup();
    }

    // ============================================================
    // PHASE 2: CAPTURE PLACEHOLDERS
    // ============================================================

    function createCapturePlaceholders() {
        app.beginUndoGroup("Create Capture Placeholders");

        // Create a helper composition to hold placeholder solids
        var helperComp = app.project.items.addComp(
            "_Placeholder_Source",
            CONFIG.appStore.width,
            CONFIG.appStore.height,
            1,
            30,  // 30 second duration to hold all
            CONFIG.appStore.fps
        );
        helperComp.parentFolder = folders.captures;

        // Create each placeholder solid
        for (var capId in CAPTURES) {
            if (CAPTURES.hasOwnProperty(capId)) {
                var cap = CAPTURES[capId];
                var solid = helperComp.layers.addSolid(
                    cap.color,
                    capId,
                    CONFIG.appStore.width,
                    CONFIG.appStore.height,
                    1,
                    cap.duration
                );
                solid.comment = cap.category;
            }
        }

        app.endUndoGroup();
    }

    // ============================================================
    // PHASE 3: BLOCK PRE-COMPS
    // ============================================================

    function createBlockPreComps() {
        app.beginUndoGroup("Create Block Pre-Comps");

        var w = CONFIG.appStore.width;
        var h = CONFIG.appStore.height;
        var fps = CONFIG.appStore.fps;

        // Block A: Hook (2.5s)
        blockComps.A = app.project.items.addComp("_BLOCK_A_HOOK", w, h, 1, 2.5, fps);
        blockComps.A.parentFolder = folders.blocks;

        // Add background
        var bgA = blockComps.A.layers.addSolid(
            CONFIG.colors.background,
            "Background",
            w, h, 1, 2.5
        );

        // Add placeholder for hook visual
        var hookPlaceholder = blockComps.A.layers.addSolid(
            [0.4, 0.4, 0.4],
            "HOOK_PLACEHOLDER",
            w, h, 1, 2.5
        );
        hookPlaceholder.property("Transform").property("Opacity").setValue(80);

        // Add hook text layer
        addTextLayer(blockComps.A, "[HOOK TEXT]", 0, 2.5, h * 0.12);

        // Block B: Behavior (3.5s)
        blockComps.B = app.project.items.addComp("_BLOCK_B_BEHAVIOR", w, h, 1, 3.5, fps);
        blockComps.B.parentFolder = folders.blocks;

        var bgB = blockComps.B.layers.addSolid(CONFIG.colors.background, "Background", w, h, 1, 3.5);
        var capB = blockComps.B.layers.addSolid([0.5, 0.5, 0.5], "CAP_PLACEHOLDER", w, h, 1, 3.5);
        addTransitionMarker(capB, 0, "Block B Start");
        addTransitionMarker(capB, 3.5, "Block B End");

        // Block C: Magic (6s)
        blockComps.C = app.project.items.addComp("_BLOCK_C_MAGIC", w, h, 1, 6, fps);
        blockComps.C.parentFolder = folders.blocks;

        var bgC = blockComps.C.layers.addSolid(CONFIG.colors.background, "Background", w, h, 1, 6);

        // Multiple placeholder layers for sequence
        var cap1 = blockComps.C.layers.addSolid([0.45, 0.45, 0.45], "CAP_SEQUENCE_1", w, h, 1, 2);
        cap1.startTime = 0;
        cap1.outPoint = 2;

        var cap2 = blockComps.C.layers.addSolid([0.5, 0.5, 0.5], "CAP_SEQUENCE_2", w, h, 1, 2);
        cap2.startTime = 2;
        cap2.outPoint = 4;

        var cap3 = blockComps.C.layers.addSolid([0.55, 0.55, 0.55], "CAP_SEQUENCE_3", w, h, 1, 2);
        cap3.startTime = 4;
        cap3.outPoint = 6;

        addTextLayer(blockComps.C, "[MAGIC TEXT]", 0.5, 5, h * 0.12);

        // Block D: Trust (4s)
        blockComps.D = app.project.items.addComp("_BLOCK_D_TRUST", w, h, 1, 4, fps);
        blockComps.D.parentFolder = folders.blocks;

        var bgD = blockComps.D.layers.addSolid(CONFIG.colors.background, "Background", w, h, 1, 4);
        var capD = blockComps.D.layers.addSolid([0.5, 0.5, 0.5], "CAP_PLACEHOLDER", w, h, 1, 4);
        addTextLayer(blockComps.D, "[TRUST TEXT]", 0, 4, h * 0.12);

        // Block E: CTA (3s)
        blockComps.E = app.project.items.addComp("_BLOCK_E_CTA", w, h, 1, 3, fps);
        blockComps.E.parentFolder = folders.blocks;

        var bgE = blockComps.E.layers.addSolid(CONFIG.colors.background, "Background", w, h, 1, 3);

        // Logo placeholder
        var logoPlaceholder = blockComps.E.layers.addSolid(
            [0.96, 0.52, 0.27],  // Heirloom orange
            "LOGO_PLACEHOLDER",
            200, 200, 1, 3
        );
        var logoPos = logoPlaceholder.property("Transform").property("Position");
        logoPos.setValue([w / 2, h * 0.35]);

        // App Store badge placeholder
        var badgePlaceholder = blockComps.E.layers.addSolid(
            [0.1, 0.1, 0.1],
            "APP_STORE_BADGE",
            280, 84, 1, 3
        );
        var badgePos = badgePlaceholder.property("Transform").property("Position");
        badgePos.setValue([w / 2, h * 0.55]);

        // CTA text
        addTextLayer(blockComps.E, "Download Heirloom", 0, 3, h * 0.7);

        app.endUndoGroup();
    }

    // ============================================================
    // PHASE 4: APP STORE PREVIEW COMPOSITION
    // ============================================================

    function createAppStoreComp() {
        app.beginUndoGroup("Create App Store Preview");

        var w = CONFIG.appStore.width;
        var h = CONFIG.appStore.height;
        var fps = CONFIG.appStore.fps;
        var dur = CONFIG.appStore.duration;

        var comp = app.project.items.addComp("HEIRLOOM_APPSTORE_PREVIEW", w, h, 1, dur, fps);
        comp.parentFolder = folders.appStore;

        // Background (bottom layer)
        var bg = comp.layers.addSolid(CONFIG.colors.background, "Background", w, h, 1, dur);

        // Corrected storyboard layer stack (added bottom to top, reverse order)
        // See Part 2 of Creative Asset Master Plan

        // [25-30s] CTA end card: "Download Heirloom"
        var ctaLayer = comp.layers.add(blockComps.E);
        ctaLayer.startTime = 25;
        ctaLayer.outPoint = 30;
        ctaLayer.name = "BLOCK_E_CTA";

        // [21-25s] CAP_05 — Privacy pills + "Private by default"
        var cap05 = addPlaceholder(comp, "CAP_05", 21, 4, w, h);
        addTransitionMarker(cap05, 21, "Privacy Pills");

        // [17-21s] CAP_22 — Voice dictation: tap mic > speak > transcription
        var cap22 = addPlaceholder(comp, "CAP_22", 17, 4, w, h);
        addTransitionMarker(cap22, 17, "Voice Dictation");

        // [13-17s] CAP_17 > CAP_18 — Camera scan of cookbook page > extracted recipe
        var cap18 = addPlaceholder(comp, "CAP_18", 15, 2, w, h);
        var cap17 = addPlaceholder(comp, "CAP_17", 13, 2, w, h);
        addTransitionMarker(cap17, 13, "Scan Sequence");

        // [8-13s] CAP_12 — Paste video URL > import progress > recipe result
        var cap12 = addPlaceholder(comp, "CAP_12", 8, 5, w, h);
        addTransitionMarker(cap12, 8, "Video Import");

        // [4-8s] CAP_03 > CAP_03B > CAP_11 — Safari share sheet > tap Heirloom > "Saved" toast
        var cap11 = addPlaceholder(comp, "CAP_11", 7, 1, w, h);
        var cap03b = addPlaceholder(comp, "CAP_03B", 6, 1, w, h);
        var cap03 = addPlaceholder(comp, "CAP_03", 4, 2, w, h);
        addTransitionMarker(cap03, 4, "Share Extension Flow");

        // [0-4s] CAP_07B — Hook: "Your recipes, finally organized" over collections grid
        var cap07b = addPlaceholder(comp, "CAP_07B", 0, 4, w, h);
        addTransitionMarker(cap07b, 0, "Hook - Collections");

        // Text overlays matching corrected storyboard
        addTextLayer(comp, "Your recipes, finally organized", 0, 4, h * 0.1);
        addTextLayer(comp, "Save in one tap", 4, 4, h * 0.1);
        addTextLayer(comp, "Even from videos", 8, 5, h * 0.1);
        addTextLayer(comp, "Scan any cookbook", 13, 4, h * 0.1);
        addTextLayer(comp, "Speak your recipe", 17, 4, h * 0.1);
        addTextLayer(comp, "Private by default", 21, 4, h * 0.1);

        // Add safe zone guides
        addSafeZoneGuides(comp);

        app.endUndoGroup();

        return comp;
    }

    // ============================================================
    // PHASE 4: AD COMPOSITIONS
    // ============================================================

    function createAdComp(config) {
        var isExtended = config.duration === 30;
        var w = CONFIG.ads.width;
        var h = CONFIG.ads.height;
        var fps = CONFIG.ads.fps;
        var dur = config.duration;

        var comp = app.project.items.addComp(config.name, w, h, 1, dur, fps);
        comp.parentFolder = folders.ads;

        // Background
        var bg = comp.layers.addSolid(CONFIG.colors.background, "Background", w, h, 1, dur);

        // Calculate timing based on duration
        var hookEnd = 2.5;
        var behaviorEnd = isExtended ? 8 : 6;
        var magicEnd = isExtended ? 20 : 12;
        var trustEnd = isExtended ? 27 : dur;

        // Add hook placeholder
        var hookPlaceholder = comp.layers.addSolid(
            [0.4, 0.4, 0.4],
            "HOOK_" + config.hookType.toUpperCase().replace(/ /g, "_"),
            w, h, 1, hookEnd
        );
        hookPlaceholder.startTime = 0;
        hookPlaceholder.outPoint = hookEnd;
        hookPlaceholder.comment = "Hook: " + config.hookType;

        // Add captures based on config
        // Captures fill from hookEnd (2.5s) to magicEnd (12s for 15s ads, 20s for 30s ads)
        var captures = config.captures;
        var captureStart = hookEnd;
        var captureDuration = (magicEnd - captureStart) / captures.length;

        for (var i = 0; i < captures.length; i++) {
            var capId = captures[i];
            var startTime = captureStart + (i * captureDuration);
            var endTime = startTime + captureDuration;

            // Ensure we don't exceed magic end
            if (endTime > magicEnd) endTime = magicEnd;

            var capLayer = addPlaceholder(comp, capId, startTime, endTime - startTime, w, h);
            addTransitionMarker(capLayer, startTime, capId);
        }

        // CTA section - create ad-specific layers (not shared pre-comp)
        var ctaStart = isExtended ? trustEnd : magicEnd;
        var ctaDuration = dur - ctaStart;

        if (isExtended) {
            // Extended version: Trust block then CTA
            var trustPlaceholder = comp.layers.addSolid(
                [0.5, 0.5, 0.5],
                "TRUST_PLACEHOLDER",
                w, h, 1, trustEnd - magicEnd
            );
            trustPlaceholder.startTime = magicEnd;
            trustPlaceholder.outPoint = trustEnd;
        }

        // Create CTA elements directly in this comp (ad-specific, editable per ad)
        // CTA Background
        var ctaBg = comp.layers.addSolid(
            CONFIG.colors.background,
            "CTA_BACKGROUND",
            w, h, 1, ctaDuration
        );
        ctaBg.startTime = ctaStart;
        ctaBg.outPoint = dur;

        // Logo placeholder
        var logoPlaceholder = comp.layers.addSolid(
            [0.96, 0.52, 0.27],  // Heirloom orange
            "CTA_LOGO",
            160, 160, 1, ctaDuration
        );
        logoPlaceholder.startTime = ctaStart;
        logoPlaceholder.outPoint = dur;
        var logoPos = logoPlaceholder.property("Transform").property("Position");
        logoPos.setValue([w / 2, h * 0.35]);

        // App Store badge placeholder
        var badgePlaceholder = comp.layers.addSolid(
            [0.1, 0.1, 0.1],
            "CTA_APP_STORE_BADGE",
            224, 67, 1, ctaDuration
        );
        badgePlaceholder.startTime = ctaStart;
        badgePlaceholder.outPoint = dur;
        var badgePos = badgePlaceholder.property("Transform").property("Position");
        badgePos.setValue([w / 2, h * 0.55]);

        // Text overlays
        addTextLayer(comp, config.hookText, 0, hookEnd, h * 0.1);
        addTextLayer(comp, config.ctaText, ctaStart, ctaDuration, h * 0.7);

        // Add safe zone guides
        addSafeZoneGuides(comp);

        return comp;
    }

    function createAllAdComps() {
        app.beginUndoGroup("Create Ad Compositions");

        for (var i = 0; i < AD_CONFIGS.length; i++) {
            createAdComp(AD_CONFIGS[i]);
        }

        app.endUndoGroup();
    }

    // ============================================================
    // PHASE 5: APP STORE SCREENSHOT COMPOSITIONS
    // ============================================================

    function createScreenshotComp(config) {
        var w = CONFIG.appStore.width;
        var h = CONFIG.appStore.height;
        var fps = CONFIG.appStore.fps;

        // Single-frame composition (1 frame at 30fps)
        var comp = app.project.items.addComp(config.name, w, h, 1, 1 / fps, fps);
        comp.parentFolder = folders.screenshots;

        // Background solid with per-screenshot color
        var bg = comp.layers.addSolid(config.bgColor, "Background", w, h, 1, 1 / fps);

        // Capture placeholder (bottom 75% of frame — device mockup area)
        var captureH = Math.round(h * 0.75);
        var captureW = Math.round(captureH * (1290 / 2796));  // Maintain device aspect ratio
        var captureY = h - (captureH / 2);  // Anchored near bottom

        var capConfig = CAPTURES[config.capture];
        var capColor = capConfig ? capConfig.color : [0.5, 0.5, 0.5];

        var capLayer = comp.layers.addSolid(
            capColor,
            config.capture + "_PLACEHOLDER",
            captureW, captureH, 1, 1 / fps
        );
        var capPos = capLayer.property("Transform").property("Position");
        capPos.setValue([w / 2, captureY]);
        capLayer.comment = "Replace with " + config.capture + " screenshot inside device frame";

        // Headline text (SF Pro Display Bold, 72pt, centered, near top)
        var headlineLayer = comp.layers.addText(config.headline);
        headlineLayer.startTime = 0;
        headlineLayer.outPoint = 1 / fps;

        var headlineProp = headlineLayer.property("Source Text");
        var headlineDoc = headlineProp.value;
        headlineDoc.resetCharStyle();
        headlineDoc.fontSize = 72;
        headlineDoc.fillColor = [0.17, 0.17, 0.17];  // #2C2C2C

        var headlineFonts = ["SFProDisplay-Bold", "HelveticaNeue-Bold", "Helvetica-Bold", "Arial-BoldMT"];
        for (var f = 0; f < headlineFonts.length; f++) {
            try {
                headlineDoc.font = headlineFonts[f];
                break;
            } catch (e) {}
        }

        headlineDoc.justification = ParagraphJustification.CENTER_JUSTIFY;
        headlineProp.setValue(headlineDoc);

        var headlinePos = headlineLayer.property("Transform").property("Position");
        headlinePos.setValue([w / 2, h * 0.08]);

        // Subhead text (SF Pro Display Regular, 42pt, centered, below headline)
        var subheadLayer = comp.layers.addText(config.subhead);
        subheadLayer.startTime = 0;
        subheadLayer.outPoint = 1 / fps;

        var subheadProp = subheadLayer.property("Source Text");
        var subheadDoc = subheadProp.value;
        subheadDoc.resetCharStyle();
        subheadDoc.fontSize = 42;
        subheadDoc.fillColor = [0.4, 0.4, 0.4];  // #666666

        var subheadFonts = ["SFProDisplay-Regular", "HelveticaNeue", "Helvetica", "Arial"];
        for (var g = 0; g < subheadFonts.length; g++) {
            try {
                subheadDoc.font = subheadFonts[g];
                break;
            } catch (e) {}
        }

        subheadDoc.justification = ParagraphJustification.CENTER_JUSTIFY;
        subheadProp.setValue(subheadDoc);

        var subheadPos = subheadLayer.property("Transform").property("Position");
        subheadPos.setValue([w / 2, h * 0.12]);

        return comp;
    }

    function createAllScreenshotComps() {
        app.beginUndoGroup("Create Screenshot Compositions");

        for (var i = 0; i < SCREENSHOT_CONFIGS.length; i++) {
            createScreenshotComp(SCREENSHOT_CONFIGS[i]);
        }

        app.endUndoGroup();
    }

    // ============================================================
    // PHASE 6: WEBSITE HERO VIDEO COMPOSITIONS
    // ============================================================

    function createHeroComp(config) {
        var w = 1920;
        var h = 1080;
        var fps = CONFIG.appStore.fps;
        var dur = config.duration;

        var comp = app.project.items.addComp(config.name, w, h, 1, dur, fps);
        comp.parentFolder = folders.heroes;
        comp.comment = "Website hero for route: " + config.route;

        // Warm cream background
        var bg = comp.layers.addSolid(CONFIG.colors.background, "Background", w, h, 1, dur);

        // Device frame placeholder (centered, 9:19.5 phone aspect within 16:9)
        var deviceH = Math.round(h * 0.85);
        var deviceW = Math.round(deviceH * (1290 / 2796));

        // Add capture placeholders sequenced across duration
        var captures = config.captures;
        var segDuration = dur / captures.length;

        for (var i = 0; i < captures.length; i++) {
            var capId = captures[i];
            var startTime = i * segDuration;

            var capConfig = CAPTURES[capId];
            var capColor = capConfig ? capConfig.color : [0.5, 0.5, 0.5];

            var capLayer = comp.layers.addSolid(
                capColor,
                capId,
                deviceW, deviceH, 1, segDuration
            );
            capLayer.startTime = startTime;
            capLayer.outPoint = startTime + segDuration;

            var capPos = capLayer.property("Transform").property("Position");
            capPos.setValue([w / 2, h / 2]);

            capLayer.comment = capId + " — replace with screen recording inside device frame";
            addTransitionMarker(capLayer, startTime, capId);
        }

        return comp;
    }

    function createAllHeroComps() {
        app.beginUndoGroup("Create Hero Compositions");

        for (var i = 0; i < HERO_CONFIGS.length; i++) {
            createHeroComp(HERO_CONFIGS[i]);
        }

        app.endUndoGroup();
    }

    // ============================================================
    // PHASE 7: RENDER QUEUE PRESETS
    // ============================================================

    function setupRenderQueue() {
        app.beginUndoGroup("Setup Render Queue");

        var rq = app.project.renderQueue;

        // Find all compositions to add
        var compsToRender = [];

        for (var i = 1; i <= app.project.numItems; i++) {
            var item = app.project.item(i);
            if (item instanceof CompItem) {
                // Skip block pre-comps and helper comps
                if (item.name.indexOf("_BLOCK_") === 0 || item.name.indexOf("_Placeholder") === 0) {
                    continue;
                }
                // Add main comps (App Store, Ads, Screenshots, Heroes)
                if (item.name.indexOf("HEIRLOOM_") === 0 || item.name.indexOf("V") === 0 ||
                    item.name.indexOf("SS_") === 0 || item.name.indexOf("HERO_") === 0) {
                    compsToRender.push(item);
                }
            }
        }

        // Add each to render queue
        for (var j = 0; j < compsToRender.length; j++) {
            var comp = compsToRender[j];
            var rqItem = rq.items.add(comp);

            // Set output module (H.264 settings)
            // Note: Exact template names depend on AE version
            try {
                var om = rqItem.outputModule(1);

                // Try to apply H.264 preset
                try {
                    om.applyTemplate("H.264 - Match Render Settings - 15 Mbps");
                } catch (e1) {
                    try {
                        om.applyTemplate("H.264");
                    } catch (e2) {
                        // Use default
                    }
                }

                // Set output path
                var outputFolder = folders.exports ? folders.exports : app.project.file.parent;
                var outputPath;

                if (outputFolder instanceof FolderItem) {
                    // Can't directly get path from FolderItem, use project location
                    var projectPath = app.project.file ? app.project.file.parent.fsName : "~/Desktop";
                    outputPath = projectPath + "/Exports/" + comp.name + ".mp4";
                } else {
                    outputPath = "~/Desktop/Heirloom_Exports/" + comp.name + ".mp4";
                }

                om.file = new File(outputPath);

            } catch (e) {
                // Output module settings may vary by AE version
            }
        }

        app.endUndoGroup();
    }

    // ============================================================
    // MAIN EXECUTION
    // ============================================================

    function main() {
        // Confirm before running
        var confirm = Window.confirm(
            "Heirloom Video Setup Script\n\n" +
            "This will create:\n" +
            "• Project folder structure\n" +
            "• 19 capture placeholders\n" +
            "• 5 block pre-compositions\n" +
            "• 1 App Store Preview (30s)\n" +
            "• 10 App Store Screenshot compositions\n" +
            "• 5 Website Hero video compositions\n" +
            "• 12 Ad compositions (15-30s)\n" +
            "• Render queue with all comps\n\n" +
            "Total: 28 compositions + 5 block pre-comps\n\n" +
            "Continue?",
            true,
            "Heirloom Setup"
        );

        if (!confirm) {
            return;
        }

        // Start progress
        var startTime = new Date().getTime();

        try {
            // Phase 1: Project structure
            $.writeln("Phase 1: Creating project structure...");
            createProjectStructure();

            // Phase 2: Capture placeholders
            $.writeln("Phase 2: Creating capture placeholders...");
            createCapturePlaceholders();

            // Phase 3: Block pre-comps
            $.writeln("Phase 3: Creating block pre-compositions...");
            createBlockPreComps();

            // Phase 4: App Store composition
            $.writeln("Phase 4: Creating App Store Preview...");
            createAppStoreComp();

            // Phase 4b: Ad compositions
            $.writeln("Phase 4b: Creating Ad compositions...");
            createAllAdComps();

            // Phase 5: Screenshot compositions
            $.writeln("Phase 5: Creating App Store Screenshot compositions...");
            createAllScreenshotComps();

            // Phase 6: Website hero compositions
            $.writeln("Phase 6: Creating Website Hero compositions...");
            createAllHeroComps();

            // Phase 7: Render queue
            $.writeln("Phase 7: Setting up render queue...");
            setupRenderQueue();

            // Complete
            var endTime = new Date().getTime();
            var elapsed = ((endTime - startTime) / 1000).toFixed(1);

            alert(
                "Heirloom Video Setup Complete!\n\n" +
                "Created in " + elapsed + " seconds:\n" +
                "• 4 root folders with subfolders\n" +
                "• 19 capture placeholders (CAP_02\u2013CAP_22)\n" +
                "• 5 block pre-compositions\n" +
                "• 1 App Store Preview (30s @ 1290x2796)\n" +
                "• 10 App Store Screenshot compositions (1290x2796)\n" +
                "• 5 Website Hero compositions (1920x1080)\n" +
                "• 12 Ad compositions (15-30s @ 1080x1920)\n" +
                "• Render queue with all outputs\n\n" +
                "Total: 28 compositions + 5 block pre-comps\n\n" +
                "Next steps:\n" +
                "1. Import captures to /Captures/ folder\n" +
                "2. Alt+drag onto matching placeholder layers\n" +
                "3. Adjust timing as needed\n" +
                "4. Render from queue",
                "Setup Complete"
            );

        } catch (e) {
            alert(
                "Error during setup:\n\n" +
                e.toString() + "\n\n" +
                "Line: " + e.line,
                "Error"
            );
        }
    }

    // Run the script
    main();

})();
