// Central configuration: product names, ids, Discord server and role ids. Everything here can be overridden by env
// variables, so a rename or a new role never needs a code change.

export type ProductId = "gamesense" | "primordial";

export type ProductConfig = {
  id: ProductId;          // stable id used in the database and in the client api, never rename it
  slug: string;           // url part: /luas/<slug>
  name: string;
  platform: string;
  tagline: string;
  description: string;
  discordRoleIds: string[]; // a member with any of these roles has access to the product
};

function list(value: string | undefined): string[] {
  return (value ?? "").split(",").map((s) => s.trim()).filter(Boolean);
}

function env(name: string, fallback: string): string {
  const v = (process.env[name] ?? "").trim();
  return v || fallback;
}

export function getProducts(): ProductConfig[] {
  return [
    {
      id: "gamesense",
      slug: env("LUA1_SLUG", "gamesense"),
      name: env("LUA1_NAME", "Specter for Gamesense"),
      platform: env("LUA1_PLATFORM", "Gamesense"),
      tagline: env("LUA1_TAGLINE", "The complete Specter script for gamesense."),
      description: env("LUA1_DESCRIPTION", "Resolver, anti-aim, visuals and the config cloud, built for gamesense."),
      discordRoleIds: list(process.env.LUA1_ROLE_IDS),
    },
    {
      id: "primordial",
      slug: env("LUA2_SLUG", "primordial"),
      name: env("LUA2_NAME", "Specter for Primordial"),
      platform: env("LUA2_PLATFORM", "Primordial"),
      tagline: env("LUA2_TAGLINE", "The Specter script rebuilt for Primordial."),
      description: env("LUA2_DESCRIPTION", "Resolver, anti-aim, visuals and the config cloud, built for Primordial."),
      discordRoleIds: list(process.env.LUA2_ROLE_IDS),
    },
  ];
}

export function getProduct(idOrSlug: string): ProductConfig | undefined {
  return getProducts().find((p) => p.id === idOrSlug || p.slug === idOrSlug);
}

export const site = {
  name: "SPECTER",
  get url(): string {
    return env("PUBLIC_URL", "http://localhost:3000").replace(/\/+$/, "");
  },
  get discordInvite(): string {
    return env("DISCORD_INVITE", "");
  },
  get guildId(): string {
    return env("DISCORD_GUILD_ID", "");
  },
};

// A grant that ends within this many days is shown as "Expiring soon".
export const EXPIRING_SOON_DAYS = 7;

// Limits (backend enforced).
export const LIMITS = {
  configBytes: 256 * 1024,     // one config payload, as JSON text
  configNameLen: 48,
  configDescLen: 600,
  maxTags: 8,
  tagLen: 24,
  imageBytes: 2 * 1024 * 1024,
  maxImagesPerConfig: 4,
  uploadsPerDay: 20,           // per user
  deviceCodeTtlSec: 600,
  deviceTokenTtlDays: 90,
};
