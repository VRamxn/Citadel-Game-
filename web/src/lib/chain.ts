import {
  createPublicClient,
  createWalletClient,
  custom,
  http,
  type Account,
  type Address,
  type Chain,
  type PublicClient,
  type WalletClient,
  BaseError,
  ContractFunctionRevertedError,
} from "viem";
import { mnemonicToAccount } from "viem/accounts";
import { base, baseSepolia, foundry, mainnet, sepolia } from "viem/chains";
import gameAbi from "../abi/game";
import drakmaAbi from "../abi/drakma";
import citadelAbi from "../abi/citadel";
import pilotAbi from "../abi/pilot";
import mentatAbi from "../abi/mentat";
import techTreeAbi from "../abi/techTree";
import technocracyAbi from "../abi/technocracy";
import councilAbi from "../abi/council";
import faucetAbi from "../abi/faucet";
import bridgeAbi from "../abi/bridge";
import claimAbi from "../abi/claim";
import vaultAbi from "../abi/vault";
import claimRelayAbi from "../abi/claimRelay";
import originalsFaucetAbi from "../abi/originalsFaucet";

export const abis = {
  game: gameAbi,
  drakma: drakmaAbi,
  citadel: citadelAbi,
  pilot: pilotAbi,
  mentat: mentatAbi,
  techTree: techTreeAbi,
  technocracy: technocracyAbi,
  council: councilAbi,
  faucet: faucetAbi,
  bridge: bridgeAbi,
  claim: claimAbi,
};
/** Contracts on the L1 side of the bridge (Ethereum / Sepolia; the same local chain in dev). */
export const l1Abis = {
  vault: vaultAbi,
  claimRelay: claimRelayAbi,
  citadelOriginal: citadelAbi, // ERC721 functions only
  pilotOriginal: citadelAbi,
  originalsFaucet: originalsFaucetAbi,
};
export type L1Name = keyof typeof l1Abis;
export type L1Deployment = {
  chainId: number;
  vault: Address;
  claimRelay?: Address;
  citadelOriginal: Address;
  pilotOriginal: Address;
  originalsFaucet?: Address;
};
export type ContractName = keyof typeof abis;

export type Deployment = {
  chainId: number;
  block: number;
  game: Address;
  drakma: Address;
  citadel: Address;
  pilot: Address;
  mentat: Address;
  techTree: Address;
  technocracy: Address;
  council: Address;
  faucet: Address;
  bridge: Address;
  claim: Address;
  // local dev only: the L1 side lives in the same file
  vault?: Address;
  claimRelay?: Address;
  citadelOriginal?: Address;
  pilotOriginal?: Address;
  originalsFaucet?: Address;
};

const files = import.meta.glob("../../../deployments/*.json", { eager: true, import: "default" }) as Record<
  string,
  Deployment
>;
export const deployments: Deployment[] = Object.values(files).filter((d) => d && (d as any).game);
const l1Deployments: L1Deployment[] = Object.values(files).filter((d) => d && (d as any).vault && !(d as any).game) as any;

const CHAINS: Record<number, Chain> = { 31337: foundry, 11155111: sepolia, 1: mainnet, 84532: baseSepolia, 8453: base };
/** The L1 each L2 settles to. */
const L1_OF: Record<number, number> = { 84532: 11155111, 8453: 1, 31337: 31337 };
const RPC: Record<number, string> = {
  31337: "http://127.0.0.1:8545",
  11155111: "https://ethereum-sepolia-rpc.publicnode.com",
  1: "https://ethereum-rpc.publicnode.com",
  84532: "https://sepolia.base.org",
  8453: "https://mainnet.base.org",
};

export function pickDeployment(): Deployment | undefined {
  const want = Number(new URLSearchParams(location.search).get("chain"));
  return (
    deployments.find((d) => d.chainId === want) ??
    deployments.find((d) => d.chainId === 8453) ??
    deployments.find((d) => d.chainId === 84532) ??
    deployments.find((d) => d.chainId === 31337)
  );
}

export const DEV_MNEMONIC = "test test test test test test test test test test test junk";
export const devAccounts = Array.from({ length: 10 }, (_, i) => mnemonicToAccount(DEV_MNEMONIC, { addressIndex: i }));

export class Chain_ {
  dep: Deployment;
  chain: Chain;
  pub: PublicClient;
  wallet?: WalletClient;
  account?: Account | Address;
  /** The other side of the bridge, where the original CITADEL and PILOT live. */
  l1?: { dep: L1Deployment; chain: Chain; pub: PublicClient };
  private injected = false;

  constructor(dep: Deployment) {
    this.dep = dep;
    this.chain = CHAINS[dep.chainId] ?? { ...foundry, id: dep.chainId };
    const url = new URLSearchParams(location.search).get("rpc") ?? RPC[dep.chainId];
    this.pub = createPublicClient({ chain: this.chain, transport: http(url, { batch: { wait: 16 } }) });
    const l1Id = L1_OF[dep.chainId];
    const l1Dep: L1Deployment | undefined =
      dep.chainId === 31337 && dep.vault
        ? (dep as any)
        : l1Deployments.find((x) => x.chainId === l1Id);
    if (l1Dep) {
      const l1Chain = CHAINS[l1Dep.chainId] ?? this.chain;
      const l1Pub = l1Dep.chainId === dep.chainId ? this.pub : createPublicClient({ chain: l1Chain, transport: http(RPC[l1Dep.chainId], { batch: { wait: 16 } }) });
      this.l1 = { dep: { ...l1Dep, chainId: l1Dep.chainId ?? l1Id }, chain: l1Chain, pub: l1Pub };
    }
  }

