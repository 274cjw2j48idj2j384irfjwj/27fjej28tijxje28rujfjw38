"""Tests of the register / download / role sync part of discord_bot.py with fake Discord objects and a fake license server.
python3 tests/bot_register.py"""
import asyncio
import os
import sys
import types
import unittest

os.environ.setdefault("DISCORD_TOKEN", "x")
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import discord  # noqa: E402
import discord_bot as bot  # noqa: E402


class Role:
    def __init__(self, name, managed=False):
        self.name, self.managed = name, managed


class Member:
    def __init__(self, uid, roles=(), dm_ok=True):
        self.id, self.roles, self.dm_ok, self.sent = uid, [Role(r) for r in roles], dm_ok, []
        self.mention = f"<@{uid}>"

    async def add_roles(self, role, reason=None):
        self.roles.append(role)

    async def remove_roles(self, role, reason=None):
        self.roles = [r for r in self.roles if r is not role and r.name != role.name]

    async def send(self, **kw):
        if not self.dm_ok:
            raise discord.Forbidden(types.SimpleNamespace(status=403, reason="x"), "closed")
        self.sent.append(kw)


class Guild:
    def __init__(self, members=()):
        self.members = {m.id: m for m in members}
        self.name = "g"
        self.roles = []
        self.owner_id = 0

    def get_member(self, uid):
        return self.members.get(uid)


class Followup:
    def __init__(self):
        self.messages = []

    async def send(self, content=None, **kw):
        self.messages.append({"content": content, **kw})


class Response:
    async def defer(self, **kw):
        pass


def interaction(user, guild):
    return types.SimpleNamespace(user=user, guild=guild, followup=Followup(), response=Response())


def run(coro):
    return asyncio.get_event_loop_policy().new_event_loop().run_until_complete(coro)


def text(it):
    m = it.followup.messages[-1]
    emb = m.get("embed")
    return (m.get("content") or "") + (" " + " ".join(str(f.value) for f in emb.fields) + (emb.title or "") if emb else "")


class Pure(unittest.TestCase):
    def test_lua_and_activity(self):
        self.assertEqual(bot.lua_of_plan("pm_nightly"), "primordial")
        self.assertEqual(bot.lua_of_plan("specter"), "gamesense")
        self.assertTrue(bot.license_active({"revoked": False, "expired": False}))
        self.assertFalse(bot.license_active({"revoked": True}))
        self.assertFalse(bot.license_active({"expired": True}))

    def test_desired_roles(self):
        self.assertEqual(bot.desired_roles([]), set())
        self.assertEqual(bot.desired_roles([{"plan": "specter", "expired": True}]), set())
        self.assertEqual(bot.desired_roles([{"plan": "specter"}]), {"Customer", "Specter"})
        self.assertEqual(bot.desired_roles([{"plan": "pm_nightly"}, {"plan": "nightly"}]), {"Customer", "Primordial", "Nightly"})
        self.assertEqual(bot.desired_roles([{"plan": "pm_dev", "revoked": True}, {"plan": "beta"}]), {"Customer", "Beta"})


class Roles(unittest.TestCase):
    def setUp(self):
        self.created = []

        async def find_or_create_role(guild, name):
            self.created.append(name)
            return Role(name)

        self.orig = (bot.find_or_create_role, bot.guild_role)
        bot.find_or_create_role = find_or_create_role
        bot.guild_role = lambda guild, name: Role(name)

    def tearDown(self):
        bot.find_or_create_role, bot.guild_role = self.orig

    def test_gives_roles_of_running_keys_and_takes_ended_ones_away(self):
        m = Member(1, roles=["Staff", "Beta", "Customer"])
        added, removed = run(bot.sync_member_roles(Guild([m]), m, [{"plan": "pm_nightly"}, {"plan": "beta", "expired": True}], "t"))
        self.assertEqual(added, ["Primordial"])
        self.assertEqual(removed, ["Beta"])
        self.assertEqual(sorted(r.name for r in m.roles), ["Customer", "Primordial", "Staff"])   # Staff is never touched

    def test_all_keys_ended_removes_every_managed_role(self):
        m = Member(1, roles=["Specter", "Customer", "Member"])
        added, removed = run(bot.sync_member_roles(Guild([m]), m, [{"plan": "specter", "revoked": True}], "t"))
        self.assertEqual(sorted(r.name for r in m.roles), ["Member"])
        self.assertEqual(added, [])


