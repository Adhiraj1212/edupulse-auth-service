// Auth microservice: logins, sessions (stored in Redis) and the verify hook nginx calls.
const crypto = require("crypto");
const express = require("express");
const { createClient } = require("redis");
const events = require("./events");

const COOKIE = "edupulse_session";
const SESSION_SECONDS = 8 * 60 * 60;
const MAX_FAILS = 5;
const LOCK_SECONDS = 60;
const port = process.env.PORT || 4000;

const redis = createClient({
  url: process.env.REDIS_URL || "redis://redis:6379",
  password: process.env.REDIS_PASSWORD || undefined,
});
redis.on("error", (e) => console.error("Redis error:", e.message));

// One account per role.
const accounts = () => ({
  teacher: {
    user: process.env.ADMIN_USER || "admin",
    pass: process.env.ADMIN_PASSWORD || "administrator",
  },
  student: {
    user: process.env.STUDENT_USER || "student",
    pass: process.env.STUDENT_PASSWORD || "student123",
  },
});

const safeEqual = (a, b) => {
  const ha = crypto.createHash("sha256").update(String(a)).digest();
  const hb = crypto.createHash("sha256").update(String(b)).digest();
  return crypto.timingSafeEqual(ha, hb);
};

const cookieOpts = () => ({
  httpOnly: true,
  sameSite: "strict",
  secure: process.env.COOKIE_SECURE === "true",
  path: "/",
});

function sessionId(req) {
  const raw = (req.headers.cookie || "")
    .split(";")
    .map((c) => c.trim())
    .find((c) => c.startsWith(COOKIE + "="));
  const id = raw && raw.slice(COOKIE.length + 1);
  return /^[a-f0-9]{64}$/.test(id || "") ? id : null;
}

async function readSession(req) {
  const id = sessionId(req);
  if (!id) return null;
  const data = await redis.get(`sess:${id}`);
  return data ? JSON.parse(data) : null;
}

const app = express();
app.set("trust proxy", true); // only nginx can reach this service
app.use(express.json());

app.get("/health", (req, res) => res.json({ status: "ok" }));
app.get("/healthz", (req, res) => res.json({ status: "ok" }));

app.post("/api/login", async (req, res) => {
  const failKey = `fail:${req.ip}`;
  try {
    if (Number(await redis.get(failKey)) >= MAX_FAILS) {
      return res
        .status(429)
        .json({ message: "Too many attempts. Try again in a minute." });
    }

    const { username, password, role } = req.body || {};
    const account = accounts()[role];
    const ok =
      !!account &&
      typeof username === "string" &&
      typeof password === "string" &&
      safeEqual(username, account.user) &&
      safeEqual(password, account.pass);

    if (!ok) {
      const n = await redis.incr(failKey);
      if (n === 1) await redis.expire(failKey, LOCK_SECONDS);
      events.publish("auth.login_failed", { ip: req.ip, data: { role } });
      return res.status(401).json({ message: "Invalid username or password" });
    }

    await redis.del(failKey);
    const id = crypto.randomBytes(32).toString("hex");
    await redis.set(`sess:${id}`, JSON.stringify({ user: account.user, role }), {
      EX: SESSION_SECONDS,
    });
    res.cookie(COOKIE, id, { ...cookieOpts(), maxAge: SESSION_SECONDS * 1000 });
    events.publish("auth.login", { actor: account.user, ip: req.ip, data: { role } });
    res.json({ message: "ok", role });
  } catch (e) {
    console.error("login failed:", e.message);
    res.status(503).json({ message: "Login temporarily unavailable" });
  }
});

app.post("/api/logout", async (req, res) => {
  try {
    const id = sessionId(req);
    if (id) {
      const s = await readSession(req);
      await redis.del(`sess:${id}`);
      if (s) events.publish("auth.logout", { actor: s.user, data: { role: s.role } });
    }
  } catch (e) {
    console.error("logout failed:", e.message);
  }
  res.clearCookie(COOKIE, cookieOpts());
  res.json({ message: "ok" });
});

// Used by the landing page and navbar to know who is signed in.
app.get("/api/me", async (req, res) => {
  try {
    const s = await readSession(req);
    res.json(s ? { role: s.role, user: s.user } : { role: null });
  } catch (e) {
    res.json({ role: null });
  }
});

// nginx auth_request target: 200 + identity headers, or 401. Fails closed.
app.get("/verify", async (req, res) => {
  try {
    const s = await readSession(req);
    if (!s) return res.sendStatus(401);
    const required = req.get("X-Required-Role");
    if (required && required !== s.role) return res.sendStatus(403);
    res.set("X-Auth-Role", s.role).set("X-Auth-User", s.user).sendStatus(200);
  } catch (e) {
    res.sendStatus(401);
  }
});

events.start();
redis
  .connect()
  .then(() => app.listen(port, () => console.log(`auth-service on :${port}`)))
  .catch((e) => {
    console.error("Cannot connect to Redis:", e.message);
    process.exit(1);
  });
