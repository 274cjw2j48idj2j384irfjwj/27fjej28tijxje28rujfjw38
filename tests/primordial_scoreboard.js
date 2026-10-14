// Panorama API contract checks; no browser/game process required.
// Run: node tests/primordial_scoreboard.js
const fs = require("fs");
const assert = require("assert");
const vm = require("vm");
const source = fs.readFileSync(process.argv[2] || "specter_primordial.lua", "utf8");
const match = source.match(/libs\.tools\.js = libs\.panorama\.loadstring\(\[\[([\s\S]*?)\]\], "CSGOHud"\)\(\)/);
assert(match, "Panorama block found");
class Panel {
    constructor(id, parent = null) {
        this.id = id; this.parent = parent; this.children = [];
        this.style = {}; this.attrs = {}; this.valid = true; this.visible = true;
        if (parent) parent.children.push(this);
    }
    IsValid() { return this.valid; }
    Children() { return this.children.filter(p => p.valid); }
    FindChild(id) { return this.Children().find(p => p.id === id) || null; }
    FindChildTraverse(id) {
        if (this.id === id) return this;
        for (const child of this.Children()) {
            const found = child.FindChildTraverse(id);
            if (found) return found;
        }
        return null;
    }
    FindChildrenWithClassTraverse(cls) {
        let result = this.cls === cls ? [this] : [];
        for (const child of this.Children()) result = result.concat(child.FindChildrenWithClassTraverse(cls));
        return result;
    }
    GetAttributeString(key, fallback) { return this.attrs[key] || fallback; }
    DeleteAsync() { this.valid = false; for (const child of this.children) child.DeleteAsync(); }
    SetImage(path) { this.image = path; this.writes = (this.writes || 0) + 1; }
}
let context = new Panel("hud");
const xuids = { 1: "76561197960278073", 2: "76561197960290419" };
let nextEvent = 0;
const events = new Map();
const api = vm.runInNewContext("(function() {" + match[1] + "})()", {
    $: {
        GetContextPanel: () => context,
        CreatePanel: (type, parent, id) => new Panel(id, parent),
        RegisterForUnhandledEvent: (event, callback) => {
            const handle = ++nextEvent;
            events.set(handle, { event, callback });
            return handle;
        },
        UnregisterForUnhandledEvent: (event, handle) => {
            assert.equal(events.get(handle).event, event);
            events.delete(handle);
        },
    },
    GameStateAPI: { GetPlayerXuidStringFromEntIndex: idx => xuids[idx] },
});
let count = 0;
function check(ok, name) { assert(ok, name); count++; console.log("PASS " + name); }
api.create();
api.create();
check(events.size === 3, "event registration is idempotent");
api.update(2, "moon", false, xuids[2]);
check(context.Children().length === 0, "missing scoreboard does not throw or fabricate a panel");
const container = new Panel("ScoreboardContainer", context);
let board = new Panel("Scoreboard", container);
function row(xuid, withRank = true) {
    const row = new Panel("row-" + xuid, board);
    row.cls = "sb-row"; row.attrs.xuid = xuid;
    if (withRank) {
        const rank = new Panel("rank", row);
        rank.attrs["data-stat"] = "rank";
        new Panel("original-rank-image", rank);
    }
    return row;
}
let other = row(xuids[2]);
api.apply();
let badge = other.FindChildTraverse("specter-presence-" + xuids[2]);
check(badge && badge.FindChild("specter-fallback").visible && !badge.FindChild("specter-image").visible,
    "queued update survives unopened scoreboard and shows fallback");
api.update(2, "moon", true, xuids[2]);
check(badge.FindChild("specter-image").visible && !badge.FindChild("specter-fallback").visible
    && badge.FindChild("specter-image").image === "moon", "icon-ready update applies immediately");
api.apply();
check(badge.FindChild("specter-image").writes === 1, "unchanged image is not reloaded on every event");
let mine = row(xuids[1], false);
api.update(1, "moon", true, xuids[1]);
check(mine.FindChild("specter-presence-" + xuids[1]), "rankless scoreboard rows receive a badge");
board.DeleteAsync();
board = new Panel("Scoreboard", container);
other = row(xuids[2]);
mine = row(xuids[1]);
for (const { callback } of events.values()) callback();
check(other.FindChildTraverse("specter-presence-" + xuids[2]), "rebuilt scoreboard rows recover queued badges");
badge = other.FindChildTraverse("specter-presence-" + xuids[2]);
xuids[2] = "76561197960365727";
api.apply();
check(!badge.IsValid(), "slot reuse deletes the previous user's badge");
other = row(xuids[2]);
api.apply();
check(!other.FindChildTraverse("specter-presence-" + xuids[2]), "slot replacement is not badged without new presence data");
api.update(2, "moon", true, xuids[2]);
badge = other.FindChildTraverse("specter-presence-" + xuids[2]);
delete xuids[2];
api.apply();
check(!badge.IsValid(), "disconnected identity removes its rendered badge");
api.clear();
check(mine.FindChildTraverse("original-rank-image").visible, "clearing badges leaves original scoreboard rank visible");
api.update(1, "moon", true, xuids[1]);
api.destroy();
check(events.size === 0 && !mine.FindChildTraverse("specter-presence-" + xuids[1]),
    "shutdown unregisters events and removes owned panels");
check(api.update(65, "moon", true, "x") === false, "invalid entity slots are rejected");
context = null;
api.create();
api.update(1, "moon", true, xuids[1]);
check(events.size === 3, "missing HUD context is null-safe");
console.log("ALL " + count + " SCOREBOARD CONTRACT CHECKS PASSED");
