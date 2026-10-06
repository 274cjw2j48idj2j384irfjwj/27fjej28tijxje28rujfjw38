"""
Specter / Zenith — Discord License Bot
Slash commands for key management + automatic role system.
Auto-syncs keys to GitHub so the Lua loader picks them up.

ENV VARS (set in Discord bot host or .env):
  DISCORD_TOKEN       — Bot token from Discord Developer Portal
  API_URL             — License server URL (e.g. https://your-app.up.railway.app)
  ADMIN_SECRET        — Matches server.js ADMIN_SECRET
  ADMIN_ROLE_ID       — Discord role ID that can use admin commands (optional)
  DEFAULT_ROLE_NAME   — Role given to every new member (default: "Member")
  LOG_CHANNEL_ID      — Channel ID for key/role logs (optional)
  GITHUB_TOKEN        — GitHub PAT with repo write access (for key sync). Leave it EMPTY while the repo is public:
                        the sync writes every key into specter_keys.json in the repo (the loader does not need it)
  GITHUB_REPO         — GitHub repo (default: 274cjw2j48idj2j384irfjwj/27fjej28tijxje28rujfjw38)
  SCRIPT_BRANCH       — branch /script_upload takes specter_cloud.lua from (default: main)
"""

import os
import json
import base64
import asyncio
import aiohttp
import discord
from discord import app_commands

# ── Config ────────────────────────────────────────────────────────────

DISCORD_TOKEN     = os.getenv("DISCORD_TOKEN", "")
API_URL           = os.getenv("API_URL", "http://localhost:3000").rstrip("/")
ADMIN_SECRET      = os.getenv("ADMIN_SECRET", "change_this_secret_now")
ADMIN_ROLE_ID     = int(os.getenv("ADMIN_ROLE_ID", "0"))
DEFAULT_ROLE_NAME = os.getenv("DEFAULT_ROLE_NAME", "Member")
LOG_CHANNEL_ID    = int(os.getenv("LOG_CHANNEL_ID", "0"))
GITHUB_TOKEN      = os.getenv("GITHUB_TOKEN", "")
GITHUB_REPO       = os.getenv("GITHUB_REPO", "274cjw2j48idj2j384irfjwj/27fjej28tijxje28rujfjw38")
SCRIPT_BRANCH     = os.getenv("SCRIPT_BRANCH", "main")

VALID_PLANS     = ["beta", "nightly", "specter", "debug"]
VALID_DURATIONS = ["lifetime", "1d", "7d", "14d", "30d", "90d"]

ROLE_CONFIG = {
    "Member":   {"color": 0x808080, "hoist": False, "position": "bottom"},
    "Debug":    {"color": 0xFF5050, "hoist": True,  "position": "top"},
    "Specter":  {"color": 0x82C3FF, "hoist": True,  "position": "mid"},
    "Nightly":  {"color": 0xFF82A0, "hoist": True,  "position": "mid"},
    "Beta":     {"color": 0xC882FF, "hoist": True,  "position": "mid"},
    "Customer": {"color": 0x60FF90, "hoist": True,  "position": "mid"},
    "Staff":    {"color": 0xFFC850, "hoist": True,  "position": "top"},
}

PLAN_TO_ROLE = {
    "debug":    "Debug",
    "specter":  "Specter",
    "nightly":  "Nightly",
    "beta":     "Beta",
}

# ── Prices (edit these to match your pricing) ────────────────────────
SPECTER_PRICES = {
    "beta":    {"monthly": "$8",  "lifetime": "$40"},
    "nightly": {"monthly": "$15", "lifetime": "$75"},
    "specter": {"monthly": "$25", "lifetime": "$120"},
}
PAYMENT_METHODS = ["Crypto", "PayPal", "Revolut", "Other"]
LOGO_URL = os.getenv("SPECTER_LOGO_URL", "")
BUY_CONTACT = os.getenv("BUY_CONTACT", "@owner")

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


