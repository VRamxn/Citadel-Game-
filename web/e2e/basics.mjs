import { mkdirSync } from "node:fs";
import puppeteer from "puppeteer-core";

const shots = process.argv[2] ?? "e2e/shots";
mkdirSync(shots, { recursive: true });
const errors = [];
const browser = await puppeteer.launch({
  executablePath: process.env.CHROME ?? "/usr/bin/chromium",
  headless: true,
  args: ["--no-sandbox", "--window-size=1500,950"],
  defaultViewport: { width: 1500, height: 950 },
});
const page = await browser.newPage();
page.on("console", (m) => {
  if (m.type() === "error" || m.type() === "warn") errors.push(`${m.type()}: ${m.text()}`);
});
page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function clickText(text, sel = "button") {
  for (let i = 0; i < 40; i++) {
    const ok = await page.evaluate(
      (text, sel) => {
        const el = [...document.querySelectorAll(sel)].find((b) => b.textContent.trim().startsWith(text) && !b.disabled);
        if (el) el.click();
        return !!el;
      },
      text,
      sel,
    );
    if (ok) return;
    await sleep(250);
  }
  throw new Error(`no clickable "${text}"`);
}
async function waitToast(re, ms = 20000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const t = await page.evaluate(() => [...document.querySelectorAll(".toast")].map((x) => x.className + "|" + x.textContent));
    const err = t.find((x) => x.startsWith("toast err"));
    if (err) throw new Error(`toast error: ${err}`);
    if (t.some((x) => re.test(x))) return;
    await sleep(200);
  }
  throw new Error(`timeout waiting for ${re}`);
}
async function tab(name) {
  await clickText(name, ".tabs button");
  await sleep(400);
}
async function clickTile(q, r) {
  await page.evaluate((k) => document.querySelector(`[data-tile="${k}"]`).dispatchEvent(new MouseEvent("click", { bubbles: true })), `${q},${r}`);
}
async function clickCitadel(id) {
  await page.evaluate((id) => document.querySelector(`[data-citadel="${id}"]`).dispatchEvent(new MouseEvent("click", { bubbles: true })), String(id));
}
const shot = (n) => page.screenshot({ path: `${shots}/ui-${n}.png` });
const step = async (name, fn) => {
  process.stdout.write(`• ${name} … `);
  try {
    await fn();
  } catch (e) {
    await shot("FAIL");
    const toasts = await page.evaluate(() => [...document.querySelectorAll(".toast, .termout div")].map((x) => x.textContent).slice(-12));
    console.log("FAILED\n", toasts.join("\n "));
    console.log(errors.join("\n"));
    await browser.close();
    process.exit(1);
  }
  console.log("ok");
};

await page.goto("http://localhost:5173/");
await page.evaluate(() => localStorage.setItem("citadel.dev", "9"));
await page.reload();
await sleep(3000);

await step("claim starter kit", async () => {
  await tab("ASSETS");
  await clickText("Claim starter kit");
  await waitToast(/testnet faucet: done/);
});
await step("approve NFTs", async () => {
  for (const t of ["CITADEL", "PILOT", "MENTAT"]) {
    await clickText(`approve ${t}`);
    await waitToast(new RegExp(`approve ${t.toLowerCase()}: done`));
  }
});
await shot("assets");
const citadelId = await page.evaluate(() => {
  const m = document.body.innerText.match(/CITADEL (\d+) GEN0/);
  return m && Number(m[1]);
});
await step(`lite CITADEL ${citadelId} at (-2,1) for SANCTION with a PILOT`, async () => {
  await clickText("lite…");
  await page.evaluate(() => {
    const sel = document.querySelector(".form select");
    sel.value = "2";
    sel.dispatchEvent(new Event("change", { bubbles: true }));
    const cb = document.querySelector(".form input[type=checkbox]");
    cb.click();
  });
  await clickText("choose a tile");
  await sleep(300);
  await clickTile(-2, 1);
  await waitToast(/lite CITADEL .*: done/);
});
await step("select own CITADEL", async () => {
  await sleep(1500);
  await clickCitadel(citadelId);
  await sleep(1500);
});
await shot("citadel");
await step("build FLEET ACADEMY + hurry", async () => {
  await page.evaluate(() => {
    const row = [...document.querySelectorAll("table.bld tr")].find((r) => r.textContent.startsWith("FLEET ACADEMY"));
    row.querySelector("button").click();
  });
  await waitToast(/build FLEET ACADEMY L1: done/);
  await clickText("hurry");
  await waitToast(/hurry FLEET ACADEMY: done/);
});
await step("train 200 SIF + hurry", async () => {
  await page.evaluate(() => {
    const row = [...document.querySelectorAll("table.bld tr")].find((r) => r.textContent.startsWith("SIF"));
    const inp = row.querySelector("input");
    const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
    set.call(inp, "200");
    inp.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await sleep(200);
  await page.evaluate(() => {
    const row = [...document.querySelectorAll("table.bld tr")].find((r) => r.textContent.startsWith("SIF"));
    [...row.querySelectorAll("button")].find((b) => b.textContent === "train").click();
  });
  await waitToast(/train 200 SIF GATTACA: done/);
  await clickText("hurry 200");
  await waitToast(/hurry SIF GATTACA: done/);
});
await step("skip a day so the neighbour has DK", async () => {
  await clickText("+1d");
  await waitToast(/skip 1 day: done/);
});
await step("raid neighbour CITADEL 70 (adjacent, instant)", async () => {
  await clickCitadel(70);
  await sleep(1500);
  await page.evaluate(() => {
    const inp = document.querySelector(".units label input");
    const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
    set.call(inp, "150");
    inp.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await sleep(200);
  await clickText("RAID");
  await waitToast(/raid CITADEL 70: done/);
});
await shot("raid");
await step("distant raid on CITADEL 900 (travels)", async () => {
  await clickCitadel(900).catch(() => {});
  await sleep(1500);
  await page.evaluate(() => {
    const inp = document.querySelector(".units label input");
    const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
    set.call(inp, "20");
    inp.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await sleep(200);
  await clickText("RAID");
  await waitToast(/raid CITADEL 900: done/);
});
for (const t of ["WAR", "TECH", "POLITICS", "DISPATCH"]) {
  await step(`open ${t}`, async () => {
    await tab(t);
    await sleep(1500);
    await shot(t.toLowerCase());
  });
}
await step("terminal: status", async () => {
  await page.type(".termin input", `status ${citadelId}\n`);
  await sleep(1500);
});
await shot("terminal");
await browser.close();
console.log(errors.length ? `\nconsole errors:\n${errors.join("\n")}` : "\nno console errors");