class Register(unittest.TestCase):
    def setUp(self):
        self.bound = {}
        self.calls = []

        async def api_post(path, data):
            self.calls.append((path, data))
            if data["key"] == "GOOD":
                owner = self.bound.setdefault("GOOD", data["discord_id"])
                if owner != data["discord_id"]:
                    return {"status": 409, "ok": False, "reason": "bound_to_other"}
                return {"status": 200, "ok": True, "already": False, "plan": "specter", "lua": "gamesense", "expires_at": None}
            return {"status": 404, "ok": False, "reason": "invalid_key"}

        async def licenses_of(uid):
            return [{"key": "GOOD", "plan": "specter", "lua": "gamesense"}] if self.bound.get("GOOD") == str(uid) else []

        async def sync(guild, member, licenses, reason):
            return (["Specter"], [])

        async def log_action(guild, embed):
            pass

        self.orig = (bot.api_post, bot.licenses_of, bot.sync_member_roles, bot.log_action)
        bot.api_post, bot.licenses_of, bot.sync_member_roles, bot.log_action = api_post, licenses_of, sync, log_action

    def tearDown(self):
        bot.api_post, bot.licenses_of, bot.sync_member_roles, bot.log_action = self.orig

    def test_first_account_registers_second_is_refused(self):
        g = Guild()
        a, b = Member(111111111111111111), Member(222222222222222222)
        ia = interaction(a, g)
        run(bot.register.callback(ia, "GOOD"))
        self.assertIn("Key registered", text(ia))
        self.assertIn("Specter", text(ia))
        ib = interaction(b, g)
        run(bot.register.callback(ib, "GOOD"))
        self.assertIn("another Discord account", text(ib))
        self.assertTrue(ib.followup.messages[-1]["ephemeral"])

    def test_bad_key_and_the_key_is_sent_to_the_server_trimmed(self):
        it = interaction(Member(111111111111111111), Guild())
        run(bot.register.callback(it, "  `NOPE`  "))
        self.assertIn("does not exist", text(it))
        self.assertEqual(self.calls[-1][1]["key"], "NOPE")

    def test_registering_for_somebody_else_is_staff_only(self):
        g = Guild()
        user, other = Member(111111111111111111), Member(222222222222222222)
        orig = bot.is_staff
        bot.is_staff = lambda i: False
        try:
            it = interaction(user, g)
            run(bot.register.callback(it, "GOOD", other))
            self.assertIn("Only staff", text(it))
            self.assertEqual(self.calls, [])
            bot.is_staff = lambda i: True
            it2 = interaction(user, g)
            run(bot.register.callback(it2, "GOOD", other))
            self.assertEqual(self.calls[-1][1]["discord_id"], "222222222222222222")
        finally:
            bot.is_staff = orig

    def test_server_down_is_not_reported_as_a_bad_key(self):
        async def down(path, data):
            raise bot.aiohttp.ClientError("down")
        bot.api_post = down
        it = interaction(Member(111111111111111111), Guild())
        run(bot.register.callback(it, "GOOD"))
        self.assertIn("can not be reached", text(it))


class Download(unittest.TestCase):
    def setUp(self):
        self.lic = []

        async def licenses_of(uid):
            return self.lic

        async def loader_bytes(lua):
            return f"-- {lua} loader".encode()

        self.orig = (bot.licenses_of, bot.loader_bytes)
        bot.licenses_of, bot.loader_bytes = licenses_of, loader_bytes

    def tearDown(self):
        bot.licenses_of, bot.loader_bytes = self.orig

    def test_no_running_key_gets_no_loader(self):
        self.lic = [{"key": "A", "plan": "specter", "expired": True}, {"key": "B", "plan": "beta", "revoked": True}]
        m = Member(111111111111111111)
        it = interaction(m, Guild())
        run(bot.download.callback(it))
        self.assertEqual(m.sent, [])
        self.assertIn("no running key", text(it))
        self.assertTrue(all("file" not in x for x in it.followup.messages))
        self.assertTrue(it.followup.messages[-1]["ephemeral"])

    def test_no_account_at_all_gets_no_loader(self):
        self.lic = []
        it = interaction(Member(111111111111111111), Guild())
        run(bot.download.callback(it))
        self.assertIn("/register", text(it))
        self.assertTrue(all("file" not in x for x in it.followup.messages))

    def test_the_loader_comes_in_the_channel_visible_only_to_the_member(self):
        self.lic = [{"key": "A", "plan": "specter"}, {"key": "B", "plan": "pm_nightly"}]
        m = Member(111111111111111111)
        it = interaction(m, Guild())
        run(bot.download.callback(it))
        sent = [x for x in it.followup.messages if "file" in x]
        self.assertEqual(sorted(x["file"].filename for x in sent), ["specter_loader.lua", "specter_primordial_loader.lua"])
        self.assertTrue(all(x["ephemeral"] for x in sent))
        self.assertEqual(m.sent, [])                     # nothing goes to a DM any more

    def test_only_the_unlocked_lua(self):
        self.lic = [{"key": "A", "plan": "pm_beta"}]
        it = interaction(Member(111111111111111111), Guild())
        run(bot.download.callback(it))
        self.assertEqual([x["file"].filename for x in it.followup.messages if "file" in x], ["specter_primordial_loader.lua"])

    def test_choosing_one_lua_sends_only_that_loader(self):
        self.lic = [{"key": "A", "plan": "specter"}, {"key": "B", "plan": "pm_nightly"}]
        it = interaction(Member(111111111111111111), Guild())
        run(bot.download.callback(it, discord.app_commands.Choice(name="Primordial", value="primordial")))
        self.assertEqual([x["file"].filename for x in it.followup.messages if "file" in x], ["specter_primordial_loader.lua"])

    def test_choosing_a_lua_the_keys_do_not_unlock_sends_nothing(self):
        self.lic = [{"key": "A", "plan": "specter"}]
        it = interaction(Member(111111111111111111), Guild())
        run(bot.download.callback(it, discord.app_commands.Choice(name="Primordial", value="primordial")))
        self.assertTrue(all("file" not in x for x in it.followup.messages))
        self.assertIn("do not unlock", text(it))

    def test_license_server_down_says_so(self):
        async def none(uid):
            return None
        bot.licenses_of = none
        it = interaction(Member(111111111111111111), Guild())
        run(bot.download.callback(it))
        self.assertIn("can not be reached", text(it))

    def test_the_command_works_in_a_server_only(self):
        self.assertTrue(bot.download.guild_only)