async def find_or_create_role(guild: discord.Guild, name: str) -> discord.Role | None:
    role = discord.utils.get(guild.roles, name=name)
    if role:
        return role
    cfg = ROLE_CONFIG.get(name, {"color": 0x808080, "hoist": False})
    try:
        role = await guild.create_role(
            name=name,
            color=discord.Color(cfg["color"]),
            hoist=cfg["hoist"],
            mentionable=False,
            reason=f"Auto-created by license bot",
        )
        return role
    except discord.Forbidden:
        return None


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

        staff_role = discord.utils.get(guild.roles, name="Staff")
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

    for name, cfg in ROLE_CONFIG.items():
        existing = discord.utils.get(guild.roles, name=name)
        if existing:
            existed.append(name)
            continue
        try:
            await guild.create_role(
                name=name,
                color=discord.Color(cfg["color"]),
                hoist=cfg["hoist"],
                mentionable=False,
                reason=f"Setup by {interaction.user}",
            )
            created.append(name)
        except discord.Forbidden:
            failed.append(name)

    embed = discord.Embed(title="Role Setup", color=0x60FF90)
    if created:
        embed.add_field(name="Created", value=", ".join(f"**{r}**" for r in created), inline=False)
    if existed:
        embed.add_field(name="Already exist", value=", ".join(f"**{r}**" for r in existed), inline=False)
    if failed:
        embed.add_field(name="Failed (missing perms)", value=", ".join(f"**{r}**" for r in failed), inline=False)

    desc_lines = [
        "**Role hierarchy (drag in Server Settings > Roles):**",
        "",
        "```",
        "  Staff      — admin / moderator",
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
            except discord.Forbidden:
                failed.append(f"Category: {cat_name}")
                continue

        for ch in section["channels"]:
            ch_name = ch["name"]
            ch_type = ch.get("type", "text")
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
                if ch_type == "forum":
                    await guild.create_forum(
                        name=ch_name,
                        topic=ch.get("topic", ""),
                        category=category,
                        overwrites=overwrites,
                        reason=f"Setup by {interaction.user}",
                    )
                else:
                    await guild.create_text_channel(
                        name=ch_name,
                        topic=ch.get("topic", ""),
                        category=category,
                        overwrites=overwrites,
                        reason=f"Setup by {interaction.user}",
                    )
                created.append(f"#{ch_name}")
            except discord.Forbidden:
                failed.append(f"#{ch_name}")

    embed = discord.Embed(title="\U0001f319 Channel Setup Complete", color=0x82C3FF)
    if created:
        embed.add_field(name="Created", value="\n".join(created), inline=False)
    if existed:
        embed.add_field(name="Already exist", value="\n".join(existed), inline=False)
    if failed:
        embed.add_field(name="Failed (perms)", value="\n".join(failed), inline=False)
    embed.set_footer(text="Use /setup_tickets in #support-ticket, /post_prices in #prices, /post_rules in #rules")
    await interaction.followup.send(embed=embed, ephemeral=True)


# ── /give_role — manual role assign ──────────────────────────────────

@tree.command(name="give_role", description="Give a role to a user")
@app_commands.describe(user="Target user", role_name="Role to give")
@app_commands.choices(
    role_name=[app_commands.Choice(name=r, value=r) for r in ROLE_CONFIG],
)
async def give_role(interaction: discord.Interaction, user: discord.Member, role_name: str):
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
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
    if not is_admin(interaction):
        await interaction.response.send_message("No permission.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    role = discord.utils.get(interaction.guild.roles, name=role_name)
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
                role = discord.utils.get(interaction.guild.roles, name=rname)
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
    if not is_admin(interaction):
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
    if not is_admin(interaction):
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

        line = f"`{k['key']}` | **{k['plan']}** | {status}"
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
    if not is_admin(interaction):
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


# ── /script_upload — put the cloud Lua on the license server ─────────

def strip_lua_comments(src: str) -> str:
    """Comments and blank lines out, strings and long strings kept (the same as the owners' build)."""
    import re
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
            br = branch or SCRIPT_BRANCH
            url = f"https://raw.githubusercontent.com/{GITHUB_REPO}/{br}/specter_cloud.lua"
            async with aiohttp.ClientSession() as s:
                async with s.get(url) as r:
                    if r.status != 200:
                        await interaction.followup.send(f"GitHub: {r.status} for `{url}`", ephemeral=True)
                        return
                    raw = await r.read()
            source = f"GitHub {GITHUB_REPO}@{br}"
        text = raw.decode("utf-8")
    except Exception as e:
        await interaction.followup.send(f"Could not read the script: {e}", ephemeral=True)
        return

    # only the cloud script: it has the auth gate the loader's prefix opens (the dev build has none)
    if "-- ── AUTH GATE" not in text or "_auth_ok" not in text:
        await interaction.followup.send("This is not specter_cloud.lua (no auth gate in it). Nothing uploaded.", ephemeral=True)
        return

    try:
        script = strip_lua_comments(text)
    except Exception as e:
        await interaction.followup.send(f"Could not clean the script: {e}", ephemeral=True)
        return

    plans = VALID_PLANS if plan == "all" else [plan]
    lines = []
    for p in plans:
        try:
            res = await api_post("/admin/upload_script", {"plan": p, "script": script})
            ok = res.get("ok") and res.get("status") == 200
            lines.append(f"`{p}`: " + (f"ok ({res.get('bytes', 0) // 1024} KB, {res.get('parts', 1)} parts)" if ok else f"failed {res}"))
        except Exception as e:
            lines.append(f"`{p}`: API error {e}")

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
            "3. Paste your key, pick a username & password\n"
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

    is_staff = is_admin(interaction) or discord.utils.get(interaction.user.roles, name="Staff")
    is_owner = channel.name == f"ticket-{interaction.user.name.lower().replace(' ', '-')[:20]}"
    if not is_staff and not is_owner:
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

    gs_lines = []
    for plan_name in ["beta", "nightly", "specter"]:
        p = SPECTER_PRICES.get(plan_name, {})
        gs_lines.append(f"*{plan_name} version*")
        if p.get("monthly"):
            gs_lines.append(f"○ `1 month` — {p['monthly']}")
        if p.get("lifetime"):
            gs_lines.append(f"○ `lifetime` — {p['lifetime']}")
        gs_lines.append("")

    embed.add_field(
        name="\U0001f319 Specter for GS",
        value="\n".join(gs_lines),
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
            "• *Features* — ragebot, resolver, anti-aim, builder, visuals\n"
            "• *Platform* — gamesense"
        ),
        inline=False,
    )

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
        name="Step 2 — Load the Script",
        value=(
            "1. Open **gamesense** (CS2)\n"
            "2. Go to **Lua** tab and load the **Specter Loader**\n"
            "3. Navigate to **AA > Anti-aimbot angles**"
        ),
        inline=False,
    )
    embed.add_field(
        name="Step 3 — Register / Login",
        value=(
            "1. Paste your **license key** in the key field\n"
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

    # 1. Create roles
    for name, cfg in ROLE_CONFIG.items():
        existing = discord.utils.get(guild.roles, name=name)
        if existing:
            continue
        try:
            await guild.create_role(
                name=name,
                color=discord.Color(cfg["color"]),
                hoist=cfg["hoist"],
                mentionable=False,
                reason=f"Server setup by {interaction.user}",
            )
            log_lines.append(f"✅ Role **{name}** created")
        except discord.Forbidden:
            log_lines.append(f"❌ Role **{name}** failed")

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
            except discord.Forbidden:
                log_lines.append(f"❌ Category **{cat_name}** failed")
                continue

        for ch in section["channels"]:
            ch_name = ch["name"]
            ch_type = ch.get("type", "text")
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
                if ch_type == "forum":
                    created_ch = await guild.create_forum(
                        name=ch_name, topic=ch.get("topic", ""),
                        category=category, overwrites=overwrites,
                        reason=f"Setup by {interaction.user}")
                else:
                    created_ch = await guild.create_text_channel(
                        name=ch_name, topic=ch.get("topic", ""),
                        category=category, overwrites=overwrites,
                        reason=f"Setup by {interaction.user}")
                log_lines.append(f"✅ #{ch_name}")
                if ch_name == "prices":     prices_ch = created_ch
                if ch_name == "rules":      rules_ch  = created_ch
                if ch_name == "how-to-use": howto_ch  = created_ch
                if ch_name == "support-ticket": ticket_ch = created_ch
            except discord.Forbidden:
                log_lines.append(f"❌ #{ch_name}")

    # 3. Post embeds in the right channels
    posted = []

    if prices_ch and isinstance(prices_ch, discord.TextChannel):
        gs_lines = []
        for plan_name in ["beta", "nightly", "specter"]:
            p = SPECTER_PRICES.get(plan_name, {})
            gs_lines.append(f"*{plan_name} version*")
            if p.get("monthly"):
                gs_lines.append(f"○ `1 month` — {p['monthly']}")
            if p.get("lifetime"):
                gs_lines.append(f"○ `lifetime` — {p['lifetime']}")
            gs_lines.append("")
        e = discord.Embed(title="Prices", color=0x82C3FF)
        e.add_field(name="\U0001f319 Specter for GS", value="\n".join(gs_lines), inline=False)
        pay = [f"○ {m}" for m in PAYMENT_METHODS]
        if BUY_CONTACT:
            pay.append(f"○ Tag to buy: **{BUY_CONTACT}**")
        e.add_field(name="Payment Methods", value="\n".join(pay), inline=False)
        e.add_field(name="\U0001f319 Specter Info", value=(
            "• *Versions* — `beta` | `nightly` | `specter`\n"
            "• *Status* — fully updated for 2026\n"
            "• *Platform* — gamesense"
        ), inline=False)
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
        e.add_field(name="Step 2 — Load the Script", value=(
            "1. Open **gamesense** (CS2)\n"
            "2. Go to **Lua** tab and load the **Specter Loader**\n"
            "3. Navigate to **AA > Anti-aimbot angles**"
        ), inline=False)
        e.add_field(name="Step 3 — Register / Login", value=(
            "1. Paste your **license key**\n"
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

@client.event
async def on_ready():
    client.add_view(TicketCreateView())
    client.add_view(TicketCloseView())
    await tree.sync()
    print(f"Bot online: {client.user}  |  Guilds: {len(client.guilds)}")
    print(f"API: {API_URL}")
    print(f"Default role: {DEFAULT_ROLE_NAME}")


# ── Run ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if not DISCORD_TOKEN:
        print("ERROR: Set DISCORD_TOKEN environment variable.")
        raise SystemExit(1)
    client.run(DISCORD_TOKEN)
