/**
 * Heirloom Video Production Setup Script
 *
 * After Effects ExtendScript (.jsx) that sets up the complete video production
 * project per the Video Creative Production Guide (05-video-creative-production.md).
 *
 * Implements:
 *   - Section A: Brand guidelines ("Warm Ceramic Calm" palette, motion language, typography)
 *   - Section C: App Store Preview 30s storyboard (frame-by-frame with transitions)
 *   - Section D: 12 paid ad variants with approved hook text
 *   - Section G: After Effects assembly rules (text presets, end card spec, safe margins)
 *
 * Usage:
 *   1. Open After Effects
 *   2. File > Scripts > Run Script File...
 *   3. Select this file
 *   4. Import captures to /Captures/ folder
 *   5. Alt+drag captures onto matching placeholder layers
 */

(function() {
    "use strict";

    // ============================================================
    // CONFIGURATION — Section A.1 Visual Identity + Section G
    // ============================================================

    var CONFIG = {
        // App Store Preview (iPhone 15 Pro Max) — Section C specs
        appStore: {
            width: 1290,
            height: 2796,
            fps: 30,
            duration: 30
        },
        // Paid ads (standard vertical) — Section D
        ads: {
            width: 1080,
            height: 1920,
            fps: 30,
            duration: 15
        },
        // Safe zones — Section G
        safeZones: {
            top: 150,
            bottom: 100,
            sides: 40
        },
        // Brand palette — Section A.1 "Warm Ceramic Calm"
        colors: {
            cream:      [250/255, 245/255, 240/255],  // #FAF5F0 — base
            terracotta: [224/255, 123/255,  84/255],   // #E07B54 — warm accent
            sage:       [ 76/255, 175/255,  80/255],   // #4CAF50 — trust/privacy
            charcoal:   [ 44/255,  44/255,  44/255],   // #2C2C2C — text
            nearBlack:  [ 26/255,  26/255,  26/255],   // #1A1A1A — strong text
            white:      [1, 1, 1],
            guideColor: [1, 0, 0.5]                     // Magenta for safe zone guides
        },
        // Section G — Text animation preset
        textAnim: {
            fadeFrames: 8,         // 0% > 100% over 8 frames
            slidePixels: 8,        // +8px Y > 0
            easeInfluence: 33,     // Ease Out 33% influence
            holdMin: 0.8           // Hold key states 0.8s minimum
        },
        // Section G — Transition presets
        transitions: {
            dissolveFrames: 8,     // Cross-dissolve 6-10 frames, using 8
            slidePixels: 12,       // Slide 8-16px, using 12
            dissolveSeconds: 8/30  // 8 frames at 30fps
        },
        // Section G — End card specification
        endCard: {
            logoYPercent: 0.40,    // Center, 40% from top
            logoWidth: 180,        // 180px width
            badgeYPercent: 0.70,   // Center, 70% from top
            badgeWidth: 200,       // 200px width
            ctaYPercent: 0.85,     // Center, 85% from top
            ctaFontSize: 48        // 48pt
        }
    };

    // ============================================================
    // CAPTURE PLACEHOLDERS — Section E Master Capture Map
    // ============================================================

    var CAPTURES = {
        "CAP_02":  { color: [1, 0.9, 0.2],      duration: 5, category: "Credits/premium" },
        "CAP_03":  { color: [0.2, 0.8, 0.2],     duration: 8, category: "Share/Import" },
        "CAP_03B": { color: [0.3, 0.7, 0.3],     duration: 5, category: "Share/Import" },
        "CAP_04":  { color: [0.2, 0.4, 0.9],     duration: 6, category: "P2P sharing" },
        "CAP_04B": { color: [0.3, 0.5, 0.8],     duration: 4, category: "P2P sharing" },
        "CAP_05":  { color: [0.6, 0.2, 0.8],     duration: 6, category: "Privacy/visibility" },
        "CAP_07B": { color: [1, 0.5, 0.1],       duration: 6, category: "Collections/detail" },
        "CAP_08":  { color: [0.9, 0.2, 0.2],     duration: 4, category: "Attestation/ownership" },
        "CAP_09":  { color: [0.8, 0.3, 0.3],     duration: 4, category: "Attestation/ownership" },
        "CAP_10":  { color: [0.2, 0.8, 0.9],     duration: 5, category: "AI/generation" },
        "CAP_11":  { color: [0.25, 0.75, 0.25],  duration: 5, category: "Share/Import" },
        "CAP_12":  { color: [0.35, 0.75, 0.35],  duration: 8, category: "Share/Import" },
        "CAP_13":  { color: [0.55, 0.25, 0.75],  duration: 5, category: "Privacy/visibility" },
        "CAP_15":  { color: [0.95, 0.55, 0.15],  duration: 8, category: "Collections/detail" },
        "CAP_17":  { color: [0.2, 0.6, 0.6],     duration: 6, category: "Scan" },
        "CAP_18":  { color: [0.25, 0.55, 0.55],  duration: 5, category: "Scan" },
        "CAP_20":  { color: [0.25, 0.75, 0.85],  duration: 6, category: "AI/generation" },
        "CAP_21":  { color: [0.95, 0.85, 0.25],  duration: 5, category: "Credits/premium" },
        "CAP_22":  { color: [0.3, 0.5, 0.9],     duration: 6, category: "Voice/AI" },
        "CAP_24":  { color: [0.85, 0.55, 0.2],   duration: 6, category: "Family/lineage" }
    };

    // ============================================================
    // SECTION C — App Store Preview Storyboard (Frame-by-Frame)
    // ============================================================

    var APP_STORE_STORYBOARD = [
        {
            segment: "Hook",
            startTime: 0,
            endTime: 4,
            captures: ["CAP_07B"],
            text: "Your family\u2019s recipes, finally preserved",
            transition: "fade_zoom"  // Fade in + slight zoom
        },
        {
            segment: "Save",
            startTime: 4,
            endTime: 8,
            captures: ["CAP_03", "CAP_03B", "CAP_11"],
            text: "Save in one tap",
            transition: "cut"
        },
        {
            segment: "Video",
            startTime: 8,
            endTime: 13,
            captures: ["CAP_12"],
            text: "Even from videos",
            transition: "dissolve"
        },
        {
            segment: "Scan",
            startTime: 13,
            endTime: 17,
            captures: ["CAP_17", "CAP_18"],
            text: "Scan any cookbook",
            transition: "cut"
        },
        {
            segment: "Lineage",
            startTime: 17,
            endTime: 21,
            captures: ["CAP_24"],
            text: "Preserve your family\u2019s recipes",
            transition: "dissolve"
        },
        {
            segment: "Trust",
            startTime: 21,
            endTime: 25,
            captures: ["CAP_05"],
            text: "Private by default",
            transition: "dissolve"
        },
        {
            segment: "CTA",
            startTime: 25,
            endTime: 30,
            captures: [],  // End card, no captures
            text: "Download Heirloom",
            transition: "dissolve"
        }
    ];

    // ============================================================
    // SECTION D — Paid Ad Variants (approved hook text)
    // ============================================================

    var AD_CONFIGS = [
        {
            name: "V01_SCREENSHOTS_GRAVEYARD",
            duration: 15,
            hookText: "I screenshot every recipe\u2026 and lose it.",
            captures: ["CAP_03", "CAP_12", "CAP_11"],
            magicText: "One tap. Real recipe.",
            ctaText: "Preserve your family\u2019s recipes."
        },
        {
            name: "V02_EVEN_ASMR",
            duration: 15,
            hookText: "This recipe was ASMR\u2026 and I still saved it.",
            captures: ["CAP_03", "CAP_12", "CAP_13"],
            magicText: "",
            trustText: "Credit where it came from.",
            ctaText: "One tap. Real recipe."
        },
        {
            name: "V03_COOKBOOK_PAGE",
            duration: 15,
            hookText: "Cookbook page? Don\u2019t retype it.",
            captures: ["CAP_17", "CAP_18", "CAP_07B"],
            magicText: "",
            ctaText: "Your personal recipe box."
        },
        {
            name: "V04_CREDIT_WHERE_IT_CAME_FROM",
            duration: 15,
            hookText: "I want the recipe\u2026 and the source.",
            captures: ["CAP_03", "CAP_12", "CAP_13"],
            magicText: "",
            ctaText: "Ingredients \u2022 Steps \u2022 Credit."
        },
        {
            name: "V05_PRIVATE_BY_DEFAULT",
            duration: 15,
            hookText: "My recipes aren\u2019t public. Period.",
            captures: ["CAP_07B", "CAP_04", "CAP_05"],
            trustText: "Private by default.",
            ctaText: "You control what\u2019s shared."
        },
        {
            name: "V06_SHARE_THAT_STICKS",
            duration: 15,
            hookText: "Stop texting screenshots.",
            captures: ["CAP_04", "CAP_04B", "CAP_07B"],
            magicText: "They keep it forever.",
            ctaText: "Share recipes that stick."
        },
        {
            name: "V07_GENERATOR",
            duration: 15,
            hookText: "I had chicken, lemons, and zero plan.",
            captures: ["CAP_20", "CAP_10"],
            magicText: "Tell us what you have.",
            trustText: "Share privately.",
            ctaText: "Preserve your family\u2019s recipes."
        },
        {
            name: "V08_RANGE_MONTAGE",
            duration: 15,
            hookText: "Recipes are everywhere. Now your box is too.",
            captures: ["CAP_12", "CAP_18", "CAP_07B"],
            magicText: "",
            ctaText: "Preserve your family\u2019s recipes."
        },
        {
            name: "V09_GRANDMAS_RECIPE",
            duration: 30,
            hookText: "My grandmother\u2019s handwriting is fading\u2026",
            captures: ["CAP_22", "CAP_18", "CAP_07B"],
            magicText: "Speak it. Heirloom writes it.",
            trustText: "Saved with credit.",
            ctaText: "Preserve your family\u2019s recipes forever."
        },
        {
            name: "V10_FREE_CREDITS",
            duration: 15,
            hookText: "50 free credits to start saving recipes.",
            captures: ["CAP_03", "CAP_02", "CAP_21"],
            magicText: "50 credits to start.\n100/month with Heritage.",
            ctaText: "Start free. Go premium when ready."
        },
        {
            name: "V11_RESPECT_CREATORS",
            duration: 15,
            hookText: "Save recipes. Respect creators.",
            captures: ["CAP_08", "CAP_12", "CAP_13"],
            magicText: "",
            ctaText: "Ingredients \u2022 Steps \u2022 Credit."
        },
        {
            name: "V12_PUBLIC_ONLY_WHEN_YOURS",
            duration: 15,
            hookText: "Public sharing shouldn\u2019t be risky.",
            captures: ["CAP_09", "CAP_05"],
            trustText: "Private by default.",
            ctaText: "You control what\u2019s shared."
        }
    ];

    // App Store Screenshot compositions
    var SCREENSHOT_CONFIGS = [
        { name: "SS_01_COLLECTIONS_HOME",  headline: "Your recipes, finally organized",  subhead: "All your favorites in one place",    capture: "CAP_07B", bgColor: [0.96, 0.90, 0.85] },
        { name: "SS_02_ONE_TAP_SAVE",      headline: "Save from any app\u2014one tap",   subhead: "From links, videos, or cookbooks",   capture: "CAP_03",  bgColor: [0.88, 0.94, 0.88] },
        { name: "SS_03_VIDEO_IMPORT",       headline: "Turn any video into a recipe",     subhead: "TikTok, Instagram, YouTube\u2014instant", capture: "CAP_12",  bgColor: [0.96, 0.82, 0.78] },
        { name: "SS_04_SCAN_COOKBOOK",       headline: "Scan cookbook pages instantly",     subhead: "Point, shoot, done",                 capture: "CAP_17",  bgColor: [0.90, 0.82, 0.72] },
        { name: "SS_05_READ_RECIPE",        headline: "Speak Your Recipe",                subhead: "Dictate\u2014Heirloom writes it down", capture: "CAP_22",  bgColor: [0.82, 0.88, 0.96] },
        { name: "SS_06_AI_GENERATE",        headline: "Tell us what you have",            subhead: "Get a recipe from your ingredients", capture: "CAP_20",  bgColor: [0.90, 0.84, 0.96] },
        { name: "SS_07_SHARE_FRIENDS",      headline: "Share recipes that stick",         subhead: "Friends keep them forever",          capture: "CAP_04",  bgColor: [0.96, 0.90, 0.80] },
        { name: "SS_08_PRIVATE_DEFAULT",    headline: "Private by default",               subhead: "You control what\u2019s shared",      capture: "CAP_05",  bgColor: [0.82, 0.92, 0.85] },
        { name: "SS_09_ATTRIBUTION",        headline: "Credit where it came from",        subhead: "Track every recipe\u2019s source",    capture: "CAP_13",  bgColor: [0.96, 0.92, 0.78] },
        { name: "SS_10_PREMIUM",            headline: "Start Free, Go Heritage",          subhead: "50 trial credits included",          capture: "CAP_02",  bgColor: [0.96, 0.94, 0.85] }
    ];

    // Website hero video compositions
    var HERO_CONFIGS = [
        { name: "HERO_LP1_SAVE",      duration: 15, captures: ["CAP_03", "CAP_03B", "CAP_11"], route: "/" },
        { name: "HERO_LP2_SHARE",     duration: 12, captures: ["CAP_04", "CAP_04B"],           route: "/lp/share" },
        { name: "HERO_LP_VIDEO",      duration: 15, captures: ["CAP_12", "CAP_13"],            route: "/lp/video" },
        { name: "HERO_LP_SCAN",       duration: 12, captures: ["CAP_17", "CAP_18"],            route: "/lp/scan" },
        { name: "HERO_LP_GENERATE",   duration: 12, captures: ["CAP_20", "CAP_10"],            route: "/lp/generate" }
    ];

    // ============================================================
    // GLOBAL REFERENCES
    // ============================================================

    var folders = {};

    // ============================================================
    // UTILITY FUNCTIONS
    // ============================================================

    function createFolder(name, parent) {
        var folder = app.project.items.addFolder(name);
        if (parent) {
            folder.parentFolder = parent;
        }
        return folder;
    }

    /**
     * Resolve a font from a preference list (PostScript names).
     * Returns the first available font or the last in the list as fallback.
     */
    function resolveFont(candidates) {
        for (var i = 0; i < candidates.length; i++) {
            try {
                // Test by creating a temp text document — if font doesn't exist
                // AE will throw or silently fall back. We try/catch to be safe.
                var test = new TextDocument("");
                test.font = candidates[i];
                return candidates[i];
            } catch (e) {
                // Continue
            }
        }
        return candidates[candidates.length - 1];
    }

    /**
     * Add a colored-solid placeholder for a capture ID.
     * Returns the layer so callers can adjust timing/position.
     */
    function addPlaceholder(comp, captureId, startTime, duration, width, height) {
        var capConfig = CAPTURES[captureId];
        if (!capConfig) {
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
        solid.comment = "[" + capConfig.category + "] Replace with " + captureId + " footage";
        return solid;
    }

    /**
     * Section G — Standard text entrance animation.
     * Fade 0%>100% over 8 frames, +8px Y>0 over 8 frames, Ease Out 33%.
     */
    function applyTextEntrance(layer) {
        var animDur = CONFIG.textAnim.fadeFrames / CONFIG.appStore.fps;
        var inPt = layer.inPoint;

        // Opacity: 0 > 100
        var opacity = layer.property("Transform").property("Opacity");
        opacity.setValueAtTime(inPt, 0);
        opacity.setValueAtTime(inPt + animDur, 100);

        // Position: +8px Y > 0
        var position = layer.property("Transform").property("Position");
        var restPos = position.value;
        position.setValueAtTime(inPt, [restPos[0], restPos[1] + CONFIG.textAnim.slidePixels]);
        position.setValueAtTime(inPt + animDur, restPos);

        // Apply ease-out to the second keyframe (33% influence)
        try {
            var influence = CONFIG.textAnim.easeInfluence;
            var easeIn  = new KeyframeEase(0, influence);
            var easeOut = new KeyframeEase(0, 75);
            opacity.setTemporalEaseAtKey(2, [easeIn], [easeOut]);
            position.setTemporalEaseAtKey(2, [easeIn, easeIn], [easeOut, easeOut]);
        } catch (e) { /* easing not available */ }
    }

    /**
     * Add a text layer matching Section A.3 typography rules.
     *   - fontSize: defaults to 72 (headlines) or caller can override
     *   - color: defaults to charcoal #2C2C2C
     *   - yPosition: absolute Y, or percentage of comp height if < 1
     */
    function addTextLayer(comp, text, startTime, duration, yPosition, fontSize, fontColor) {
        var textLayer = comp.layers.addText(text);
        textLayer.startTime = startTime;
        textLayer.outPoint = startTime + duration;

        var textProp = textLayer.property("Source Text");
        var textDoc = textProp.value;
        textDoc.resetCharStyle();
        textDoc.fontSize = fontSize || 72;
        textDoc.fillColor = fontColor || CONFIG.colors.charcoal;
        textDoc.font = resolveFont(["SFProDisplay-Semibold", "SFProDisplay-Regular", "HelveticaNeue-Medium", "HelveticaNeue", "Helvetica", "Arial"]);
        textDoc.justification = ParagraphJustification.CENTER_JUSTIFY;
        textProp.setValue(textDoc);

        // Position
        var yVal = (yPosition < 1) ? (comp.height * yPosition) : yPosition;
        var position = textLayer.property("Transform").property("Position");
        position.setValue([comp.width / 2, yVal]);

        // Section G text entrance animation
        applyTextEntrance(textLayer);

        return textLayer;
    }

    /**
     * Apply a cross-dissolve to a layer (opacity fade-in over dissolveFrames).
     * Section G: 6-10 frames, we use 8.
     */
    function applyCrossDissolve(layer) {
        var dur = CONFIG.transitions.dissolveSeconds;
        var opacity = layer.property("Transform").property("Opacity");
        opacity.setValueAtTime(layer.inPoint, 0);
        opacity.setValueAtTime(layer.inPoint + dur, 100);
        try {
            var ease = new KeyframeEase(0, 50);
            opacity.setTemporalEaseAtKey(1, [ease], [ease]);
            opacity.setTemporalEaseAtKey(2, [ease], [ease]);
        } catch (e) { /* ok */ }
    }

    /**
     * Apply a dissolve-out to a layer (opacity fade-out at the end).
     */
    function applyCrossDissolveOut(layer) {
        var dur = CONFIG.transitions.dissolveSeconds;
        var opacity = layer.property("Transform").property("Opacity");
        opacity.setValueAtTime(layer.outPoint - dur, 100);
        opacity.setValueAtTime(layer.outPoint, 0);
        try {
            var ease = new KeyframeEase(0, 50);
            opacity.setTemporalEaseAtKey(1, [ease], [ease]);
            opacity.setTemporalEaseAtKey(2, [ease], [ease]);
        } catch (e) { /* ok */ }
    }

    /**
     * Apply fade-in + slight zoom (for the Hook segment).
     * Section C: "Fade in, slight zoom"
     */
    function applyFadeZoom(layer) {
        var fadeDur = 0.8;  // 0.8s fade-in

        // Opacity fade
        var opacity = layer.property("Transform").property("Opacity");
        opacity.setValueAtTime(layer.inPoint, 0);
        opacity.setValueAtTime(layer.inPoint + fadeDur, 100);

        // Subtle zoom: 102% > 100% over full segment duration
        var scale = layer.property("Transform").property("Scale");
        scale.setValueAtTime(layer.inPoint, [102, 102]);
        scale.setValueAtTime(layer.outPoint, [100, 100]);

        try {
            var easeIn  = new KeyframeEase(0, 33);
            var easeOut = new KeyframeEase(0, 75);
            opacity.setTemporalEaseAtKey(2, [easeIn], [easeOut]);
            scale.setTemporalEaseAtKey(1, [easeIn, easeIn], [easeOut, easeOut]);
            scale.setTemporalEaseAtKey(2, [easeIn, easeIn], [easeOut, easeOut]);
        } catch (e) { /* ok */ }
    }

    /**
     * Add a composition marker (on the comp's marker property).
     */
    function addCompMarker(comp, time, comment) {
        var marker = new MarkerValue(comment);
        comp.markerProperty.setValueAtTime(time, marker);
    }

    /**
     * Add safe-zone guide overlays — Section G safe margins.
     * Creates a locked guide layer showing the no-text zones.
     */
    function addSafeZoneGuides(comp) {
        var sz = CONFIG.safeZones;
        var guideLayer = comp.layers.addShape();
        guideLayer.name = "SAFE_ZONE_GUIDES";
        guideLayer.guideLayer = true;

        var contents = guideLayer.property("Contents");

        // Draw the safe-area rectangle (the area INSIDE the margins)
        var group = contents.addProperty("ADBE Vector Group");
        group.name = "Safe Area";

        var rect = group.property("Contents").addProperty("ADBE Vector Shape - Rect");
        var safeW = comp.width - (sz.sides * 2);
        var safeH = comp.height - sz.top - sz.bottom;
        rect.property("ADBE Vector Rect Size").setValue([safeW, safeH]);
        // Center the rectangle accounting for asymmetric top/bottom margins
        var offsetY = (sz.top - sz.bottom) / 2;
        rect.property("ADBE Vector Rect Position").setValue([0, offsetY]);

        var stroke = group.property("Contents").addProperty("ADBE Vector Graphic - Stroke");
        stroke.property("Color").setValue(CONFIG.colors.guideColor);
        stroke.property("Stroke Width").setValue(2);
        stroke.property("Opacity").setValue(50);

        guideLayer.moveToBeginning();
        guideLayer.locked = true;
        return guideLayer;
    }

    // ============================================================
    // PHASE 1: PROJECT STRUCTURE
    // ============================================================

    function createProjectStructure() {
        app.beginUndoGroup("Create Project Structure");

        folders.captures      = createFolder("Captures");
        folders.compositions  = createFolder("Compositions");
        folders.assets        = createFolder("Assets");
        folders.exports       = createFolder("Exports");

        folders.appStore     = createFolder("App Store Preview", folders.compositions);
        folders.screenshots  = createFolder("Screenshots", folders.compositions);
        folders.heroes       = createFolder("Website Heroes", folders.compositions);
        folders.ads          = createFolder("Ads", folders.compositions);

        folders.logo         = createFolder("Logo", folders.assets);
        folders.endCard      = createFolder("End Card", folders.assets);
        folders.badge        = createFolder("App Store Badge", folders.assets);

        app.endUndoGroup();
    }

    // ============================================================
    // PHASE 2: CAPTURE PLACEHOLDERS
    // ============================================================

    function createCapturePlaceholders() {
        app.beginUndoGroup("Create Capture Placeholders");

        var helperComp = app.project.items.addComp(
            "_Placeholder_Source",
            CONFIG.appStore.width,
            CONFIG.appStore.height,
            1,
            30,
            CONFIG.appStore.fps
        );
        helperComp.parentFolder = folders.captures;

        for (var capId in CAPTURES) {
            if (CAPTURES.hasOwnProperty(capId)) {
                var cap = CAPTURES[capId];
                var solid = helperComp.layers.addSolid(
                    cap.color, capId,
                    CONFIG.appStore.width, CONFIG.appStore.height,
                    1, cap.duration
                );
                solid.comment = cap.category;
            }
        }

        app.endUndoGroup();
    }

    // ============================================================
    // PHASE 3: APP STORE PREVIEW — Section C (frame-by-frame)
    // ============================================================

    function createAppStorePreview() {
        app.beginUndoGroup("Create App Store Preview");

        var w   = CONFIG.appStore.width;
        var h   = CONFIG.appStore.height;
        var fps = CONFIG.appStore.fps;
        var dur = CONFIG.appStore.duration;

        var comp = app.project.items.addComp("HEIRLOOM_APPSTORE_PREVIEW", w, h, 1, dur, fps);
        comp.parentFolder = folders.appStore;

        // Warm cream background — Section A.1
        comp.layers.addSolid(CONFIG.colors.cream, "Background", w, h, 1, dur);

        // --------------------------------------------------------
        // Build each storyboard segment (Section C table)
        // Layers are added top-down; last added = topmost in timeline
        // We build bottom-up so the earliest segments end up on top.
        // --------------------------------------------------------

        for (var s = APP_STORE_STORYBOARD.length - 1; s >= 0; s--) {
            var seg = APP_STORE_STORYBOARD[s];
            var segDur = seg.endTime - seg.startTime;

            // --- CTA end card (special case, no captures) ---
            if (seg.segment === "CTA") {
                buildEndCard(comp, seg.startTime, segDur, w, h);

                // Dissolve-in on the end card background
                var endBg = comp.layer("ENDCARD_BG");
                if (endBg) applyCrossDissolve(endBg);

                addCompMarker(comp, seg.startTime, "CTA: " + seg.text);
                continue;
            }

            // --- Capture layers ---
            var captures = seg.captures;
            if (captures.length === 1) {
                // Single capture fills the segment
                var layer = addPlaceholder(comp, captures[0], seg.startTime, segDur, w, h);
                applyTransition(layer, seg.transition);
            } else {
                // Multiple captures split the segment evenly
                var splitDur = segDur / captures.length;
                for (var c = captures.length - 1; c >= 0; c--) {
                    var capStart = seg.startTime + (c * splitDur);
                    var capLayer = addPlaceholder(comp, captures[c], capStart, splitDur, w, h);
                    // First capture in the segment gets the segment transition;
                    // subsequent captures within the same segment use cut.
                    if (c === 0) {
                        applyTransition(capLayer, seg.transition);
                    }
                    // For "cut" transitions within a multi-capture segment,
                    // no additional opacity work needed (hard cut).
                }
            }

            // --- On-screen text overlay ---
            // Section A.3: max 7 words/line, 1 claim per shot, paired to UI action
            var textY = 0.08;  // 8% from top, inside safe zone
            addTextLayer(comp, seg.text, seg.startTime, segDur, textY);

            // Comp marker for segment
            addCompMarker(comp, seg.startTime, seg.segment + ": " + seg.text);
        }

        // Safe zone guides on top
        addSafeZoneGuides(comp);

        app.endUndoGroup();
        return comp;
    }

    /**
     * Apply the correct transition to a layer based on Section C's per-segment spec.
     */
    function applyTransition(layer, transitionType) {
        switch (transitionType) {
            case "fade_zoom":
                applyFadeZoom(layer);
                break;
            case "dissolve":
                applyCrossDissolve(layer);
                break;
            case "cut":
                // Hard cut — no opacity animation needed
                break;
            default:
                break;
        }
    }

    /**
     * Build the end card per Section G spec:
     *   Logo: center, 40% from top, 180px wide
     *   App Store badge: center, 70% from top, 200px wide
     *   CTA text: center, 85% from top, 48pt
     *   Background: warm cream gradient
     */
    function buildEndCard(comp, startTime, duration, w, h) {
        var ec = CONFIG.endCard;

        // Background
        var bg = comp.layers.addSolid(CONFIG.colors.cream, "ENDCARD_BG", w, h, 1, duration);
        bg.startTime = startTime;
        bg.outPoint = startTime + duration;

        // Logo placeholder (terracotta solid)
        var logoH = Math.round(ec.logoWidth * 1);  // Square logo placeholder
        var logo = comp.layers.addSolid(
            CONFIG.colors.terracotta, "ENDCARD_LOGO",
            ec.logoWidth, logoH, 1, duration
        );
        logo.startTime = startTime;
        logo.outPoint = startTime + duration;
        logo.property("Transform").property("Position").setValue([w / 2, h * ec.logoYPercent]);
        logo.comment = "Replace with Heirloom logo PNG";

        // App Store badge placeholder
        var badgeH = Math.round(ec.badgeWidth * 0.335);  // Standard badge aspect ~3:1
        var badge = comp.layers.addSolid(
            CONFIG.colors.nearBlack, "ENDCARD_APP_STORE_BADGE",
            ec.badgeWidth, badgeH, 1, duration
        );
        badge.startTime = startTime;
        badge.outPoint = startTime + duration;
        badge.property("Transform").property("Position").setValue([w / 2, h * ec.badgeYPercent]);
        badge.comment = "Replace with official Apple App Store badge";

        // CTA text — "Download Heirloom" at 48pt per Section G
        addTextLayer(comp, "Download Heirloom", startTime, duration, ec.ctaYPercent, ec.ctaFontSize);

        // Fade-in the logo and badge
        applyTextEntrance(logo);
        applyTextEntrance(badge);
    }

    // ============================================================
    // PHASE 4: AD COMPOSITIONS — Section D
    // ============================================================

    function createAdComp(config) {
        var isExtended = (config.duration === 30);
        var w   = CONFIG.ads.width;
        var h   = CONFIG.ads.height;
        var fps = CONFIG.ads.fps;
        var dur = config.duration;

        var comp = app.project.items.addComp(config.name, w, h, 1, dur, fps);
        comp.parentFolder = folders.ads;

        // Background
        comp.layers.addSolid(CONFIG.colors.cream, "Background", w, h, 1, dur);

        // --- Timing — Section A.2 motion language ---
        var hookEnd     = 2.5;
        var behaviorEnd = isExtended ? 8 : 6;
        var magicEnd    = isExtended ? 14 : 10;
        var trustEnd    = isExtended ? 22 : 12;
        var ctaStart    = isExtended ? 27 : (dur - 3);
        // For 15s ads: hook 0-2.5 | behavior 2.5-6 | magic 6-10 | trust 10-12 | CTA 12-15
        // For 30s ads: hook 0-2.5 | behavior 2.5-8 | magic 8-14 | trust 14-22 | extra 22-27 | CTA 27-30

        // Hook text on warm background
        var hookBg = comp.layers.addSolid(CONFIG.colors.cream, "HOOK_BG", w, h, 1, hookEnd);
        hookBg.startTime = 0;
        hookBg.outPoint = hookEnd;

        addTextLayer(comp, config.hookText, 0, hookEnd, 0.45, 64);
        addCompMarker(comp, 0, "Hook: " + config.hookText);

        // Capture layers fill behavior + magic segments
        var captures = config.captures;
        var captureZoneStart = hookEnd;
        var captureZoneEnd = trustEnd;
        var captureZoneDur = captureZoneEnd - captureZoneStart;
        var perCapDur = captureZoneDur / captures.length;

        for (var i = captures.length - 1; i >= 0; i--) {
            var capStart = captureZoneStart + (i * perCapDur);
            var capLayer = addPlaceholder(comp, captures[i], capStart, perCapDur, w, h);
            // First capture dissolves in from hook; rest are cuts
            if (i === 0) {
                applyCrossDissolve(capLayer);
            }
            addCompMarker(comp, capStart, captures[i]);
        }

        // Trust text overlay (if specified)
        if (config.trustText) {
            addTextLayer(comp, config.trustText, magicEnd, trustEnd - magicEnd, 0.10, 56);
        }

        // Magic text overlay (if specified)
        if (config.magicText) {
            addTextLayer(comp, config.magicText, behaviorEnd, magicEnd - behaviorEnd, 0.10, 56);
        }

        // CTA end card
        var ctaDur = dur - ctaStart;
        buildEndCard(comp, ctaStart, ctaDur, w, h);

        // Override CTA text with ad-specific text
        // Find and update the CTA text layer that buildEndCard created
        for (var t = 1; t <= comp.numLayers; t++) {
            var lyr = comp.layer(t);
            if (lyr instanceof TextLayer && lyr.startTime >= ctaStart) {
                var srcText = lyr.property("Source Text");
                var td = srcText.value;
                td.text = config.ctaText;
                td.fontSize = CONFIG.endCard.ctaFontSize;
                srcText.setValue(td);
                break;
            }
        }

        addCompMarker(comp, ctaStart, "CTA: " + config.ctaText);
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
    // PHASE 5: APP STORE SCREENSHOTS
    // ============================================================

    function createScreenshotComp(config) {
        var w   = CONFIG.appStore.width;
        var h   = CONFIG.appStore.height;
        var fps = CONFIG.appStore.fps;
        var frameDur = 1 / fps;

        var comp = app.project.items.addComp(config.name, w, h, 1, frameDur, fps);
        comp.parentFolder = folders.screenshots;

        // Background
        comp.layers.addSolid(config.bgColor, "Background", w, h, 1, frameDur);

        // Device mockup area (bottom 75%)
        var captureH = Math.round(h * 0.75);
        var captureW = Math.round(captureH * (1290 / 2796));

        var capConfig = CAPTURES[config.capture];
        var capColor = capConfig ? capConfig.color : [0.5, 0.5, 0.5];
        var capLayer = comp.layers.addSolid(capColor, config.capture + "_PLACEHOLDER", captureW, captureH, 1, frameDur);
        capLayer.property("Transform").property("Position").setValue([w / 2, h - (captureH / 2)]);
        capLayer.comment = "Replace with " + config.capture + " inside device frame";

        // Headline — Section A.3 rules, bold
        var headlineLayer = comp.layers.addText(config.headline);
        headlineLayer.startTime = 0;
        headlineLayer.outPoint = frameDur;
        var hlProp = headlineLayer.property("Source Text");
        var hlDoc = hlProp.value;
        hlDoc.resetCharStyle();
        hlDoc.fontSize = 72;
        hlDoc.fillColor = CONFIG.colors.charcoal;
        hlDoc.font = resolveFont(["SFProDisplay-Bold", "HelveticaNeue-Bold", "Helvetica-Bold", "Arial-BoldMT"]);
        hlDoc.justification = ParagraphJustification.CENTER_JUSTIFY;
        hlProp.setValue(hlDoc);
        headlineLayer.property("Transform").property("Position").setValue([w / 2, h * 0.08]);

        // Subhead
        var subheadLayer = comp.layers.addText(config.subhead);
        subheadLayer.startTime = 0;
        subheadLayer.outPoint = frameDur;
        var shProp = subheadLayer.property("Source Text");
        var shDoc = shProp.value;
        shDoc.resetCharStyle();
        shDoc.fontSize = 42;
        shDoc.fillColor = [0.4, 0.4, 0.4];
        shDoc.font = resolveFont(["SFProDisplay-Regular", "HelveticaNeue", "Helvetica", "Arial"]);
        shDoc.justification = ParagraphJustification.CENTER_JUSTIFY;
        shProp.setValue(shDoc);
        subheadLayer.property("Transform").property("Position").setValue([w / 2, h * 0.12]);

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
    // PHASE 6: WEBSITE HERO VIDEOS
    // ============================================================

    function createHeroComp(config) {
        var w   = 1920;
        var h   = 1080;
        var fps = CONFIG.appStore.fps;
        var dur = config.duration;

        var comp = app.project.items.addComp(config.name, w, h, 1, dur, fps);
        comp.parentFolder = folders.heroes;
        comp.comment = "Website hero for " + config.route;

        comp.layers.addSolid(CONFIG.colors.cream, "Background", w, h, 1, dur);

        // Phone frame area — centered 9:19.5 device within 16:9
        var deviceH = Math.round(h * 0.85);
        var deviceW = Math.round(deviceH * (1290 / 2796));

        var captures = config.captures;
        var segDur = dur / captures.length;

        for (var i = captures.length - 1; i >= 0; i--) {
            var capId = captures[i];
            var capStart = i * segDur;
            var capConfig = CAPTURES[capId];
            var capColor = capConfig ? capConfig.color : [0.5, 0.5, 0.5];

            var capLayer = comp.layers.addSolid(capColor, capId, deviceW, deviceH, 1, segDur);
            capLayer.startTime = capStart;
            capLayer.outPoint = capStart + segDur;
            capLayer.property("Transform").property("Position").setValue([w / 2, h / 2]);
            capLayer.comment = capId + " \u2014 replace with recording inside device frame";

            if (i > 0) applyCrossDissolve(capLayer);
            addCompMarker(comp, capStart, capId);
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
    // PHASE 7: RENDER QUEUE — Section G export settings
    // ============================================================

    function setupRenderQueue() {
        app.beginUndoGroup("Setup Render Queue");

        var rq = app.project.renderQueue;
        var compsToRender = [];

        for (var i = 1; i <= app.project.numItems; i++) {
            var item = app.project.item(i);
            if (!(item instanceof CompItem)) continue;
            // Skip internal helper comps
            if (item.name.indexOf("_Placeholder") === 0) continue;
            // Include App Store, Ads, Screenshots, Heroes
            if (item.name.indexOf("HEIRLOOM_") === 0 ||
                item.name.indexOf("V0") === 0 || item.name.indexOf("V1") === 0 ||
                item.name.indexOf("SS_") === 0 ||
                item.name.indexOf("HERO_") === 0) {
                compsToRender.push(item);
            }
        }

        for (var j = 0; j < compsToRender.length; j++) {
            var comp = compsToRender[j];
            var rqItem = rq.items.add(comp);

            try {
                var om = rqItem.outputModule(1);
                // Section G: H.264, 15-20 Mbps
                try { om.applyTemplate("H.264 - Match Render Settings - 15 Mbps"); }
                catch (e1) {
                    try { om.applyTemplate("H.264"); } catch (e2) { /* default */ }
                }

                var projectPath = app.project.file ? app.project.file.parent.fsName : "~/Desktop";
                om.file = new File(projectPath + "/Exports/" + comp.name + ".mp4");
            } catch (e) { /* output module settings vary by AE version */ }
        }

        app.endUndoGroup();
    }

    // ============================================================
    // MAIN
    // ============================================================

    function main() {
        var ok = Window.confirm(
            "Heirloom Video Setup Script\n\n" +
            "This will create:\n" +
            "\u2022 Project folder structure\n" +
            "\u2022 19 capture placeholders (CAP_02\u2013CAP_22)\n" +
            "\u2022 1 App Store Preview (30s @ 1290\u00d72796)\n" +
            "    \u2014 Section C storyboard, frame-by-frame\n" +
            "    \u2014 Fade+zoom hook, dissolves, cuts per spec\n" +
            "    \u2014 End card per Section G spec\n" +
            "\u2022 10 App Store Screenshot compositions\n" +
            "\u2022 5 Website Hero compositions (1920\u00d71080)\n" +
            "\u2022 12 Ad compositions (15\u201330s @ 1080\u00d71920)\n" +
            "\u2022 Render queue with H.264 presets\n\n" +
            "Total: 28 compositions\n\n" +
            "Continue?",
            true,
            "Heirloom Setup"
        );

        if (!ok) return;

        var startTime = new Date().getTime();

        try {
            $.writeln("Phase 1: Project structure...");
            createProjectStructure();

            $.writeln("Phase 2: Capture placeholders...");
            createCapturePlaceholders();

            $.writeln("Phase 3: App Store Preview (Section C)...");
            createAppStorePreview();

            $.writeln("Phase 4: Ad compositions (Section D)...");
            createAllAdComps();

            $.writeln("Phase 5: Screenshot compositions...");
            createAllScreenshotComps();

            $.writeln("Phase 6: Website Hero compositions...");
            createAllHeroComps();

            $.writeln("Phase 7: Render queue...");
            setupRenderQueue();

            var elapsed = ((new Date().getTime() - startTime) / 1000).toFixed(1);

            alert(
                "Heirloom Video Setup Complete!\n\n" +
                "Created in " + elapsed + "s:\n" +
                "\u2022 19 capture placeholders\n" +
                "\u2022 1 App Store Preview (30s)\n" +
                "    \u2014 7 segments matching Section C storyboard\n" +
                "    \u2014 Per-segment transitions (fade+zoom, dissolve, cut)\n" +
                "    \u2014 Approved on-screen text from phrase bank\n" +
                "    \u2014 End card: logo 40%, badge 70%, CTA 85% @ 48pt\n" +
                "\u2022 12 Ad compositions with approved hook text\n" +
                "\u2022 10 Screenshot compositions\n" +
                "\u2022 5 Website Hero compositions\n" +
                "\u2022 Render queue ready\n\n" +
                "Next steps:\n" +
                "1. Import captures to /Captures/\n" +
                "2. Alt+drag onto matching placeholder layers\n" +
                "3. Import logo + App Store badge to /Assets/\n" +
                "4. Adjust timing, render from queue",
                "Setup Complete"
            );
        } catch (e) {
            alert("Error:\n" + e.toString() + "\nLine: " + e.line, "Error");
        }
    }

    main();

})();
