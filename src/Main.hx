package mods.cooldown_text;

import mods.api.Context;
import mods.api.Mod;
import facade.DBFacade;
import openfl.events.Event;
import openfl.display.DisplayObject;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.filters.GlowFilter;
import brain.render.MovieClipRenderer;
import starling.display.DisplayObject as StarlingDisplayObject;

class Main extends Mod {
    var context:Context;
    var facade:DBFacade;
    var labels:Array<TextField> = [];
    var watchedHud:Dynamic;
    var failed:Bool = false;
    var loggedBackend:String = "";
    var effectsFailed:Bool = false;

    override public function init(context:Context):Void {
        this.context = context;
        context.overlay.mouseEnabled = false;
        context.overlay.mouseChildren = false;
        // Allocate the overlay fields directly, as in the working 0.1 build.
        // Reserve independent fields for up to 64 simultaneous effect icons.
        for (index in 0...69) {
            var label = new TextField();
            label.defaultTextFormat = new TextFormat("_sans", 24, 0xFFFFFF, true);
            label.width = 110;
            label.height = 38;
            label.selectable = false;
            label.mouseEnabled = false;
            label.multiline = false;
            label.wordWrap = false;
            label.filters = [new GlowFilter(0x000000, 1, 4, 4, 5)];
            label.visible = false;
            labels.push(label);
            context.overlay.addChild(label);
        }
        context.overlay.addEventListener(Event.ENTER_FRAME, update);
    }

    override public function ready(context:Context):Void {
        facade = context.core.facade;
        context.log("loaded; waiting for weapon and consumable cooldowns");
    }

    override public function dispose():Void {
        context.overlay.removeEventListener(Event.ENTER_FRAME, update);
        for (label in labels) {
            if (label.parent != null) label.parent.removeChild(label);
        }
        labels = [];
        watchedHud = null;
        facade = null;
    }

    function update(event:Event):Void {
        for (label in labels) label.visible = false;
        if (facade == null || !context.core.alive || context.state.floor == null) return;
        try {
            var hud:Dynamic = Reflect.field(facade, "mHud");
            if (hud != watchedHud) {
                watchedHud = hud;
                failed = false;
                effectsFailed = false;
            }
            if (hud == null || failed) return;
            var name = Type.getClassName(Type.getClass(hud));
            if (name == "uI.hud.starlingConverted.StarlingHud") {
                updateStarling(hud);
            } else if (name == "uI.hud.UIHud") {
                updateLegacy(hud);
            } else {
                throw "Unsupported HUD: " + name;
            }
            if (loggedBackend != name) {
                loggedBackend = name;
                context.log("following " + name);
            }
        } catch (error:Dynamic) {
            failed = true;
            for (label in labels) label.visible = false;
            context.log("cooldown labels stopped: " + Std.string(error));
        }
    }

    function updateStarling(hud:Dynamic):Void {
        var root:StarlingDisplayObject = cast Reflect.field(hud, "mRoot");
        if (!starlingVisible(root) || Reflect.field(hud, "mHeroOwner") == null) return;
        var starts:Dynamic = Reflect.field(hud, "mCooldownStarts");
        var durations:Dynamic = Reflect.field(hud, "mCooldownDurations");
        var weapons:Dynamic = Reflect.field(hud, "mWeapons");
        var consumables:Dynamic = Reflect.field(hud, "mConsumables");
        if (starts == null || durations == null || weapons == null || consumables == null) return;
        var now:Float = facade.gameClock.gameTime;
        for (index in 0...5) {
            var duration:Float = durations[index];
            if (!(duration > 0)) continue;
            var start:Float = starts[index];
            var remaining = duration - Math.max(0, (now - start) / 1000);
            if (!(remaining > 0)) continue;
            var list:Dynamic = index < 3 ? weapons : consumables;
            var slotIndex = index < 3 ? index : index - 3;
            if (slotIndex >= list.length) continue;
            var slot:Dynamic = list[slotIndex];
            if (slot == null) continue;
            var graphic:StarlingDisplayObject = cast Reflect.field(slot, "mGraphic");
            if (!starlingVisible(graphic)) continue;
            // The Starling root is synchronized to scalingRoot by the game.
            // Bounds in this root are the same authored HUD coordinates.
            var button:Dynamic = Reflect.field(slot, "mButton");
            var bounds = starlingButtonBounds(button, graphic, root);
            place(index, remaining, bounds);
        }
        if (!effectsFailed) {
            try {
                updateStarlingBuffs(hud, root);
            } catch (error:Dynamic) {
                effectsFailed = true;
                context.log("effect timers stopped; weapon timers remain active: " + Std.string(error));
            }
        }
    }

    function updateLegacy(hud:Dynamic):Void {
        var root:DisplayObject = cast Reflect.field(hud, "mRoot");
        if (!flashVisible(root) || Reflect.field(hud, "mHeroOwner") == null) return;
        updateLegacySlots(Reflect.field(hud, "mCooldowns"), Reflect.field(hud, "mWeaponButtons"), 3, 0);
        updateLegacySlots(Reflect.field(hud, "mConsumableCooldowns"), Reflect.field(hud, "mConsumableWeaponButtons"), 2, 3);
        if (!effectsFailed) {
            try {
                var buffs:Dynamic = Reflect.field(hud, "mBuffCooldowns");
                var buttons:Dynamic = Reflect.field(hud, "mBuffIconButtons");
                if (buffs != null && buttons != null) updateLegacySlots(buffs, buttons, buffs.length, 5);
            } catch (error:Dynamic) {
                effectsFailed = true;
                context.log("effect timers stopped; weapon timers remain active: " + Std.string(error));
            }
        }
    }

