// Best-effort publisher for the RabbitMQ event bus. If the broker is down the
// service keeps working; events are simply dropped until it reconnects.
const amqp = require("amqplib");

const URL = process.env.RABBITMQ_URL;
const EXCHANGE = "edupulse.events";
let channel = null;

async function start() {
  if (!URL) return;
  for (;;) {
    try {
      const conn = await amqp.connect(URL);
      conn.on("error", () => {});
      conn.on("close", () => {
        channel = null;
        setTimeout(start, 3000);
      });
      const ch = await conn.createChannel();
      ch.on("error", () => {});
      await ch.assertExchange(EXCHANGE, "topic", { durable: true });
      channel = ch;
      console.log("Connected to RabbitMQ");
      return;
    } catch (e) {
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
}

function publish(key, payload) {
  if (!channel) return;
  try {
    const body = { type: key, at: new Date().toISOString(), ...payload };
    channel.publish(EXCHANGE, key, Buffer.from(JSON.stringify(body)), {
      persistent: true,
      contentType: "application/json",
    });
  } catch (e) {
    console.error("event publish failed:", e.message);
  }
}

module.exports = { start, publish };
