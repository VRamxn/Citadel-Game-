# End-to-end playtests

Drive the real client in headless Chromium against a fresh local world, as dev account #9.

```sh
anvil &
forge script script/DevDeploy.s.sol --rpc-url local --broadcast   # fresh world each run
npm run dev &                                                     # http://localhost:5173
npm run e2e:basics    # faucet, approvals, lite, build, train, instant + travelling raids, every panel
npm run e2e:war       # PILOT claim, PILOT-led siege to capture, colonize, sovereign seat, bribe
```

Each script needs a fresh chain (they claim the faucet as account #9). Screenshots land in `e2e/shots/`.
Set `CHROME=/path/to/chrome` if Chromium isn't at `/usr/bin/chromium`.
