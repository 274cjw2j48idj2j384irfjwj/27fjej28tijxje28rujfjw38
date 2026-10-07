"""
Specter / Zenith — Discord License Bot
Slash commands for key management + automatic role system.
Auto-syncs keys to GitHub so the Lua loader picks them up.

ENV VARS (set in Discord bot host or .env):
  DISCORD_TOKEN       — Bot token from Discord Developer Portal
  API_URL             — License server URL (e.g. https://your-app.up.railway.app)
  ADMIN_SECRET        — Matches server.js ADMIN_SECRET
  ADMIN_ROLE_ID       — Discord role ID that can use admin commands (optional; else owner + Administrator). The Staff
                        role gets the support commands (key info / list / HWID reset, roles, tickets, release_check)
  DEFAULT_ROLE_NAME   — Role given to every new member (default: "Member")
  LOG_CHANNEL_ID      — Channel ID for key/role logs (optional)
  GITHUB_TOKEN        — GitHub PAT with repo write access (for key sync). Leave it EMPTY while the repo is public:
                        the sync writes every key into specter_keys.json in the repo (the loader does not need it)
  GITHUB_REPO         — GitHub repo (default: 274cjw2j48idj2j384irfjwj/27fjej28tijxje28rujfjw38)
  SCRIPT_BRANCH       — branch /script_upload takes specter_cloud.lua from (default: main)
  SCRIPT_TOKEN        — GitHub token that can READ the repo (fine-grained, Contents: Read-only). Needed when the repo
                        is private: /script_upload then downloads specter_cloud.lua through the GitHub API with it.
                        It is not used for anything else (the key sync uses GITHUB_TOKEN). With it the version check
                        below also gets its own GitHub API limit (without it: 60 calls / hour per IP, shared on Railway)
  RELEASE_CHANNEL     — staff channel (name or id) new script versions are posted in (default: staff). Only posted when
                        neither @everyone nor a member / customer / plan role can read it
  RELEASE_FILES       — files posted there when a new commit changes them (default: specter_dev.lua)
  RELEASE_MINUTES     — how often GitHub is checked (default: 5, 0 = only /release_check)
  AUTO_UPLOAD         — 1 (default): a new specter_cloud.lua of SCRIPT_BRANCH goes to the license server by itself (every
                        plan; the loader downloads it from there), 0: only /script_upload
"""

import os
import io
import re
import time
import json
import base64
import asyncio
import hashlib
import aiohttp
import discord
from datetime import datetime
from discord import app_commands

# ── Config ────────────────────────────────────────────────────────────

def _env(name: str, default: str = "") -> str:
    """A variable pasted as NAME=value or with quotes around it still works: both are cut off."""
    v = (os.environ.get(name) or "").strip()
    if v.startswith(name + "="):
        v = v[len(name) + 1:].strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        v = v[1:-1].strip()
    return v or default


DISCORD_TOKEN     = _env("DISCORD_TOKEN", "")
API_URL           = _env("API_URL", "http://localhost:3000").rstrip("/")
ADMIN_SECRET      = _env("ADMIN_SECRET", "change_this_secret_now")
ADMIN_ROLE_ID     = int(_env("ADMIN_ROLE_ID", "0"))
DEFAULT_ROLE_NAME = _env("DEFAULT_ROLE_NAME", "Member")
LOG_CHANNEL_ID    = int(_env("LOG_CHANNEL_ID", "0"))
GITHUB_TOKEN      = _env("GITHUB_TOKEN", "")
GITHUB_REPO       = _env("GITHUB_REPO", "274cjw2j48idj2j384irfjwj/27fjej28tijxje28rujfjw38")
SCRIPT_BRANCH     = _env("SCRIPT_BRANCH", "main")
SCRIPT_TOKEN      = _env("SCRIPT_TOKEN", "")

VALID_PLANS     = ["beta", "nightly", "specter", "debug"]
VALID_DURATIONS = ["lifetime", "1d", "7d", "14d", "30d", "90d"]

# what the Staff role may do on the server: moderation, not the server / roles / channels (those stay the owner's)
STAFF_PERMISSIONS = discord.Permissions(
    view_channel=True, send_messages=True, send_messages_in_threads=True, create_public_threads=True,
    create_private_threads=True, embed_links=True, attach_files=True, add_reactions=True, use_external_emojis=True,
    read_message_history=True, use_application_commands=True, change_nickname=True, connect=True, speak=True,
    manage_messages=True, manage_threads=True, moderate_members=True, kick_members=True, ban_members=True,
    manage_nicknames=True, mute_members=True, deafen_members=True, move_members=True, view_audit_log=True,
)
if hasattr(STAFF_PERMISSIONS, "pin_messages"):      # its own permission since 2025 (older discord.py: in manage_messages)
    STAFF_PERMISSIONS.pin_messages = True

ROLE_CONFIG = {
    "Member":   {"color": 0x808080, "hoist": False, "position": "bottom"},
    "Debug":    {"color": 0xFF5050, "hoist": True,  "position": "top"},
    "Specter":  {"color": 0x82C3FF, "hoist": True,  "position": "mid"},
    "Nightly":  {"color": 0xFF82A0, "hoist": True,  "position": "mid"},
    "Beta":     {"color": 0xC882FF, "hoist": True,  "position": "mid"},
    "Customer": {"color": 0x60FF90, "hoist": True,  "position": "mid"},
    "Staff":    {"color": 0xFFC850, "hoist": True,  "position": "top", "permissions": STAFF_PERMISSIONS},
}

PLAN_TO_ROLE = {
    "debug":    "Debug",
    "specter":  "Specter",
    "nightly":  "Nightly",
    "beta":     "Beta",
}

# ── Prices (edit these to match your pricing) ────────────────────────
SPECTER_PRICES = {
    "beta":    {"monthly": "$8",  "lifetime": "$20"},
    "nightly": {"monthly": "$15", "lifetime": "$40"},
    "specter": {"monthly": "$25", "lifetime": "$55"},
}


def price_lines() -> str:
    """The price list of the #prices embed (/post_prices and /setup_server)."""
    lines = []
    for plan_name in ["beta", "nightly", "specter"]:
        p = SPECTER_PRICES.get(plan_name, {})
        lines.append(f"*{plan_name} version*")
        if p.get("monthly"):
            lines.append(f"○ `1 month` — {p['monthly']}")
        if p.get("lifetime"):
            lines.append(f"○ `lifetime` — {p['lifetime']}")
        lines.append("")
    return "\n".join(lines)
PAYMENT_METHODS = ["Crypto", "PayPal", "Revolut", "Other"]

# the "Features" field of the #prices embed (/post_prices and /setup_server); a Discord field holds 1024 characters
FEATURES_TEXT = (
    "• **Resolver** — learns every enemy's desync, jitter and defensive AA, shows its angle in the hitlog *(specter)*\n"
    "• **Ragebot+** — backtrack optimization, extended backtrack, smart multipoint, resolver safety, "
    "dormant aimbot, DT guard *(nightly+)*\n"
    "• **Tuning** — air / noscope hit chance, weapon profiles, peek assist, quick peek options, force shot *(nightly+)*\n"
    "• **Anti-aim** — 7 presets, state builder *(nightly+)*, defensive AA *(nightly+)*, adaptive anti-bruteforce, "
    "manual / freestanding, roll, fake lag modes\n"
    "• **Visuals** — watermark, hitlog, keybinds & spectators, crosshair indicators, custom scope, damage marker, "
    "manual arrows, bullet tracers\n"
    "• **Misc** — animation breaker, clan tag, kill say, buy bot, aspect ratio, thirdperson\n"
    "• **Configs** — loadouts, cloud configs, import / export, auto-save"
)
LOGO_URL = _env("SPECTER_LOGO_URL", "")
BUY_CONTACT = _env("BUY_CONTACT", "@owner")

# ── Channel structure ────────────────────────────────────────────────
CHANNEL_STRUCTURE = [
    {
        "category": "⭐ Announcements",
        "channels": [
            {"name": "news",    "type": "text", "readonly": True, "emoji": "\U0001f4e2", "topic": "Latest Specter news"},
            {"name": "updates", "type": "text", "readonly": True, "emoji": "\U0001f4dc", "topic": "Version updates and changelogs"},
            {"name": "rules",   "type": "text", "readonly": True, "emoji": "\U0001f30d", "topic": "Server rules"},
        ],
    },
    {
        "category": "⭐ Purchase • Support",
        "channels": [
            {"name": "prices",         "type": "text", "readonly": True, "emoji": "\U0001f4b2", "topic": "Specter pricing and plans"},
            {"name": "support-ticket", "type": "text", "access": "member", "emoji": "\U0001f3ab", "topic": "Create a support ticket"},
            {"name": "how-to-use",     "type": "text", "readonly": True, "emoji": "\U0001f4d5", "topic": "How to set up and use Specter"},
            {"name": "media-deal",     "type": "text", "access": "member", "emoji": "✨", "topic": "Media deals and promotions"},
        ],
    },
    {
        "category": "◉ Communication",
        "channels": [
            {"name": "chat",  "type": "text", "access": "member", "emoji": "\U0001f4ac", "topic": "General chat"},
            {"name": "media", "type": "text", "access": "member", "emoji": "\U0001f4f8", "topic": "Screenshots, clips, media"},
        ],
    },
    {
        "category": "◉ Presentations",
        "channels": [
            {"name": "intro", "type": "text", "access": "member", "emoji": "\U0001f465", "topic": "Introduce yourself"},
        ],
    },
    {
        "category": "⭐ Specter Hub",
        "channels": [
            {"name": "loader-download", "type": "text", "access": "customer_readonly", "emoji": "\U0001f4e5", "topic": "Download the Specter loader here"},
            {"name": "config-share",    "type": "forum", "access": "customer", "emoji": "\U0001f4c1", "topic": "Upload and share your configs"},
            {"name": "script-help",     "type": "text",  "access": "customer", "emoji": "\U0001f527", "topic": "Script questions, issues, and troubleshooting"},
            {"name": "showcase",        "type": "text",  "access": "customer", "emoji": "\U0001f3ac", "topic": "Show off your clips, screenshots, and highlights"},
        ],
    },
    {
        "category": "⭐ Specter·Gs",
        "channels": [
            {"name": "reviews",     "type": "forum", "access": "customer", "emoji": "\U0001f49c", "topic": "Leave a review"},
            {"name": "suggestions", "type": "forum", "access": "customer", "emoji": "\U0001f4a1", "topic": "Feature suggestions"},
            {"name": "bug-reports", "type": "forum", "access": "customer", "emoji": "\U0001f534", "topic": "Report bugs"},
        ],
    },
    {
        "category": "⭐ Staff",
        "channels": [
            {"name": "staff", "type": "text", "access": "staff", "emoji": "\U0001f6e0️", "topic": "Staff discussion"},
            {"name": "logs",  "type": "text", "access": "staff", "emoji": "\U0001f4cb", "topic": "Bot and audit logs"},
        ],
    },
]

