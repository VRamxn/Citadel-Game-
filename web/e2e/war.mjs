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
  if (m.type() === "error") errors.push(`${m.type()}: ${m.text()}`);
});
page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const clickTile = (q, r) => page.evaluate((q, r) => window.__citadelMap.click(q, r), q, r);
const clickCitadel = (id) => page.evaluate((id) => window.__citadelMap.clickCitadel(String(id)), String(id));
const shot = (n) => page.screenshot({ path: `${shots}/ui2-${n}.png` });

async function clickText(text, sel = "button") {
  for (let i = 0; i < 60; i++) {
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
async function waitToast(re, ms = 30000) {
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
  await sleep(500);
}
async function setInput(selector, index, value) {
  await page.evaluate(
    (selector, index, value) => {
      const inp = document.querySelectorAll(selector)[index];
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(inp, value);
      inp.dispatchEvent(new Event("input", { bubbles: true }));
    },
    selector,
    index,
    value,
  );
  await sleep(150);
}
async function selectValue(selector, index, value) {
  await page.evaluate(
    (selector, index, value) => {
      const s = document.querySelectorAll(selector)[index];
      Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, "value").set.call(s, value);
      s.dispatchEvent(new Event("change", { bubbles: true }));
    },
    selector,
    index,
    value,
  );
  await sleep(150);
}
const step = async (name, fn) => {
  process.stdout.write(`• ${name} … `);
  try {
    await fn();
  } catch (e) {
    await shot("FAIL");
    const log = await page.evaluate(() => [...document.querySelectorAll(".termout div")].map((x) => x.textContent).slice(-10));
    console.log(`FAILED: ${e.message}\n  ${log.join("\n  ")}\n${errors.join("\n")}`);
    await browser.close();
    process.exit(1);
  }
  console.log("ok");
};
const text = () => page.evaluate(() => document.body.innerText);

await page.goto("http://localhost:5173/");
await page.evaluate(() => localStorage.setItem("citadel.dev", "9"));
await page.reload();
await sleep(3000);

await step("get stand-in originals, bridge them over, take testnet DRAKMA", async () => {
  await tab("BRIDGE");
  await clickText("testnet: get 2 CITADEL + 2 PILOT");
  await waitToast(/testnet originals: done/);
  await clickText("find my originals");
  for (let i = 0; i < 120 && !(await page.evaluate(() => document.querySelectorAll(".item .chk input").length)); i++) await sleep(250);
  await page.evaluate(() => document.querySelectorAll(".item .chk input").forEach((c) => c.click()));
  await clickText("bridge 4 to");
  await waitToast(/bridge 4 to .*: done/, 60000);
  await tab("ASSETS");
  await clickText("Testnet: take 5M DRAKMA");
  await waitToast(/testnet DRAKMA faucet: done/);
});
let mine;
await step("approvals", async () => {
  for (const t of ["CITADEL", "PILOT", "MENTAT"]) {
    await clickText(`approve ${t}`);
    await waitToast(new RegExp(`approve ${t.toLowerCase()}: done`));
  }
  for (let i = 0; i < 40 && !mine; i++) {
    const m = (await text()).match(/CITADEL (\d+) GEN0/);
    if (m) mine = Number(m[1]);
    else await sleep(250);
  }
});
await step(`lite CITADEL ${mine} at (-2,1) for SANCTION, no PILOT`, async () => {
  await clickText("lite…");
  await selectValue(".form select", 0, "2");
  await clickText("choose a tile");
  await sleep(300);
  await clickTile(-2, 1);
  await waitToast(/lite CITADEL .*: done/);
  await sleep(1200);
});
await step("academy, 3000 SIF (hurried)", async () => {
  await clickCitadel(mine);
  await sleep(1500);
  await page.evaluate(() => [...document.querySelectorAll("table.bld tr")].find((r) => r.textContent.startsWith("FLEET ACADEMY")).querySelector("button").click());
  await waitToast(/build FLEET ACADEMY L1: done/);
  await clickText("hurry");
  await waitToast(/hurry FLEET ACADEMY: done/);
  await setInput("table.bld input", 0, "3000");
  await page.evaluate(() => [...[...document.querySelectorAll("table.bld tr")].find((r) => r.textContent.startsWith("SIF")).querySelectorAll("button")].find((b) => b.textContent === "train").click());
  await waitToast(/train 3000 SIF GATTACA: done/);
  await clickText("hurry 3000");
  await waitToast(/hurry SIF GATTACA: done/);
});
await step("lay siege to CITADEL 70 with 3000 SIF and a PILOT", async () => {
  await clickCitadel(70);
  await sleep(1500);
  await setInput(".units label input", 0, "3000");
  const pilots = await page.evaluate(() => [...document.querySelectorAll("select option")].map((o) => o.value + "|" + o.textContent).filter((x) => x.includes("PILOT #")));
  await selectValue(".row.wrap select", 1, pilots[0].split("|")[0]);
  await clickText("LAY SIEGE");
  await waitToast(/SIEGE CITADEL 70: done/);
});
await shot("siege-start");
await step("48h later, fight the siege to the end from the WAR tab", async () => {
  await tab("WAR");
  for (let i = 0; i < 6; i++) {
    await clickText("+1d");
    await waitToast(/skip 1 day: done/);
    await sleep(800);
    while (true) {
      const t = await text();
      if (!/fight \d+ due wave/.test(t)) break;
      await clickText("fight");
      await waitToast(/advance siege .*: done/);
      await sleep(800);
    }
    if (/No active sieges/.test(await text())) break;
  }
  if (!/No active sieges/.test(await text())) throw new Error("siege still active");
});
await step("the captured tile now holds our GEN1 CITADEL", async () => {
  await tab("DISPATCH");
  await sleep(500);
  const t = await text();
  if (!/SUCCEEDED/.test(t)) throw new Error("no success in dispatch");
  await clickTile(-3, 1);
  await sleep(1500);
  const p = await text();
  if (!/GEN1/.test(p) || !/yours/.test(p)) throw new Error("tile not ours");
});
await shot("captured");
await step("colonize (-1,1) with the other bridged PILOT", async () => {
  await tab("ASSETS");
  await selectValue(".item .row.wrap select", 0, "2");
  await clickText("colonize…");
  await sleep(300);
  await clickTile(-1, 1);
  await waitToast(/colonize \(-1, 1\) with PILOT .*: done/);
});
await step("buy a sovereign seat with a PILOT", async () => {
  await tab("POLITICS");
  await sleep(2500);
  await clickText("buy a seat");
  await waitToast(/seat PILOT .*: done/);
  await sleep(1500);
  if (!/1\/128 seats|[1-9]\d*\/128 seats/.test(await text())) throw new Error("no seat");
});
await shot("politics");
await step("bribe a KULT", async () => {
  await clickText("bribe (100k DK)");
  await waitToast(/bribe .*: done/);
});
await tab("TECH");
await sleep(1500);
await shot("tech");
await browser.close();
console.log(errors.length ? `\nconsole errors:\n${errors.join("\n")}` : "\nno console errors");