  get l1Name() {
    return this.l1 ? (this.l1.dep.chainId === this.dep.chainId ? "local L1" : this.l1.chain.name) : "";
  }

  get isDev() {
    return this.dep.chainId === 31337;
  }

  get address(): Address | undefined {
    if (!this.account) return undefined;
    return typeof this.account === "string" ? this.account : this.account.address;
  }

  useDevAccount(i: number) {
    this.account = devAccounts[i];
    const url = RPC[31337];
    this.wallet = createWalletClient({ account: this.account, chain: this.chain, transport: http(url) });
  }

  async connectInjected() {
    const eth = (window as any).ethereum;
    if (!eth) throw new Error("No browser wallet found. Install MetaMask or another injected wallet.");
    const [addr] = (await eth.request({ method: "eth_requestAccounts" })) as Address[];
    const hex = `0x${this.chain.id.toString(16)}`;
    try {
      await eth.request({ method: "wallet_switchEthereumChain", params: [{ chainId: hex }] });
    } catch {
      /* the wallet will reject the tx on the wrong chain; let the user switch */
    }
    this.account = addr;
    this.injected = true;
    this.wallet = createWalletClient({ account: addr, chain: this.chain, transport: custom(eth) });
  }

  private async switchTo(chain: Chain) {
    if (!this.injected) return;
    const eth = (window as any).ethereum;
    await eth.request({ method: "wallet_switchEthereumChain", params: [{ chainId: `0x${chain.id.toString(16)}` }] });
  }

  readL1<T = any>(c: L1Name, functionName: string, args: unknown[] = []): Promise<T> {
    if (!this.l1) throw new Error("No L1 deployment for this network.");
    const address = this.l1.dep[c] as Address;
    return this.l1.pub.readContract({ address, abi: l1Abis[c] as any, functionName, args }) as Promise<T>;
  }

  /** A transaction on the L1 side of the bridge (the wallet is switched there and back). */
  async writeL1(c: L1Name, functionName: string, args: unknown[] = []) {
    if (!this.l1) throw new Error("No L1 deployment for this network.");
    if (!this.wallet || !this.account) throw new Error("Connect a wallet first.");
    const l1 = this.l1;
    const sameChain = l1.dep.chainId === this.dep.chainId;
    const eth = (window as any).ethereum;
    const wallet = sameChain
      ? this.wallet
      : this.injected
        ? createWalletClient({ account: this.account as Address, chain: l1.chain, transport: custom(eth) })
        : createWalletClient({ account: this.account, chain: l1.chain, transport: http(RPC[l1.dep.chainId]) });
    if (!sameChain) await this.switchTo(l1.chain);
    try {
      const call = { address: l1.dep[c] as Address, abi: l1Abis[c] as any, functionName, args, account: this.account };
      const { request } = await l1.pub.simulateContract(call);
      const hash = await wallet.writeContract(request as any);
      const receipt = await l1.pub.waitForTransactionReceipt({ hash });
      if (receipt.status !== "success") throw new Error(`Transaction reverted: ${hash}`);
      return receipt;
    } finally {
      if (!sameChain) await this.switchTo(this.chain).catch(() => {});
    }
  }

  read<T = any>(c: ContractName, functionName: string, args: unknown[] = []): Promise<T> {
    return this.pub.readContract({ address: this.dep[c], abi: abis[c] as any, functionName, args }) as Promise<T>;
  }

  async write(c: ContractName, functionName: string, args: unknown[] = []) {
    if (!this.wallet || !this.account) throw new Error("Connect a wallet first.");
    const call = { address: this.dep[c], abi: abis[c] as any, functionName, args, account: this.account };
    const { request } = await this.pub.simulateContract(call);
    // Some actions roll traits from block randomness, so their gas varies between estimate and execution: pad it.
    const gas = ((await this.pub.estimateContractGas(call)) * 13n) / 10n;
    const hash = await this.wallet.writeContract({ ...(request as any), gas });
    const receipt = await this.pub.waitForTransactionReceipt({ hash });
    if (receipt.status !== "success") throw new Error(`Transaction reverted: ${hash}`);
    return receipt;
  }

  /** Local chain only: move time forward. */
  async skip(seconds: number) {
    await this.pub.request({ method: "evm_increaseTime" as any, params: [seconds] as any });
    await this.pub.request({ method: "evm_mine" as any, params: [] as any });
  }
}

export function explainError(e: unknown): string {
  if (e instanceof BaseError) {
    const revert = e.walk((x) => x instanceof ContractFunctionRevertedError) as ContractFunctionRevertedError | null;
    if (revert?.data?.errorName) {
      const args = revert.data.args?.length ? `(${revert.data.args.map(String).join(", ")})` : "";
      return `${revert.data.errorName}${args}`;
    }
    return e.shortMessage;
  }
  return e instanceof Error ? e.message : String(e);
}