class Ban(unittest.TestCase):
    def setUp(self):
        self.me = types.SimpleNamespace(id=1, top_role=5)
        self.guild = types.SimpleNamespace(owner_id=99, get_member=lambda uid: {2: types.SimpleNamespace(id=2, top_role=5), 3: types.SimpleNamespace(id=3, top_role=1)}.get(uid))
        bot.client._connection.user = types.SimpleNamespace(id=777)

    def test_the_rules(self):
        t = lambda uid: types.SimpleNamespace(id=uid)
        self.assertIn("yourself", bot.ban_problem(self.guild, self.me, t(1)))
        self.assertIn("myself", bot.ban_problem(self.guild, self.me, t(777)))
        self.assertIn("owner", bot.ban_problem(self.guild, self.me, t(99)))
        self.assertIn("higher role", bot.ban_problem(self.guild, self.me, t(2)))      # same role = not allowed
        self.assertEqual(bot.ban_problem(self.guild, self.me, t(3)), "")              # a lower member
        self.assertEqual(bot.ban_problem(self.guild, self.me, t(555)), "")            # not in the server: a plain user id

    def test_the_commands_are_staff_only(self):
        for cmd in (bot.ban, bot.unban):
            it = types.SimpleNamespace(user=Member(5), guild=Guild(), followup=Followup(), response=types.SimpleNamespace())
            sent = []

            async def send_message(content=None, **kw):
                sent.append(content)
            it.response.send_message = send_message
            orig = bot.is_staff
            bot.is_staff = lambda i: False
            try:
                if cmd is bot.ban:
                    run(cmd.callback(it, types.SimpleNamespace(id=9, mention="<@9>")))
                else:
                    run(cmd.callback(it, "123"))
            finally:
                bot.is_staff = orig
            self.assertEqual(sent, ["No permission."])


class RoleLoop(unittest.TestCase):
    def test_sync_roles_only_touches_members_with_a_bound_key(self):
        keys = [
            {"key": "A", "plan": "specter", "discord_id": "111111111111111111", "expired": True},
            {"key": "B", "plan": "pm_nightly", "discord_id": "222222222222222222"},
            {"key": "C", "plan": "beta"},                                  # not registered: nobody's roles
        ]

        async def api_get(path):
            return keys

        seen = []

        async def sync(guild, member, licenses, reason):
            seen.append((member.id, [l["key"] for l in licenses]))
            return (["x"], [])

        orig = (bot.api_get, bot.sync_member_roles, bot.client)
        m1, m2, m3 = Member(111111111111111111), Member(222222222222222222), Member(333333333333333333)
        bot.api_get, bot.sync_member_roles = api_get, sync
        bot.client = types.SimpleNamespace(guilds=[Guild([m1, m2, m3])])
        try:
            report = run(bot.sync_roles())
        finally:
            bot.api_get, bot.sync_member_roles, bot.client = orig
        self.assertEqual(sorted(seen), [(111111111111111111, ["A"]), (222222222222222222, ["B"])])
        self.assertEqual(len(report), 2)


class Panels(unittest.TestCase):
    def test_how_to_describes_the_new_flow(self):
        t = " ".join(f.value for f in bot.howto_embed().fields)
        for needle in ("/register", "/download", "Invoice ID", "only you can see it"):
            self.assertIn(needle, t)

    def test_loader_posts_are_off_by_default(self):
        self.assertFalse(bot.LOADER_POSTS)


if __name__ == "__main__":
    unittest.main(verbosity=1)