    function updateLegacySlots(renderers:Dynamic, buttons:Dynamic, count:Int, offset:Int):Void {
        if (renderers == null || buttons == null) return;
        for (index in 0...count) {
            if (index >= renderers.length || index >= buttons.length) continue;
            var renderer:MovieClipRenderer = cast renderers[index];
            var button:Dynamic = buttons[index];
            if (renderer == null || button == null || renderer.clip == null || !renderer.clip.visible || !renderer.isPlaying) continue;
            var buttonRoot:DisplayObject = cast Reflect.getProperty(button, "root");
            if (!flashVisible(buttonRoot)) continue;
            // Use only the button's authored square, excluding icon artwork,
            // key prompts, quantities, tooltips, and the cooldown wedge.
            var frame:DisplayObject = cast Reflect.field(button, "mUpState");
            if (frame == null) frame = cast Reflect.field(button, "mHitArea");
            if (frame == null) frame = buttonRoot;
            var rate = renderer.playRate;
            if (!(rate > 0) || !(renderer.frameRate > 0)) continue;
            var head:Float = Reflect.field(renderer, "mPlayHead");
            // UIHud encodes the requested seconds as playRate = 4.1 / seconds.
            var remaining = (4.1 - head / renderer.frameRate) / rate;
            if (remaining > 0) place(offset + index, remaining, frame.getBounds(facade.scalingRoot), offset >= 5);
        }
    }

    function updateStarlingBuffs(hud:Dynamic, root:StarlingDisplayObject):Void {
        var views:Dynamic = Reflect.field(hud, "mBuffViews");
        if (views == null) return;
        for (index in 0...views.length) {
            var view:Dynamic = views[index];
            if (view == null) continue;
            var cooldown:StarlingDisplayObject = cast Reflect.field(view, "mCooldown");
            if (!starlingVisible(cooldown)) continue;
            var playing:Bool = Reflect.getProperty(cooldown, "isPlaying");
            if (!playing) continue;
            var rate:Float = Reflect.getProperty(cooldown, "playRate");
            var head:Float = Reflect.field(cooldown, "mPlayHead");
            if (!(rate > 0)) continue;
            var remaining = (4.1 - head / 24) / rate;
            if (!(remaining > 0)) continue;
            var button:Dynamic = Reflect.field(view, "mButton");
            var bounds = starlingButtonBounds(button, cooldown, root);
            place(5 + index, remaining, bounds, true);
        }
    }

    function starlingButtonBounds(button:Dynamic, fallback:StarlingDisplayObject, root:StarlingDisplayObject):Rectangle {
        if (button != null) {
            var states:Dynamic = Reflect.field(button, "mStates");
            if (states != null && states.length > 0) {
                var frame:StarlingDisplayObject = cast states[0];
                if (frame != null) {
                    var bounds = frame.getBounds(root);
                    if (bounds.width > 0 && bounds.height > 0) return bounds;
                }
            }
            var hit:StarlingDisplayObject = cast Reflect.field(button, "mHit");
            if (hit != null) {
                var bounds = hit.getBounds(root);
                if (bounds.width > 0 && bounds.height > 0) return bounds;
            }
        }
        return fallback.getBounds(root);
    }

    function place(index:Int, remaining:Float, bounds:Rectangle, small:Bool = false):Void {
        if (index >= labels.length) return;
        if (bounds == null || bounds.width <= 0 || bounds.height <= 0) return;
        var center = new Point(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
        var edge = new Point(center.x + bounds.width, center.y);
        center = context.overlay.globalToLocal(facade.scalingRoot.localToGlobal(center));
        edge = context.overlay.globalToLocal(facade.scalingRoot.localToGlobal(edge));
        var scale = small ? Math.max(0.45, Math.min(0.8, Math.abs(edge.x - center.x) / 90))
            : Math.max(0.6, Math.min(1.5, Math.abs(edge.x - center.x) / 90));
        var label = labels[index];
        // Always show one decimal; avoid showing 0.0s before the cooldown ends.
        var tenths = Math.ceil(remaining * 10);
        var text = Std.string(Std.int(tenths / 10)) + "." + Std.string(tenths % 10) + "s";
        if (label.text != text) label.text = text;
        label.width = label.textWidth + 4;
        label.height = label.textHeight + 4;
        label.scaleX = label.scaleY = scale;
        label.x = center.x - (label.textWidth / 2 + 2) * scale;
        label.y = center.y - (label.textHeight / 2 + 2) * scale;
        label.visible = true;
    }

    function flashVisible(object:DisplayObject):Bool {
        if (object == null || object.stage == null) return false;
        var current:DisplayObject = object;
        while (current != null) {
            if (!current.visible || current.alpha <= 0) return false;
            current = current.parent;
        }
        return true;
    }

    function starlingVisible(object:StarlingDisplayObject):Bool {
        if (object == null || object.stage == null) return false;
        var current:StarlingDisplayObject = object;
        while (current != null) {
            if (!current.visible || current.alpha <= 0) return false;
            current = current.parent;
        }
        return true;
    }
}