# ── Bot setup ─────────────────────────────────────────────────────────

intents = discord.Intents.default()
intents.members = True
client  = discord.Client(intents=intents)
tree    = app_commands.CommandTree(client)


def is_admin(interaction: discord.Interaction) -> bool:
    if interaction.user.id == interaction.guild.owner_id:
        return True
    if ADMIN_ROLE_ID:
        return any(r.id == ADMIN_ROLE_ID for r in interaction.user.roles)
    return interaction.user.guild_permissions.administrator


def guild_role(guild: discord.Guild, name: str) -> discord.Role | None:
    """A role by name, never a bot's own role: Discord names that after the bot, and the bot "Specter" has a role
    "Specter" (with Administrator when it was invited so), the same name as the specter plan role."""
    return discord.utils.find(lambda r: r.name == name and not r.managed, guild.roles)


def is_staff(interaction: discord.Interaction) -> bool:
    """The support commands (key info / list / HWID reset, roles except Staff, tickets, version check): admins + Staff."""
    return is_admin(interaction) or discord.utils.get(interaction.user.roles, name="Staff") is not None


async def api_post(path: str, data: dict) -> dict:
    async with aiohttp.ClientSession() as s:
        async with s.post(
            f"{API_URL}{path}",
            json=data,
            headers={"x-admin-secret": ADMIN_SECRET},
        ) as r:
            return {"status": r.status, **(await r.json())}


async def api_get(path: str) -> dict | list:
    async with aiohttp.ClientSession() as s:
        async with s.get(
            f"{API_URL}{path}",
            headers={"x-admin-secret": ADMIN_SECRET},
        ) as r:
            body = await r.json()
            if isinstance(body, list):
                return body
            return {"status": r.status, **body}


# ── GitHub key sync ───────────────────────────────────────────────────

KEYS_FILE = "specter_keys.json"
GH_API    = "https://api.github.com"

async def gh_read_keys() -> tuple[dict, str]:
    url = f"{GH_API}/repos/{GITHUB_REPO}/contents/{KEYS_FILE}"
    async with aiohttp.ClientSession() as s:
        async with s.get(url, headers={
            "Authorization": f"token {GITHUB_TOKEN}",
            "Accept": "application/vnd.github.v3+json",
        }) as r:
            if r.status != 200:
                return {}, ""
            data = await r.json()
            content = base64.b64decode(data["content"]).decode("utf-8")
            keys = json.loads(content) if content.strip() else {}
            return keys, data["sha"]


async def gh_write_keys(keys: dict, sha: str, message: str) -> bool:
    url = f"{GH_API}/repos/{GITHUB_REPO}/contents/{KEYS_FILE}"
    content = json.dumps(keys, indent=2, ensure_ascii=False)
    encoded = base64.b64encode(content.encode("utf-8")).decode("ascii")
    async with aiohttp.ClientSession() as s:
        async with s.put(url, json={
            "message": message,
            "content": encoded,
            "sha": sha,
        }, headers={
            "Authorization": f"token {GITHUB_TOKEN}",
            "Accept": "application/vnd.github.v3+json",
        }) as r:
            return r.status in (200, 201)


async def gh_add_key(key: str, note: str, plan: str) -> bool:
    if not GITHUB_TOKEN:
        return False
    try:
        keys, sha = await gh_read_keys()
        keys[key] = {"note": note, "plan": plan}
        return await gh_write_keys(keys, sha, f"Add key: {key[:8]}...")
    except Exception:
        return False


async def gh_remove_key(key: str) -> bool:
    if not GITHUB_TOKEN:
        return False
    try:
        keys, sha = await gh_read_keys()
        if key not in keys:
            return True
        del keys[key]
        return await gh_write_keys(keys, sha, f"Remove key: {key[:8]}...")
    except Exception:
        return False


async def log_action(guild: discord.Guild, embed: discord.Embed):
    if not LOG_CHANNEL_ID:
        return
    ch = guild.get_channel(LOG_CHANNEL_ID)
    if ch and isinstance(ch, discord.TextChannel):
        try:
            await ch.send(embed=embed)
        except discord.Forbidden:
            pass


async def ensure_role(guild: discord.Guild, name: str, reason: str = "Auto-created by license bot"):
    """A role of ROLE_CONFIG -> (role or None, "created" / "permissions set" / "exists" / "failed: ..."). An existing role
    gets the permissions of its config added (never taken away: what the owner gave it stays)."""
    cfg = ROLE_CONFIG.get(name, {"color": 0x808080, "hoist": False})
    perms = cfg.get("permissions")
    role = guild_role(guild, name)
    try:
        if role is None:
            kw = {"permissions": perms} if perms is not None else {}
            role = await guild.create_role(name=name, color=discord.Color(cfg["color"]), hoist=cfg["hoist"],
                                           mentionable=False, reason=reason, **kw)
            return role, "created"
        if perms is not None and not perms.is_subset(role.permissions):
            await role.edit(permissions=role.permissions | perms, reason=reason)
            return role, "permissions set"
        return role, "exists"
    except discord.Forbidden:
        return role, "failed: the bot's role must be above it in Server Settings > Roles and have these permissions"
    except discord.HTTPException as e:
        return role, f"failed: {e}"


async def find_or_create_role(guild: discord.Guild, name: str) -> discord.Role | None:
    return (await ensure_role(guild, name))[0]


async def create_setup_channel(guild: discord.Guild, ch: dict, category, overwrites: dict, reason: str):
    """A channel of CHANNEL_STRUCTURE -> (channel, note). A forum the server can not have (forums need Community on in
    Server Settings) becomes a text channel instead of stopping the whole setup."""
    kw = dict(name=ch["name"], topic=ch.get("topic", ""), category=category, overwrites=overwrites, reason=reason)
    if ch.get("type", "text") == "forum":
        try:
            return await guild.create_forum(**kw), ""
        except discord.Forbidden:
            raise
        except discord.HTTPException:
            return await guild.create_text_channel(**kw), " (text channel: forums need Community)"
    return await guild.create_text_channel(**kw), ""


# ── Ticket system (persistent views) ────────────────────────────────

class TicketCreateView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)

    @discord.ui.button(
        label="Create Ticket", style=discord.ButtonStyle.blurple,
        custom_id="specter:ticket:create", emoji="\U0001f3ab",
    )
    async def create_ticket(self, interaction: discord.Interaction, button: discord.ui.Button):
        guild  = interaction.guild
        member = interaction.user
        slug   = member.name.lower().replace(" ", "-")[:20]

        existing = discord.utils.get(guild.text_channels, name=f"ticket-{slug}")
        if existing:
            await interaction.response.send_message(
                f"You already have an open ticket: {existing.mention}", ephemeral=True)
            return

        staff_role = guild_role(guild, "Staff")
        overwrites = {
            guild.default_role: discord.PermissionOverwrite(view_channel=False),
            member: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True, attach_files=True),
            guild.me: discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True, manage_channels=True),
        }
        if staff_role:
            overwrites[staff_role] = discord.PermissionOverwrite(
                view_channel=True, send_messages=True, read_message_history=True)

        category = discord.utils.get(guild.categories, name="Tickets")
        if not category:
            try:
                category = await guild.create_category("Tickets", overwrites={
                    guild.default_role: discord.PermissionOverwrite(view_channel=False),
                    guild.me: discord.PermissionOverwrite(view_channel=True, manage_channels=True),
                })
            except discord.Forbidden:
                category = None

        try:
            channel = await guild.create_text_channel(
                name=f"ticket-{slug}",
                category=category,
                overwrites=overwrites,
                topic=f"Support ticket for {member.display_name}",
                reason=f"Ticket by {member}",
            )
        except discord.Forbidden:
            await interaction.response.send_message(
                "Could not create ticket. Missing permissions.", ephemeral=True)
            return

        embed = discord.Embed(
            title="\U0001f3ab Support Ticket",
            description=(
                f"Welcome {member.mention}!\n\n"
                "Describe your issue and a staff member will help you.\n"
                "Click **Close Ticket** when your issue is resolved."
            ),
            color=0x82C3FF,
        )
        embed.set_footer(text="Specter Support \U0001f319")
        await channel.send(embed=embed, view=TicketCloseView())
        await interaction.response.send_message(f"Ticket created: {channel.mention}", ephemeral=True)

        await log_action(guild, discord.Embed(
            title="Ticket Opened",
            description=f"{member.mention} opened {channel.mention}",
            color=0x82C3FF,
        ))


class TicketCloseView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)

    @discord.ui.button(
        label="Close Ticket", style=discord.ButtonStyle.danger,
        custom_id="specter:ticket:close", emoji="\U0001f512",
    )
    async def close_ticket(self, interaction: discord.Interaction, button: discord.ui.Button):
        channel = interaction.channel
        if not channel.name.startswith("ticket-"):
            await interaction.response.send_message("This is not a ticket channel.", ephemeral=True)
            return

        await interaction.response.send_message(
            embed=discord.Embed(
                title="\U0001f512 Ticket Closing",
                description="This ticket will be deleted in 5 seconds...",
                color=0xFF6060,
            )
        )
        await log_action(interaction.guild, discord.Embed(
            title="Ticket Closed",
            description=f"{interaction.user.mention} closed **{channel.name}**",
            color=0xFF6060,
        ))
        await asyncio.sleep(5)
        try:
            await channel.delete(reason=f"Ticket closed by {interaction.user}")
        except discord.Forbidden:
            await channel.send("Could not delete channel. Please delete manually.")


