import { randomBytes } from "node:crypto";
import { closePool, one, pool } from "@/lib/db";
import { migrate } from "../scripts/migrate";

export async function resetDb(): Promise<void> {
  await pool().query("drop schema public cascade; create schema public;");
  await migrate();
}

export async function done(): Promise<void> {
  await closePool();
}

export async function mkUser(name = "user", opts: { admin?: boolean; createdAt?: Date } = {}): Promise<{ id: string; discord_id: string }> {
  const discord = String(BigInt("1" + randomBytes(8).readBigUInt64BE().toString().slice(0, 17)));
  const row = await one<{ id: string; discord_id: string }>(
    `insert into users (discord_id, username, global_name, is_admin, created_at) values ($1,$2,$2,$3,$4) returning id, discord_id`,
    [discord, name, !!opts.admin, opts.createdAt ?? new Date()],
  );
  return row!;
}

export const day = 86_400_000;
