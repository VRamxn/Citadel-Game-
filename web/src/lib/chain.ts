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
import { foundry, sepolia } from "viem/chains";
import gameAbi from "../abi/game";
import drakmaAbi from "../abi/drakma";
import citadelAbi from "../abi/citadel";
import pilotAbi from "../abi/pilot";
import mentatAbi from "../abi/mentat";
import techTreeAbi from "../abi/techTree";
import technocracyAbi from "../abi/technocracy";
import councilAbi from "../abi/council";
import faucetAbi from "../abi/faucet";

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
};

const files = import.meta.glob("../../../deployments/*.json", { eager: true, import: "default" }) as Record<
  string,
  Deployment
>;
export const deployments: Deployment[] = Object.values(files).filter((d) => d && d.game);

const CHAINS: Record<number, Chain> = { 31337: foundry, 11155111: sepolia };
const RPC: Record<number, string> = {
  31337: "http://127.0.0.1:8545",
  11155111: "https://ethereum-sepolia-rpc.publicnode.com",
};

export function pickDeployment(): Deployment | undefined {
  const want = Number(new URLSearchParams(location.search).get("chain"));
  return (
    deployments.find((d) => d.chainId === want) ??
    deployments.find((d) => d.chainId === 11155111) ??
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

  constructor(dep: Deployment) {
    this.dep = dep;
    this.chain = CHAINS[dep.chainId] ?? { ...foundry, id: dep.chainId };
    const url = new URLSearchParams(location.search).get("rpc") ?? RPC[dep.chainId];
    this.pub = createPublicClient({ chain: this.chain, transport: http(url, { batch: { wait: 16 } }) });
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
    this.wallet = createWalletClient({ account: addr, chain: this.chain, transport: custom(eth) });
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
