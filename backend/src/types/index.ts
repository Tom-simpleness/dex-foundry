export interface Pool {
  address: string;
  tokenA: string;
  tokenB: string;
  reserveA: string;
  reserveB: string;
}

export interface Swap {
  poolAddress: string;
  sender: string;
  amountIn: string;
  amountOut: string;
  tokenIn: string;
  blockNumber: number;
  transactionHash: string;
}