# ── Auto-role on join ─────────────────────────────────────────────────

@client.event
async def on_member_join(member: discord.Member):
    role = await find_or_create_role(member.guild, DEFAULT_ROLE_NAME)
    if not role:
        return
    try:
        await member.add_roles(role, reason="Auto-role on join")
    except discord.Forbidden:
        pass

    embed = discord.Embed(
        title="Member Joined",
        description=f"{member.mention} joined and got **{role.name}** role.",
        color=0x82C3FF,
    )
    embed.set_thumbnail(url=member.display_avatar.url if member.display_avatar else "")
    await log_action(member.guild, embed)


# ── /setup_roles — create all roles at once ──────────────────────────

@tree.command(name="setup_roles", description="Create all license roles (Member, Specter, Beta, Nightly, Customer, Staff)")
async def setup_roles(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    guild = interaction.guild
    created = []
    existed = []
    failed  = []

    updated = []
    for name in ROLE_CONFIG:
        _, what = await ensure_role(guild, name, f"Setup by {interaction.user}")
        {"created": created, "permissions set": updated, "exists": existed}.get(what, failed).append(name)

    embed = discord.Embed(title="Role Setup", color=0x60FF90)
    if created:
        embed.add_field(name="Created", value=", ".join(f"**{r}**" for r in created), inline=False)
    if updated:
        embed.add_field(name="Permissions set", value=", ".join(f"**{r}**" for r in updated), inline=False)
    if existed:
        embed.add_field(name="Already exist", value=", ".join(f"**{r}**" for r in existed), inline=False)
    if failed:
        embed.add_field(name="Failed (the bot's role must be above them, with their permissions)",
                        value=", ".join(f"**{r}**" for r in failed), inline=False)

    desc_lines = [
        "**Role hierarchy (drag in Server Settings > Roles):**",
        "",
        "```",
        "  (the bot)  — above Staff, or it can not manage it",
        "  Staff      — moderator + the bot's support commands",
        "  Nightly    — nightly plan users",
        "  Beta       — beta plan users",
        "  Specter    — specter plan users",
        "  Customer   — any redeemed key",
        "  Member     — auto-assigned on join",
        "  @everyone  — no access",
        "```",
        "",
        "**Recommended channel permissions:**",
        "- `#general` — Member+",
        "- `#support` — Customer+",
        "- `#specter` — Specter only",
        "- `#beta` — Beta only",
        "- `#nightly` — Nightly only",
        "- `#staff` — Staff only",
    ]
    embed.description = "\n".join(desc_lines)
    await interaction.followup.send(embed=embed, ephemeral=True)


# ── /setup_channels — full server structure ──────────────────────────

@tree.command(name="setup_channels", description="Create full server channel structure (categories + channels)")
async def setup_channels(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    guild = interaction.guild

    member_role   = await find_or_create_role(guild, "Member")
    customer_role = await find_or_create_role(guild, "Customer")
    staff_role    = await find_or_create_role(guild, "Staff")

    access_map = {
        "member":   [member_role],
        "customer": [customer_role, staff_role],
        "staff":    [staff_role],
    }

    created = []
    existed = []
    failed  = []

    for section in CHANNEL_STRUCTURE:
        cat_name = section["category"]
        category = discord.utils.get(guild.categories, name=cat_name)
        if not category:
            try:
                category = await guild.create_category(
                    cat_name,
                    reason=f"Setup by {interaction.user}",
                )
            except discord.HTTPException:
                failed.append(f"Category: {cat_name}")
                continue

        for ch in section["channels"]:
            ch_name = ch["name"]
            existing = discord.utils.get(guild.channels, name=ch_name, category=category)
            if existing:
                existed.append(f"#{ch_name}")
                continue

            overwrites = {
                guild.default_role: discord.PermissionOverwrite(view_channel=False),
                guild.me: discord.PermissionOverwrite(
                    view_channel=True, send_messages=True, manage_channels=True,
                    read_message_history=True),
            }

            if ch.get("readonly"):
                if member_role:
                    overwrites[member_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=False, read_message_history=True)
                if staff_role:
                    overwrites[staff_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=True, read_message_history=True)
            elif ch.get("access") == "customer_readonly":
                if customer_role:
                    overwrites[customer_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=False, read_message_history=True)
                if staff_role:
                    overwrites[staff_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=True, read_message_history=True)
            elif ch.get("access") in access_map:
                for role in access_map[ch["access"]]:
                    if role:
                        overwrites[role] = discord.PermissionOverwrite(
                            view_channel=True, send_messages=True,
                            read_message_history=True, attach_files=True)
            else:
                if member_role:
                    overwrites[member_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=True, read_message_history=True)

            try:
                _, note = await create_setup_channel(guild, ch, category, overwrites, f"Setup by {interaction.user}")
                created.append(f"#{ch_name}{note}")
            except discord.HTTPException:
                failed.append(f"#{ch_name}")

    embed = discord.Embed(title="\U0001f319 Channel Setup Complete", color=0x82C3FF)
    if created:
        embed.add_field(name="Created", value="\n".join(created), inline=False)
    if existed:
        embed.add_field(name="Already exist", value="\n".join(existed), inline=False)
    if failed:
        embed.add_field(name="Failed (perms)", value="\n".join(failed), inline=False)
    embed.set_footer(text="Use /setup_tickets in #support-ticket, /post_prices in #prices, /post_rules in #rules, /post_loader for #loader-download")
    await interaction.followup.send(embed=embed, ephemeral=True)


# ── /give_role — manual role assign ──────────────────────────────────

@tree.command(name="give_role", description="Give a role to a user")
@app_commands.describe(user="Target user", role_name="Role to give")
@app_commands.choices(
    role_name=[app_commands.Choice(name=r, value=r) for r in ROLE_CONFIG],
)
async def give_role(interaction: discord.Interaction, user: discord.Member, role_name: str):
    if not is_staff(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return
    if role_name == "Staff" and not is_admin(interaction):
        await interaction.response.send_message("Only the owner / admins can change who is Staff.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    role = await find_or_create_role(interaction.guild, role_name)
    if not role:
        await interaction.followup.send("Could not find/create role.", ephemeral=True)
        return

    try:
        await user.add_roles(role, reason=f"Given by {interaction.user}")
        embed = discord.Embed(title="Role Given", color=0x60FF90)
        embed.description = f"{user.mention} got **{role_name}**"
        await interaction.followup.send(embed=embed, ephemeral=True)
        await log_action(interaction.guild, embed)
    except discord.Forbidden:
        await interaction.followup.send("Missing permissions to assign role.", ephemeral=True)


# ── /remove_role — manual role remove ────────────────────────────────

@tree.command(name="remove_role", description="Remove a role from a user")
@app_commands.describe(user="Target user", role_name="Role to remove")
@app_commands.choices(
    role_name=[app_commands.Choice(name=r, value=r) for r in ROLE_CONFIG],
)
async def remove_role(interaction: discord.Interaction, user: discord.Member, role_name: str):
    if not is_staff(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return
    if role_name == "Staff" and not is_admin(interaction):
        await interaction.response.send_message("Only the owner / admins can change who is Staff.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    role = guild_role(interaction.guild, role_name)
    if not role:
        await interaction.followup.send(f"Role '{role_name}' not found.", ephemeral=True)
        return

    try:
        await user.remove_roles(role, reason=f"Removed by {interaction.user}")
        embed = discord.Embed(title="Role Removed", color=0xFF6060)
        embed.description = f"{user.mention} lost **{role_name}**"
        await interaction.followup.send(embed=embed, ephemeral=True)
        await log_action(interaction.guild, embed)
    except discord.Forbidden:
        await interaction.followup.send("Missing permissions to remove role.", ephemeral=True)


# ── /key create ───────────────────────────────────────────────────────

@tree.command(name="key_create", description="Generate a new license key")
@app_commands.describe(
    plan="Plan tier",
    duration="How long the key lasts",
    note="Who this key is for",
)
@app_commands.choices(
    plan=[app_commands.Choice(name=p, value=p) for p in VALID_PLANS],
    duration=[app_commands.Choice(name=d, value=d) for d in VALID_DURATIONS],
)
async def key_create(
    interaction: discord.Interaction,
    plan: str,
    duration: str = "lifetime",
    note: str = "",
):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        res = await api_post("/admin/create", {"plan": plan, "duration": duration, "note": note})
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if res.get("key"):
        exp = res.get("expires_at")
        exp_str = "lifetime" if not exp else f"<t:{int(exp/1000)}:R>"

        synced = await gh_add_key(res["key"], note or "", plan)

        embed = discord.Embed(title="Key Created", color=0x60FF90)
        embed.add_field(name="Key",      value=f"```{res['key']}```", inline=False)
        embed.add_field(name="Plan",     value=plan,    inline=True)
        embed.add_field(name="Duration", value=exp_str, inline=True)
        embed.add_field(name="GitHub",   value="Off" if not GITHUB_TOKEN else ("Synced" if synced else "Sync failed"), inline=True)
        if note:
            embed.add_field(name="Note", value=note, inline=True)
        await interaction.followup.send(embed=embed, ephemeral=True)

        log_embed = discord.Embed(title="Key Created", color=0x60FF90)
        log_embed.add_field(name="Plan", value=plan, inline=True)
        log_embed.add_field(name="Duration", value=exp_str, inline=True)
        log_embed.add_field(name="By", value=interaction.user.mention, inline=True)
        log_embed.add_field(name="GitHub", value="Off" if not GITHUB_TOKEN else ("Synced" if synced else "Failed"), inline=True)
        if note:
            log_embed.add_field(name="Note", value=note, inline=True)
        await log_action(interaction.guild, log_embed)
    else:
        await interaction.followup.send(f"Failed: {res}", ephemeral=True)


# ── /key revoke ───────────────────────────────────────────────────────

@tree.command(name="key_revoke", description="Revoke a license key and optionally remove user's role")
@app_commands.describe(key="The license key to revoke", user="User to remove plan role from (optional)")
async def key_revoke(interaction: discord.Interaction, key: str, user: discord.Member = None):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        res = await api_post("/admin/revoke", {"key": key})
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if res.get("revoked"):
        synced = await gh_remove_key(key)

        embed = discord.Embed(title="Key Revoked", color=0xFF6060)
        embed.add_field(name="Key", value=f"```{key}```", inline=False)
        embed.add_field(name="GitHub", value="Removed" if synced else "Sync failed", inline=True)

        if user:
            removed_roles = []
            for rname in list(PLAN_TO_ROLE.values()) + ["Customer"]:
                role = guild_role(interaction.guild, rname)
                if role and role in user.roles:
                    try:
                        await user.remove_roles(role, reason=f"Key revoked by {interaction.user}")
                        removed_roles.append(rname)
                    except discord.Forbidden:
                        pass
            if removed_roles:
                embed.add_field(name="Roles removed", value=f"{user.mention}: {', '.join(removed_roles)}", inline=False)

        await interaction.followup.send(embed=embed, ephemeral=True)

        log_embed = discord.Embed(title="Key Revoked", color=0xFF6060)
        log_embed.add_field(name="By", value=interaction.user.mention, inline=True)
        if user:
            log_embed.add_field(name="User", value=user.mention, inline=True)
        await log_action(interaction.guild, log_embed)
    else:
        await interaction.followup.send(f"Failed: {res}", ephemeral=True)


# ── /key reset_hwid ──────────────────────────────────────────────────

@tree.command(name="key_reset_hwid", description="Reset HWID lock on a key")
@app_commands.describe(key="The license key to reset HWID for")
async def key_reset_hwid(interaction: discord.Interaction, key: str):
    if not is_staff(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        res = await api_post("/admin/reset_hwid", {"key": key})
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if res.get("reset"):
        embed = discord.Embed(title="HWID Reset", color=0xFFC850)
        embed.add_field(name="Key", value=f"```{key}```", inline=False)
        embed.description = "Key can now be activated on a new machine."
        await interaction.followup.send(embed=embed, ephemeral=True)
    else:
        await interaction.followup.send(f"Failed: {res}", ephemeral=True)


# ── /key list ─────────────────────────────────────────────────────────

@tree.command(name="key_list", description="List all license keys")
@app_commands.describe(plan="Filter by plan (optional)")
@app_commands.choices(
    plan=[app_commands.Choice(name=p, value=p) for p in VALID_PLANS],
)
async def key_list(interaction: discord.Interaction, plan: str = ""):
    if not is_staff(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        keys = await api_get("/admin/list")
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if isinstance(keys, dict) and keys.get("status") == 403:
        await interaction.followup.send("Auth failed — check ADMIN_SECRET.", ephemeral=True)
        return

    if plan:
        keys = [k for k in keys if k.get("plan") == plan]

    if not keys:
        await interaction.followup.send("No keys found.", ephemeral=True)
        return

    admin = is_admin(interaction)

    chunks = []
    current = ""
    for k in keys:
        if k.get("revoked"):
            status = "REVOKED"
        elif k.get("expired"):
            status = "EXPIRED"
        elif k.get("hwid_locked"):
            status = "ACTIVE"
        else:
            status = "UNUSED"

        key = k["key"] if admin else k["key"][:6] + "…"        # Staff sees which keys exist, not the keys
        line = f"`{key}` | **{k['plan']}** | {status}"
        if k.get("note"):
            line += f" | {k['note']}"
        line += "\n"

        if len(current) + len(line) > 3900:
            chunks.append(current)
            current = line
        else:
            current += line

    if current:
        chunks.append(current)

    for i, chunk in enumerate(chunks):
        embed = discord.Embed(
            title=f"License Keys ({len(keys)} total)" if i == 0 else "Keys (cont.)",
            description=chunk,
            color=0x82C3FF,
        )
        await interaction.followup.send(embed=embed, ephemeral=True)


# ── /key info ─────────────────────────────────────────────────────────

@tree.command(name="key_info", description="Show details for a specific key")
@app_commands.describe(key="The license key to look up")
async def key_info(interaction: discord.Interaction, key: str):
    if not is_staff(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        keys = await api_get("/admin/list")
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if isinstance(keys, dict):
        await interaction.followup.send(f"Error: {keys}", ephemeral=True)
        return

    found = next((k for k in keys if k["key"] == key), None)
    if not found:
        await interaction.followup.send(f"Key `{key}` not found.", ephemeral=True)
        return

    status = "REVOKED" if found.get("revoked") else "EXPIRED" if found.get("expired") else "ACTIVE" if found.get("hwid_locked") else "UNUSED"
    color  = 0xFF6060 if status in ("REVOKED","EXPIRED") else 0x60FF90 if status == "ACTIVE" else 0xC8C8C8

    exp = found.get("expires_at")
    exp_str = "Lifetime" if not exp else f"<t:{int(exp/1000)}:F>"

    embed = discord.Embed(title="Key Details", color=color)
    embed.add_field(name="Key",      value=f"```{found['key']}```", inline=False)
    embed.add_field(name="Plan",     value=found["plan"],   inline=True)
    embed.add_field(name="Status",   value=status,          inline=True)
    embed.add_field(name="Expires",  value=exp_str,         inline=True)
    embed.add_field(name="HWID",     value="Locked" if found.get("hwid_locked") else "Not set", inline=True)
    if found.get("note"):
        embed.add_field(name="Note", value=found["note"], inline=True)
    await interaction.followup.send(embed=embed, ephemeral=True)


# ── /key sync — full sync from server to GitHub ─────────────────────

@tree.command(name="key_sync", description="Sync all keys from server to GitHub (full overwrite)")
async def key_sync(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    if not GITHUB_TOKEN:
        await interaction.response.send_message("GITHUB_TOKEN not set.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        keys = await api_get("/admin/list")
    except Exception as e:
        await interaction.followup.send(f"API error: {e}", ephemeral=True)
        return

    if isinstance(keys, dict):
        await interaction.followup.send(f"Error: {keys}", ephemeral=True)
        return

    gh_keys = {}
    for k in keys:
        if not k.get("revoked") and not k.get("expired"):
            gh_keys[k["key"]] = {"note": k.get("note", ""), "plan": k.get("plan", "")}

    try:
        _, sha = await gh_read_keys()
        ok = await gh_write_keys(gh_keys, sha, f"Full sync: {len(gh_keys)} active keys")
    except Exception as e:
        await interaction.followup.send(f"GitHub error: {e}", ephemeral=True)
        return

    if ok:
        embed = discord.Embed(title="Keys Synced to GitHub", color=0x60FF90)
        embed.description = f"**{len(gh_keys)}** active keys pushed."
        await interaction.followup.send(embed=embed, ephemeral=True)
    else:
        await interaction.followup.send("GitHub sync failed.", ephemeral=True)


# ── GitHub file download (/script_upload, /post_loader) ─────────────

class GitHubFetchError(Exception):
    pass


async def gh_get_file(path: str, ref: str, etag: str = "") -> tuple[bytes | None, str]:
    """A file of GITHUB_REPO at `ref` (branch or commit) -> (bytes, etag); bytes None = unchanged since `etag`.
    Public repo: raw.githubusercontent (no API limit); with SCRIPT_TOKEN (private repo) the contents API with that token."""
    if SCRIPT_TOKEN:
        url = f"{GH_API}/repos/{GITHUB_REPO}/contents/{path}?ref={ref}"
        headers = {"Authorization": f"Bearer {SCRIPT_TOKEN}", "Accept": "application/vnd.github.raw",
                   "X-GitHub-Api-Version": "2022-11-28"}
    else:
        url = f"https://raw.githubusercontent.com/{GITHUB_REPO}/{ref}/{path}"
        headers = {}
    if etag:
        headers["If-None-Match"] = etag
    async with aiohttp.ClientSession() as s:
        async with s.get(url, headers=headers, timeout=aiohttp.ClientTimeout(total=60)) as r:
            if r.status == 304 and etag:
                return None, etag
            if r.status != 200:
                hint = ""
                if r.status in (401, 403):
                    hint = " (SCRIPT_TOKEN wrong or expired, or it has no read access to this repo)"
                elif r.status == 404 and not SCRIPT_TOKEN:
                    hint = " (private repo? set SCRIPT_TOKEN on the bot service)"
                raise GitHubFetchError(f"GitHub: {r.status} for `{url.split('?')[0]}`{hint}")
            return await r.read(), r.headers.get("ETag", "")


async def gh_fetch_file(path: str, branch: str = "") -> tuple[bytes, str]:
    """A file of GITHUB_REPO at `branch` (default SCRIPT_BRANCH) -> (bytes, source text)."""
    br = branch or SCRIPT_BRANCH
    raw, _ = await gh_get_file(path, br)
    return raw, f"GitHub {GITHUB_REPO}@{br}"


# ── /script_upload — put the cloud Lua on the license server ─────────

def strip_lua_comments(src: str) -> str:
    """Comments and blank lines out, strings and long strings kept (the same as the owners' build)."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:i + 64])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i + m.end())
                if j < 0:
                    raise ValueError("unclosed long comment")
                out.append("\n" * src.count("\n", i, j))
                i = j + len(close)
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        if c in "\"'":
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == c or src[j] == "\n":
                    break
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
            continue
        if c == "[":
            m = re.match(r"\[(=*)\[", src[i:i + 64])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i + m.end())
                if j < 0:
                    raise ValueError("unclosed long string")
                out.append(src[i:j + len(close)])
                i = j + len(close)
                continue
        out.append(c)
        i += 1
    lines = [l.rstrip() for l in "".join(out).split("\n")]
    return "\n".join(l for l in lines if l.strip()) + "\n"


CLOUD_FILE = "specter_cloud.lua"


def is_cloud_script(text: str) -> bool:
    """Only the cloud script: it has the auth gate the loader's prefix opens (the dev build has none)."""
    return "-- ── AUTH GATE" in text and "_auth_ok" in text


async def upload_script(script: str, plans: list[str]) -> tuple[list[str], list[str]]:
    """The comment-free cloud script to the license server -> (one line per plan, the plans that got it)."""
    lines, done = [], []
    for p in plans:
        try:
            res = await api_post("/admin/upload_script", {"plan": p, "script": script})
            ok = res.get("ok") and res.get("status") == 200
            lines.append(f"`{p}`: " + (f"ok ({res.get('bytes', 0) // 1024} KB, {res.get('parts', 1)} parts)" if ok else f"failed {res}"))
            if ok:
                done.append(p)
        except Exception as e:
            lines.append(f"`{p}`: API error {e}")
    return lines, done


@tree.command(name="script_upload", description="Upload specter_cloud.lua to the license server (a file, or from GitHub)")
@app_commands.describe(
    file="specter_cloud.lua (empty: taken from GitHub)",
    branch="GitHub branch when no file is given (default: SCRIPT_BRANCH)",
    plan="Which plan gets it (default: all four)",
)
@app_commands.choices(plan=[app_commands.Choice(name="all", value="all")] + [app_commands.Choice(name=p, value=p) for p in VALID_PLANS])
async def script_upload(
    interaction: discord.Interaction,
    file: discord.Attachment = None,
    branch: str = "",
    plan: str = "all",
):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    source = ""
    try:
        if file is not None:
            raw = await file.read()
            source = file.filename
        else:
            raw, source = await gh_fetch_file("specter_cloud.lua", branch)
        text = raw.decode("utf-8")
    except GitHubFetchError as e:
        await interaction.followup.send(str(e), ephemeral=True)
        return
    except Exception as e:
        await interaction.followup.send(f"Could not read the script: {e}", ephemeral=True)
        return

    if not is_cloud_script(text):
        await interaction.followup.send("This is not specter_cloud.lua (no auth gate in it). Nothing uploaded.", ephemeral=True)
        return

    try:
        script = strip_lua_comments(text)
    except Exception as e:
        await interaction.followup.send(f"Could not clean the script: {e}", ephemeral=True)
        return

    plans = VALID_PLANS if plan == "all" else [plan]
    lines, _ = await upload_script(script, plans)

    embed = discord.Embed(title="Script Upload", color=0x82C3FF)
    embed.description = "\n".join(lines)
    embed.add_field(name="Source", value=source, inline=False)
    embed.add_field(name="Size", value=f"{len(text) // 1024} KB -> {len(script) // 1024} KB without comments", inline=False)
    await interaction.followup.send(embed=embed, ephemeral=True)

    log_embed = discord.Embed(title="Script Uploaded", color=0x82C3FF)
    log_embed.add_field(name="Plans", value=", ".join(plans), inline=True)
    log_embed.add_field(name="Source", value=source, inline=True)
    log_embed.add_field(name="By", value=interaction.user.mention, inline=True)
    await log_action(interaction.guild, log_embed)


# ── /post_loader — the customer loader in #loader-download ──────────

LOADER_FILE = "specter_loader.lua"


def is_customer_loader(text: str) -> bool:
    """Only the production loader may go to customers: never the cloud script, the dev build or the dev loader
    (those run the whole script without a key)."""
    return ("_specter_loader_loaded" in text and "AUTH GATE" not in text and "DEV LOADER" not in text
            and "[resolver:begin]" not in text and len(text) < 200_000)


@tree.command(name="post_loader", description="Post the Specter loader (specter_loader.lua) for customers to download")
@app_commands.describe(
    file="specter_loader.lua (empty: taken from GitHub)",
    branch="GitHub branch when no file is given (default: SCRIPT_BRANCH)",
    channel="Where to post it (default: #loader-download, else this channel)",
    replace="Delete the bot's older loader posts in that channel (default: yes)",
)
async def post_loader(
    interaction: discord.Interaction,
    file: discord.Attachment = None,
    branch: str = "",
    channel: discord.TextChannel = None,
    replace: bool = True,
):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    try:
        if file is not None:
            raw, source = await file.read(), file.filename
        else:
            raw, source = await gh_fetch_file(LOADER_FILE, branch)
        text = raw.decode("utf-8")
    except GitHubFetchError as e:
        await interaction.followup.send(str(e), ephemeral=True)
        return
    except Exception as e:
        await interaction.followup.send(f"Could not read the loader: {e}", ephemeral=True)
        return

    if not is_customer_loader(text):
        await interaction.followup.send(
            "This is not specter_loader.lua (the cloud script, the dev build and the dev loader are never posted). "
            "Nothing posted.", ephemeral=True)
        return

    target = channel or discord.utils.get(interaction.guild.text_channels, name="loader-download") or interaction.channel
    if not isinstance(target, discord.TextChannel):
        await interaction.followup.send("Pick a text channel to post the loader in.", ephemeral=True)
        return

    removed = 0
    if replace:
        try:
            async for msg in target.history(limit=50):
                if msg.author.id == client.user.id and any(a.filename == LOADER_FILE for a in msg.attachments):
                    await msg.delete()
                    removed += 1
        except discord.HTTPException:
            pass

    embed = discord.Embed(
        title="\U0001f4e5 Specter Loader",
        description=(
            "**Install**\n"
            "1. Download `specter_loader.lua` below\n"
            "2. Put it into your **CS:GO folder** (where `csgo.exe` is): gamesense loads Lua scripts from there\n"
            "3. In gamesense open the **Lua** tab, refresh the list and load **specter_loader**\n"
            "4. Go to **AA > Anti-aimbot angles**, copy your key and click **Paste key** (Ctrl+V does not work in gamesense text fields), pick a username & password\n"
            "5. **Register** the first time, **Login** after that. Your HWID locks on first use\n\n"
            "The script itself is downloaded from our server every time you log in, so this file only changes "
            "when we post a new one here.\n"
            "No key yet? See #prices. Problems? Open a ticket in #support-ticket."
        ),
        color=0x82C3FF,
    )
    embed.add_field(name="Updated", value=f"<t:{int(discord.utils.utcnow().timestamp())}:D>", inline=True)
    embed.add_field(name="SHA-256", value=f"`{hashlib.sha256(raw).hexdigest()[:16]}`", inline=True)
    embed.set_footer(text="Specter \U0001f319 • never share your key or the loader")
    if LOGO_URL:
        embed.set_thumbnail(url=LOGO_URL)
    try:
        await target.send(embed=embed, file=discord.File(io.BytesIO(raw), filename=LOADER_FILE))
    except discord.HTTPException as e:
        await interaction.followup.send(f"Could not post in {target.mention}: {e}", ephemeral=True)
        return

    note = f" ({removed} older post{'s' if removed != 1 else ''} removed)" if removed else ""
    await interaction.followup.send(f"Loader posted in {target.mention}{note}. Source: {source}", ephemeral=True)

    log_embed = discord.Embed(title="Loader Posted", color=0x82C3FF)
    log_embed.add_field(name="Channel", value=target.mention, inline=True)
    log_embed.add_field(name="Source", value=source, inline=True)
    log_embed.add_field(name="By", value=interaction.user.mention, inline=True)
    await log_action(interaction.guild, log_embed)


# ── New script versions -> the staff channel ────────────────────────

def _env_int(name: str, default: int) -> int:
    try:
        return int(_env(name, str(default)))
    except ValueError:
        return default


RELEASE_CHANNEL = _env("RELEASE_CHANNEL", "staff")
RELEASE_FILES   = [f.strip() for f in _env("RELEASE_FILES", "specter_dev.lua").split(",") if f.strip()]
RELEASE_MINUTES = _env_int("RELEASE_MINUTES", 5)
AUTO_UPLOAD     = _env("AUTO_UPLOAD", "1").lower() not in ("0", "false", "off", "no")
RELEASE_ROLES   = [r for r in ROLE_CONFIG if r != "Staff"]     # never posted where one of these (or @everyone) reads
RELEASE_FOOTER  = re.compile(r"^(\S+) @ ([0-9a-f]{16})$")       # the footer of a version post: file @ its SHA-256
_release_seen: dict[int, dict[str, str]] = {}                   # channel id -> file -> SHA-256 of the newest post there
_release_files: dict[str, dict] = {}                            # file -> the newest version GitHub has (body, hash, commit, etag)
_release_lock = asyncio.Lock()
_cloud_on_server = ""                                           # SHA-256 of the cloud script the server is known to have


def release_channel(guild: discord.Guild) -> discord.TextChannel | None:
    ch = (guild.get_channel(int(RELEASE_CHANNEL)) if RELEASE_CHANNEL.isdigit()
          else discord.utils.get(guild.text_channels, name=RELEASE_CHANNEL))
    return ch if isinstance(ch, discord.TextChannel) else None


def non_staff_readers(ch: discord.TextChannel) -> list[str]:
    """Which of @everyone and the member / customer / plan roles can read the channel (empty = staff only)."""
    roles = [(ch.guild.default_role, "@everyone")] + [(r, r.name) for r in ch.guild.roles
                                                    if r.name in RELEASE_ROLES and not r.managed]
    return [name + (" (has Administrator)" if r.permissions.administrator else "")
            for r, name in roles if ch.permissions_for(r).view_channel]


async def gh_last_commit(path: str) -> tuple[dict | None, str]:
    """The newest commit of SCRIPT_BRANCH that changed `path` -> (commit, error). Only for the message: the GitHub API
    allows 60 calls / hour per IP without a token (shared on Railway), SCRIPT_TOKEN gives the bot its own limit."""
    headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
    if SCRIPT_TOKEN:
        headers["Authorization"] = f"Bearer {SCRIPT_TOKEN}"
    try:
        async with aiohttp.ClientSession() as s:
            async with s.get(f"{GH_API}/repos/{GITHUB_REPO}/commits", headers=headers,
                             params={"path": path, "sha": SCRIPT_BRANCH, "per_page": "1"},
                             timeout=aiohttp.ClientTimeout(total=30)) as r:
                if r.status != 200:
                    return None, f"GitHub API {r.status}" + (" (limit: set SCRIPT_TOKEN)" if r.status in (403, 429) else "")
                data = await r.json()
    except (aiohttp.ClientError, asyncio.TimeoutError) as e:
        return None, f"GitHub API: {e!r}"
    return (data[0], "") if data else (None, "no commit")


def short_point(text: str, limit: int = 80) -> str:
    """One line of a list: up to the first clause end after 25 characters, at most `limit` (cut at a word)."""
    text = " ".join(text.split()).rstrip(".:;,")
    depth, quoted = 0, False
    for i, c in enumerate(text):
        end = text.startswith(". ", i) and (text[i - 1].isalnum() or text[i - 1] in ")\"'")    # not "5 .. 60"
        if i >= 25 and depth == 0 and not quoted and (end or text.startswith(("; ", ": ", " (", ", ", " - ", " — "), i)):
            text = text[:i]
            break
        if c == '"':
            quoted = not quoted
        elif c == "(":
            depth += 1
        elif c == ")":
            depth = max(depth - 1, 0)
    if len(text) > limit:
        text = text[:limit].rsplit(" ", 1)[0] + "…"
    return text


def commit_points(message: str, most: int = 6) -> str:
    """The commit as a short list: its title in bold, then one short line per "- " item of the body (or per sentence
    when it has no list). A PR merge says it after its first line; the attribution lines are left out."""
    lines = (message or "").strip().split("\n")
    if len(lines) > 1 and lines[0].startswith("Merge pull request"):
        lines = lines[1:]
    lines = [l for l in lines if not re.match(r"^\s*(Co-Authored-By|Claude-Session|Signed-off-by):", l, re.I)]
    while lines and not lines[0].strip():
        lines.pop(0)
    if not lines:
        return ""
    title, body = lines[0].strip(), "\n".join(lines[1:])
    items = [m.group(1) for m in re.finditer(r"^\s*[-*•]\s+(.+?)(?=^\s*[-*•]\s|^\s*$|\Z)", body, re.M | re.S)]
    if not items:
        items = [x for x in re.split(r"(?<=[.!?])\s+(?=[A-Z])", " ".join(body.split())) if x][:3]
    points = [short_point(x) for x in items]
    out = [f"**{title}**"] + [f"• {p}" for p in points[:most]]
    if len(points) > most:
        out.append(f"• … and {len(points) - most} more (see the commit)")
    return "\n".join(out)


async def posted_versions(ch: discord.TextChannel) -> dict[str, str]:
    """file -> SHA-256 of the bot's newest version post in the channel (after a restart nothing is posted twice)."""
    seen = {}
    try:
        async for msg in ch.history(limit=200):
            if msg.author.id == client.user.id and msg.embeds:
                m = RELEASE_FOOTER.match(msg.embeds[0].footer.text or "")
                if m and m.group(1) not in seen:
                    seen[m.group(1)] = m.group(2)
    except discord.HTTPException:
        pass
    return seen


async def newest_version(path: str) -> dict:
    """The newest version of `path` on SCRIPT_BRANCH. The file is checked with its ETag (unchanged = nothing downloaded,
    raw.githubusercontent has no API limit); the commit (for the message) is asked only when the file changed."""
    old = _release_files.get(path)
    raw, etag = await gh_get_file(path, SCRIPT_BRANCH, old["etag"] if old else "")
    if raw is None or (old and hashlib.sha256(raw).digest() == old["raw_hash"]):
        old["etag"] = etag
        return old
    commit, err = await gh_last_commit(path)
    if commit:
        try:            # the file of exactly that commit: the raw cache of the branch can be a few minutes old
            raw, _ = await gh_get_file(path, commit["sha"])
        except (GitHubFetchError, aiohttp.ClientError, asyncio.TimeoutError):
            pass
    body, stripped = raw, False
    if path.endswith(".lua"):               # without comments, like the owners' copy and the server's
        try:
            body, stripped = strip_lua_comments(raw.decode("utf-8")).encode("utf-8"), True
        except (UnicodeDecodeError, ValueError):
            pass
    ver = dict(body=body, stripped=stripped, hash=hashlib.sha256(body).hexdigest()[:16], commit=commit, commit_err=err,
               raw=raw, raw_hash=hashlib.sha256(raw).digest(), etag=etag)
    _release_files[path] = ver
    return ver


def release_embed(path: str, ver: dict) -> discord.Embed:
    commit = ver["commit"]
    embed = discord.Embed(title=f"\U0001f195 New version: {path}", color=0xFFC850)
    if commit:
        info = commit.get("commit") or {}
        url = commit.get("html_url") or f"https://github.com/{GITHUB_REPO}/commit/{commit['sha']}"
        embed.url = url
        embed.description = commit_points(info.get("message", "")) or "-"
        embed.add_field(name="Commit", value=f"[`{commit['sha'][:7]}`]({url})", inline=True)
        try:
            when = datetime.fromisoformat((info.get("committer") or {}).get("date", "").replace("Z", "+00:00"))
            embed.add_field(name="Date", value=f"<t:{int(when.timestamp())}:f>", inline=True)
        except ValueError:
            pass
    else:
        embed.description = f"New `{path}` on `{SCRIPT_BRANCH}` (no commit message: {ver['commit_err']})"
    embed.add_field(name="Size", value=f"{len(ver['body']) // 1024} KB" + (" without comments" if ver["stripped"] else ""),
                    inline=True)
    embed.add_field(name="SHA-256", value=f"`{ver['hash']}`", inline=True)
    embed.set_footer(text=f"{path} @ {ver['hash']}")
    return embed


def staff_channels(report: list[str]) -> list[discord.TextChannel]:
    """The staff channel of every guild of the bot that only staff can read (the others are explained in `report`)."""
    out = []
    for guild in client.guilds:
        ch = release_channel(guild)
        if ch is None:
            report.append(f"{guild.name}: no #{RELEASE_CHANNEL} channel (RELEASE_CHANNEL), nothing posted")
            continue
        readers = non_staff_readers(ch)
        if readers:
            fix = ("Server Settings > Roles: take Administrator off that role" if any("Administrator" in r for r in readers)
                   else "Edit channel > Permissions: View Channel off for them")
            report.append(f"{guild.name}: {ch.mention} can be read by {', '.join(readers)}, nothing posted there. {fix}")
            continue
        out.append(ch)
    return out


async def check_releases(force: bool = False) -> list[str]:
    """Every RELEASE_FILES file whose newest version is not in the staff channel yet is posted there (in every guild of
    the bot). force: the current versions again. -> what happened, one line each"""
    async with _release_lock:
        report, versions = [], {}
        for path in RELEASE_FILES:
            try:
                versions[path] = await newest_version(path)
            except (GitHubFetchError, aiohttp.ClientError, asyncio.TimeoutError) as e:
                report.append(f"`{path}`: {e}")
        for ch in staff_channels(report):
            if ch.id not in _release_seen:
                _release_seen[ch.id] = await posted_versions(ch)
            seen = _release_seen[ch.id]
            for path, ver in versions.items():
                if seen.get(path) == ver["hash"] and not force:
                    continue
                try:
                    await ch.send(embed=release_embed(path, ver),
                                  file=discord.File(io.BytesIO(ver["body"]), filename=path.rsplit("/", 1)[-1]))
                except discord.HTTPException as e:
                    report.append(f"`{path}`: could not post in {ch.mention}: {e}")
                    continue
                seen[path] = ver["hash"]
                report.append(f"`{path}` `{ver['hash'][:7]}` posted in {ch.mention}")
        return report


async def server_script_hashes() -> dict | None:
    """plan -> SHA-256 of the script the license server has (None: a server without /admin/script_info, or down)."""
    try:
        res = await api_get("/admin/script_info")
    except Exception:
        return None
    return res if isinstance(res, dict) and res.get("status") == 200 else None


async def sync_cloud(force: bool = False) -> list[str]:
    """A new specter_cloud.lua of SCRIPT_BRANCH -> the license server, every plan that has another version (the loader
    downloads the script from the server at every login). A short note goes to the staff channel. force: upload again."""
    global _cloud_on_server
    async with _release_lock:
        try:
            ver = await newest_version(CLOUD_FILE)
        except (GitHubFetchError, aiohttp.ClientError, asyncio.TimeoutError) as e:
            return [f"`{CLOUD_FILE}`: {e}"]
        full = hashlib.sha256(ver["body"]).hexdigest()
        if full == _cloud_on_server and not force:
            return []
        if not ver["stripped"] or not is_cloud_script(ver["raw"].decode("utf-8", "replace")):
            return [f"`{CLOUD_FILE}` of `{SCRIPT_BRANCH}`: no auth gate or comments not removable, not uploaded"]
        have = await server_script_hashes()
        plans = [p for p in VALID_PLANS if force or have is None or have.get(p) != full]
        if not plans:
            _cloud_on_server = full
            return []
        lines, done = await upload_script(ver["body"].decode("utf-8"), plans)
        if len(done) == len(plans):
            _cloud_on_server = full
        report = [f"cloud script `{ver['hash'][:7]}` to the server: " + " ".join(lines)]
        if not done:
            return report
        embed = discord.Embed(title="\u2601\ufe0f Cloud script updated on the server", color=0x82C3FF,
                              description=(commit_points(ver["commit"]["commit"].get("message", "")) if ver["commit"]
                                           else f"New `{CLOUD_FILE}` on `{SCRIPT_BRANCH}`") or "-")
        if ver["commit"]:
            embed.url = ver["commit"].get("html_url") or None
        embed.add_field(name="Plans", value="\n".join(lines)[:1024], inline=False)
        embed.set_footer(text="Customers get it at their next login (the loader downloads it from the server)")
        for ch in staff_channels(report):
            try:
                await ch.send(embed=embed)
            except discord.HTTPException as e:
                report.append(f"could not post in {ch.mention}: {e}")
        return report


async def release_loop():
    """Checks GitHub every RELEASE_MINUTES; a problem is printed once, not every round."""
    await client.wait_until_ready()
    last = []
    while True:
        try:
            report = await check_releases()
            if AUTO_UPLOAD:
                report += await sync_cloud()
        except Exception as e:
            report = [f"version check failed: {e!r}"]
        for line in report:
            if "posted in" in line or "to the server" in line or line not in last:
                print(f"[release] {line}", flush=True)
        last = report
        await asyncio.sleep(RELEASE_MINUTES * 60)


@tree.command(name="release_check", description="Check GitHub now: dev build to the staff channel, cloud script to the server")
@app_commands.describe(force="Post the dev build and upload the cloud script again even if they are there already")
async def release_check(interaction: discord.Interaction, force: bool = False):
    if not is_staff(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return
    await interaction.response.defer(ephemeral=True)
    report = await check_releases(force)
    if AUTO_UPLOAD:
        report += await sync_cloud(force)
    text = "\n".join(report) or f"Nothing new: #{RELEASE_CHANNEL} and the server already have the newest versions."
    await interaction.followup.send(text[:1900], ephemeral=True)


# ── /redeem — user-facing key claim + auto role ──────────────────────

@tree.command(name="redeem", description="Claim your license key and get your role")
@app_commands.describe(key="Your license key")
async def redeem(interaction: discord.Interaction, key: str):
    await interaction.response.defer(ephemeral=True)
    try:
        keys = await api_get("/admin/list")
    except Exception as e:
        await interaction.followup.send("Server unreachable. Try again later.", ephemeral=True)
        return

    if isinstance(keys, dict):
        await interaction.followup.send("Server error.", ephemeral=True)
        return

    found = next((k for k in keys if k["key"] == key), None)
    if not found:
        await interaction.followup.send("Invalid key.", ephemeral=True)
        return

    if found.get("revoked"):
        await interaction.followup.send("This key has been revoked.", ephemeral=True)
        return
    if found.get("expired"):
        await interaction.followup.send("This key has expired.", ephemeral=True)
        return

    plan = found["plan"]
    exp  = found.get("expires_at")
    exp_str = "Lifetime" if not exp else f"<t:{int(exp/1000)}:R>"

    guild  = interaction.guild
    member = interaction.user

    assigned_roles = []

    customer_role = await find_or_create_role(guild, "Customer")
    if customer_role and customer_role not in member.roles:
        try:
            await member.add_roles(customer_role, reason=f"Redeemed key: {plan}")
            assigned_roles.append("Customer")
        except discord.Forbidden:
            pass

    plan_role_name = PLAN_TO_ROLE.get(plan)
    if plan_role_name:
        plan_role = await find_or_create_role(guild, plan_role_name)
        if plan_role and plan_role not in member.roles:
            try:
                await member.add_roles(plan_role, reason=f"Redeemed key: {plan}")
                assigned_roles.append(plan_role_name)
            except discord.Forbidden:
                pass

    embed = discord.Embed(title="Key Redeemed!", color=0x60FF90)
    embed.add_field(name="Key",      value=f"||{key}||",  inline=False)
    embed.add_field(name="Plan",     value=plan,           inline=True)
    embed.add_field(name="Expires",  value=exp_str,        inline=True)
    embed.add_field(name="Status",   value="Locked" if found.get("hwid_locked") else "Ready to activate", inline=True)
    if assigned_roles:
        embed.add_field(name="Roles given", value=", ".join(f"**{r}**" for r in assigned_roles), inline=False)
    embed.add_field(
        name="How to use",
        value=(
            "1. Open gamesense and load the loader\n"
            "2. Go to **AA > Anti-aimbot angles**\n"
            "3. Copy your key, click **Paste key**, pick a username & password\n"
            "4. Click **Register** (first time) or **Login**\n"
            "5. Your HWID locks on first use"
        ),
        inline=False,
    )
    await interaction.followup.send(embed=embed, ephemeral=True)

    log_embed = discord.Embed(title="Key Redeemed", color=0x60FF90)
    log_embed.add_field(name="User", value=member.mention, inline=True)
    log_embed.add_field(name="Plan", value=plan, inline=True)
    if assigned_roles:
        log_embed.add_field(name="Roles", value=", ".join(assigned_roles), inline=True)
    await log_action(guild, log_embed)


# ── /setup_tickets — post ticket panel ───────────────────────────────

@tree.command(name="setup_tickets", description="Post the ticket creation panel in the current channel")
async def setup_tickets(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    embed = discord.Embed(
        title="\U0001f3ab Specter Support",
        description=(
            "Need help? Click the button below to create a private support ticket.\n\n"
            "A staff member will assist you as soon as possible.\n\n"
            "**Before opening a ticket:**\n"
            "• Check #how-to-use for common questions\n"
            "• Make sure your key is valid\n"
            "• Describe your issue clearly"
        ),
        color=0x82C3FF,
    )
    embed.set_footer(text="Specter \U0001f319")
    if LOGO_URL:
        embed.set_thumbnail(url=LOGO_URL)

    await interaction.response.send_message("Ticket panel posted!", ephemeral=True)
    await interaction.channel.send(embed=embed, view=TicketCreateView())


# ── /close_ticket — manually close a ticket ──────────────────────────

@tree.command(name="close_ticket", description="Close the current ticket channel")
async def close_ticket(interaction: discord.Interaction):
    channel = interaction.channel
    if not channel.name.startswith("ticket-"):
        await interaction.response.send_message("This is not a ticket channel.", ephemeral=True)
        return

    staff = is_staff(interaction)
    is_owner = channel.name == f"ticket-{interaction.user.name.lower().replace(' ', '-')[:20]}"
    if not staff and not is_owner:
        await interaction.response.send_message("Only staff or the ticket owner can close this.", ephemeral=True)
        return

    await interaction.response.send_message(
        embed=discord.Embed(
            title="\U0001f512 Ticket Closing",
            description="This ticket will be deleted in 5 seconds...",
            color=0xFF6060,
        )
    )
    await log_action(interaction.guild, discord.Embed(
        title="Ticket Closed",
        description=f"{interaction.user.mention} closed **{channel.name}**",
        color=0xFF6060,
    ))
    await asyncio.sleep(5)
    try:
        await channel.delete(reason=f"Ticket closed by {interaction.user}")
    except discord.Forbidden:
        await channel.send("Could not delete channel. Please delete manually.")


# ── /post_prices — post prices embed ─────────────────────────────────

@tree.command(name="post_prices", description="Post the Specter pricing embed in the current channel")
async def post_prices(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    embed = discord.Embed(title="Prices", color=0x82C3FF)

    embed.add_field(
        name="\U0001f319 Specter for GS",
        value=price_lines(),
        inline=False,
    )

    pay_lines = [f"○ {m}" for m in PAYMENT_METHODS]
    if BUY_CONTACT:
        pay_lines.append(f"○ Tag to buy: **{BUY_CONTACT}**")
    embed.add_field(
        name="Payment Methods",
        value="\n".join(pay_lines),
        inline=False,
    )

    embed.add_field(
        name="\U0001f319 Specter Info",
        value=(
            "• *Versions* — `beta` | `nightly` | `specter`\n"
            "• *Status* — fully updated for 2026\n"
            "• *Platform* — gamesense"
        ),
        inline=False,
    )

    embed.add_field(name="\u2728 Features", value=FEATURES_TEXT, inline=False)

    embed.add_field(
        name="Still Have Questions?",
        value=(
            "• Open a ticket in #support-ticket\n"
            "• Check #how-to-use for setup guide"
        ),
        inline=False,
    )

    if LOGO_URL:
        embed.set_image(url=LOGO_URL)
    embed.set_footer(text="Specter \U0001f319 • gamesense lua")

    await interaction.response.send_message("Prices posted!", ephemeral=True)
    await interaction.channel.send(embed=embed)


# ── /post_rules — post server rules ──────────────────────────────────

@tree.command(name="post_rules", description="Post server rules embed in the current channel")
async def post_rules(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    embed = discord.Embed(
        title="\U0001f30d Rules",
        color=0x82C3FF,
    )
    embed.description = (
        "**1.** Be respectful to all members.\n"
        "**2.** No spamming or self-promotion.\n"
        "**3.** Do not share or resell license keys.\n"
        "**4.** Do not share the script or any part of it.\n"
        "**5.** Use #support-ticket for help, don't DM staff.\n"
        "**6.** No NSFW, illegal content, or doxxing.\n"
        "**7.** English / Hungarian only.\n"
        "**8.** Staff decisions are final.\n\n"
        "*Breaking any rule may result in a mute, kick, or ban.*"
    )
    if LOGO_URL:
        embed.set_thumbnail(url=LOGO_URL)
    embed.set_footer(text="Specter \U0001f319")

    await interaction.response.send_message("Rules posted!", ephemeral=True)
    await interaction.channel.send(embed=embed)


# ── /post_howto — post how-to-use guide ──────────────────────────────

@tree.command(name="post_howto", description="Post the how-to-use guide in the current channel")
async def post_howto(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    embed = discord.Embed(
        title="\U0001f4d5 How to Use Specter",
        color=0x82C3FF,
    )
    embed.add_field(
        name="Step 1 — Get Your Key",
        value=(
            "Purchase a plan in #prices or from staff.\n"
            "Use `/redeem <key>` in Discord to get your role."
        ),
        inline=False,
    )
    embed.add_field(
        name="Step 2 — Register / Login",
        value=(
            "1. Copy your **license key** and click **Paste key** (Ctrl+V does not work in gamesense)\n"
            "2. Choose a **username** and **password**\n"
            "3. Click **Register** (first time) or **Login**\n"
            "4. Your HWID locks on first activation"
        ),
        inline=False,
    )
    embed.add_field(
        name="Tier Features",
        value=(
            "```\n"
            "Plan       Resolver  Ragebot+  Tuning  Builder  AA Stealer\n"
            "specter    ✔         ✔         ✔       ✔        ✘\n"
            "nightly    ✘         ✔         ✔       ✔        ✘\n"
            "beta       ✘         ✘         ✘       ✘        ✘\n"
            "```"
        ),
        inline=False,
    )
    embed.add_field(
        name="Trouble?",
        value="Open a ticket in #support-ticket and we'll help.",
        inline=False,
    )
    if LOGO_URL:
        embed.set_thumbnail(url=LOGO_URL)
    embed.set_footer(text="Specter \U0001f319")

    await interaction.response.send_message("How-to guide posted!", ephemeral=True)
    await interaction.channel.send(embed=embed)


# ── /setup_server — one-click full server setup ──────────────────────

@tree.command(name="setup_server", description="Full server setup: roles + channels + panels (all-in-one)")
async def setup_server(interaction: discord.Interaction):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    guild = interaction.guild
    log_lines = []

    # 1. Create roles (an existing Staff role gets its permissions)
    for name in ROLE_CONFIG:
        _, what = await ensure_role(guild, name, f"Server setup by {interaction.user}")
        if what != "exists":
            log_lines.append(f"{'❌' if what.startswith('failed') else '✅'} Role **{name}** {what}")

    member_role   = await find_or_create_role(guild, "Member")
    customer_role = await find_or_create_role(guild, "Customer")
    staff_role    = await find_or_create_role(guild, "Staff")
    access_map = {
        "member":   [member_role],
        "customer": [customer_role, staff_role],
        "staff":    [staff_role],
    }

    # 2. Create channels
    prices_ch = None
    rules_ch  = None
    howto_ch  = None
    ticket_ch = None

    for section in CHANNEL_STRUCTURE:
        cat_name = section["category"]
        category = discord.utils.get(guild.categories, name=cat_name)
        if not category:
            try:
                category = await guild.create_category(cat_name, reason=f"Setup by {interaction.user}")
            except discord.HTTPException:
                log_lines.append(f"❌ Category **{cat_name}** failed")
                continue

        for ch in section["channels"]:
            ch_name = ch["name"]
            existing = discord.utils.get(guild.channels, name=ch_name, category=category)
            if existing:
                if ch_name == "prices":     prices_ch = existing
                if ch_name == "rules":      rules_ch  = existing
                if ch_name == "how-to-use": howto_ch  = existing
                if ch_name == "support-ticket": ticket_ch = existing
                continue

            overwrites = {
                guild.default_role: discord.PermissionOverwrite(view_channel=False),
                guild.me: discord.PermissionOverwrite(
                    view_channel=True, send_messages=True,
                    manage_channels=True, read_message_history=True),
            }
            if ch.get("readonly"):
                if member_role:
                    overwrites[member_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=False, read_message_history=True)
                if staff_role:
                    overwrites[staff_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=True, read_message_history=True)
            elif ch.get("access") == "customer_readonly":
                if customer_role:
                    overwrites[customer_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=False, read_message_history=True)
                if staff_role:
                    overwrites[staff_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=True, read_message_history=True)
            elif ch.get("access") in access_map:
                for role in access_map[ch["access"]]:
                    if role:
                        overwrites[role] = discord.PermissionOverwrite(
                            view_channel=True, send_messages=True,
                            read_message_history=True, attach_files=True)
            else:
                if member_role:
                    overwrites[member_role] = discord.PermissionOverwrite(
                        view_channel=True, send_messages=True, read_message_history=True)

            try:
                created_ch, note = await create_setup_channel(guild, ch, category, overwrites, f"Setup by {interaction.user}")
                log_lines.append(f"✅ #{ch_name}{note}")
                if ch_name == "prices":     prices_ch = created_ch
                if ch_name == "rules":      rules_ch  = created_ch
                if ch_name == "how-to-use": howto_ch  = created_ch
                if ch_name == "support-ticket": ticket_ch = created_ch
            except discord.HTTPException:
                log_lines.append(f"❌ #{ch_name}")

    # 3. Post embeds in the right channels
    posted = []

    if prices_ch and isinstance(prices_ch, discord.TextChannel):
        e = discord.Embed(title="Prices", color=0x82C3FF)
        e.add_field(name="\U0001f319 Specter for GS", value=price_lines(), inline=False)
        pay = [f"○ {m}" for m in PAYMENT_METHODS]
        if BUY_CONTACT:
            pay.append(f"○ Tag to buy: **{BUY_CONTACT}**")
        e.add_field(name="Payment Methods", value="\n".join(pay), inline=False)
        e.add_field(name="\U0001f319 Specter Info", value=(
            "• *Versions* — `beta` | `nightly` | `specter`\n"
            "• *Status* — fully updated for 2026\n"
            "• *Platform* — gamesense"
        ), inline=False)
        e.add_field(name="\u2728 Features", value=FEATURES_TEXT, inline=False)
        if LOGO_URL:
            e.set_image(url=LOGO_URL)
        e.set_footer(text="Specter \U0001f319 • gamesense lua")
        await prices_ch.send(embed=e)
        posted.append("#prices")

    if rules_ch and isinstance(rules_ch, discord.TextChannel):
        e = discord.Embed(title="\U0001f30d Rules", color=0x82C3FF)
        e.description = (
            "**1.** Be respectful to all members.\n"
            "**2.** No spamming or self-promotion.\n"
            "**3.** Do not share or resell license keys.\n"
            "**4.** Do not share the script or any part of it.\n"
            "**5.** Use #support-ticket for help, don't DM staff.\n"
            "**6.** No NSFW, illegal content, or doxxing.\n"
            "**7.** English / Hungarian only.\n"
            "**8.** Staff decisions are final.\n\n"
            "*Breaking any rule may result in a mute, kick, or ban.*"
        )
        e.set_footer(text="Specter \U0001f319")
        await rules_ch.send(embed=e)
        posted.append("#rules")

    if howto_ch and isinstance(howto_ch, discord.TextChannel):
        e = discord.Embed(title="\U0001f4d5 How to Use Specter", color=0x82C3FF)
        e.add_field(name="Step 1 — Get Your Key", value=(
            "Purchase a plan in #prices or from staff.\n"
            "Use `/redeem <key>` to get your role."
        ), inline=False)
        e.add_field(name="Step 2 — Register / Login", value=(
            "1. Copy your **license key** and click **Paste key** (Ctrl+V does not work in gamesense)\n"
            "2. Choose a **username** and **password**\n"
            "3. Click **Register** (first time) or **Login**\n"
            "4. Your HWID locks on first activation"
        ), inline=False)
        e.add_field(name="Tier Features", value=(
            "```\n"
            "Plan       Resolver  Ragebot+  Tuning  Builder\n"
            "specter    ✔         ✔         ✔       ✔\n"
            "nightly    ✘         ✔         ✔       ✔\n"
            "beta       ✘         ✘         ✘       ✘\n"
            "```"
        ), inline=False)
        e.set_footer(text="Specter \U0001f319")
        await howto_ch.send(embed=e)
        posted.append("#how-to-use")

    if ticket_ch and isinstance(ticket_ch, discord.TextChannel):
        e = discord.Embed(
            title="\U0001f3ab Specter Support",
            description=(
                "Need help? Click the button below to create a private support ticket.\n\n"
                "A staff member will assist you as soon as possible.\n\n"
                "**Before opening a ticket:**\n"
                "• Check #how-to-use for common questions\n"
                "• Make sure your key is valid\n"
                "• Describe your issue clearly"
            ),
            color=0x82C3FF,
        )
        e.set_footer(text="Specter \U0001f319")
        if LOGO_URL:
            e.set_thumbnail(url=LOGO_URL)
        await ticket_ch.send(embed=e, view=TicketCreateView())
        posted.append("#support-ticket")

    if posted:
        log_lines.append(f"\U0001f4e8 Embeds posted: {', '.join(posted)}")

    embed = discord.Embed(title="\U0001f319 Server Setup Complete", color=0x60FF90)
    embed.description = "\n".join(log_lines) if log_lines else "Everything already existed."
    embed.set_footer(text="Drag roles in Server Settings > Roles to set hierarchy")
    await interaction.followup.send(embed=embed, ephemeral=True)


# ── Events ────────────────────────────────────────────────────────────

_synced = False
_release_task = None


@client.event
async def on_ready():
    global _synced, _release_task
    client.add_view(TicketCreateView())
    client.add_view(TicketCloseView())
    print(f"Bot online: {client.user}  |  Guilds: {len(client.guilds)}")
    # on_ready runs again after a reconnect: the command sync (rate limited) only once per start
    if not _synced:
        _synced = True
        synced = await tree.sync()
        # which commands Discord got: a command missing here means an old build is deployed
        print(f"Slash commands ({len(synced)}): {', '.join(sorted(c.name for c in synced))}")
    print(f"API: {API_URL}")
    print(f"Default role: {DEFAULT_ROLE_NAME}")
    if RELEASE_MINUTES > 0 and (_release_task is None or _release_task.done()):
        _release_task = asyncio.create_task(release_loop())
        print(f"Version check: {', '.join(RELEASE_FILES)} -> #{RELEASE_CHANNEL}"
              + (f", {CLOUD_FILE} -> license server" if AUTO_UPLOAD else "") + f" every {RELEASE_MINUTES} min")


# ── Run ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if not DISCORD_TOKEN:
        print("ERROR: Set DISCORD_TOKEN environment variable.")
        raise SystemExit(1)
    # Too many logins from one IP (a crash loop: Railway restarts the bot within a second) and Discord's Cloudflare
    # bans the IP for a while (429, error 1015). Every new try makes the ban longer, so wait here instead of exiting
    discord.utils.setup_logging()           # once: client.run would add a log handler on every try
    wait = 300
    while True:
        try:
            client.run(DISCORD_TOKEN, log_handler=None)
            break
        except discord.HTTPException as e:
            if e.status != 429:
                raise
            print(f"Discord rate limited this IP (429 / Cloudflare 1015). Next login in {wait // 60} min.", flush=True)
            time.sleep(wait)
            wait = min(wait * 2, 3600)
            client.clear()
