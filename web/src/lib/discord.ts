import type { MemberLookup } from "./access";
import { site } from "@/config/site";

const API = "https://discord.com/api/v10";

function required(name: string): string {
  const v = (process.env[name] ?? "").trim();
  if (!v) throw new Error(`${name} is not set`);
  return v;
}

export function discordConfigured(): boolean {
  return ["DISCORD_CLIENT_ID", "DISCORD_CLIENT_SECRET", "DISCORD_BOT_TOKEN", "DISCORD_GUILD_ID"].every((n) => (process.env[n] ?? "").trim());
}

export function redirectUri(): string {
  return `${site.url}/api/auth/callback`;
}

export function authorizeUrl(state: string): string {
  const p = new URLSearchParams({
    client_id: required("DISCORD_CLIENT_ID"),
    redirect_uri: redirectUri(),
    response_type: "code",
    scope: "identify",
    state,
    prompt: "none",
  });
  return `https://discord.com/oauth2/authorize?${p}`;
}

async function call(url: string, init: RequestInit = {}): Promise<Response> {
  return fetch(url, { ...init, signal: AbortSignal.timeout(6000), cache: "no-store" });
}

export type DiscordUser = { id: string; username: string; global_name: string | null; avatar: string | null };

export async function exchangeCode(code: string): Promise<string> {
  const res = await call(`${API}/oauth2/token`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: required("DISCORD_CLIENT_ID"),
      client_secret: required("DISCORD_CLIENT_SECRET"),
      grant_type: "authorization_code",
      code,
      redirect_uri: redirectUri(),
    }),
  });
  if (!res.ok) throw new Error(`discord token exchange failed (${res.status})`);
  const json = (await res.json()) as { access_token?: string };
  if (!json.access_token) throw new Error("discord token exchange returned no token");
  return json.access_token;
}

export async function fetchUser(accessToken: string): Promise<DiscordUser> {
  const res = await call(`${API}/users/@me`, { headers: { authorization: `Bearer ${accessToken}` } });
  if (!res.ok) throw new Error(`discord user lookup failed (${res.status})`);
  return (await res.json()) as DiscordUser;
}

// Roles of a member of the Specter server, asked with the bot token. 404 = not a member (a real answer);
// any other failure throws, so the caller can tell "Discord is down" from "no access".
export async function fetchMember(discordId: string): Promise<MemberLookup> {
  const res = await call(`${API}/guilds/${required("DISCORD_GUILD_ID")}/members/${discordId}`, { headers: { authorization: `Bot ${required("DISCORD_BOT_TOKEN")}` } });
  if (res.status === 404) return { inGuild: false, roles: [] };
  if (!res.ok) throw new Error(`discord member lookup failed (${res.status})`);
  const json = (await res.json()) as { roles?: string[] };
  return { inGuild: true, roles: json.roles ?? [] };
}

export function avatarUrl(discordId: string, avatar: string | null, size = 128): string {
  if (avatar) return `https://cdn.discordapp.com/avatars/${discordId}/${avatar}.${avatar.startsWith("a_") ? "gif" : "png"}?size=${size}`;
  const idx = Number((BigInt(discordId) >> BigInt(22)) % BigInt(6));
  return `https://cdn.discordapp.com/embed/avatars/${idx}.png`;
}
