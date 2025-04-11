"use client";

import Link from "next/link";
import type { NextPage } from "next";
import { useState } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { BugAntIcon, MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { Address } from "~~/components/scaffold-eth";
import { contracts } from "~~/utils/scaffold-eth/contract"; // Import deployed contract data
import { parseEther } from "viem";

// Get TokenFactory config, using 'as any' to bypass stricter index signature types
const tokenFactoryConfig = (contracts as any)?.["TokenFactory"];

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [isLoading, setIsLoading] = useState(false);
  const [txHashA, setTxHashA] = useState<`0x${string}` | undefined>();
  const [txHashB, setTxHashB] = useState<`0x${string}` | undefined>();

  // --- Wagmi Hooks for Writing --- 
  const { data: hashA, writeContractAsync: createTokenA, error: errorA } = useWriteContract();
  const { data: hashB, writeContractAsync: createTokenB, error: errorB } = useWriteContract();

  // --- Wagmi Hooks for Waiting --- 
  const { isLoading: isConfirmingA } = useWaitForTransactionReceipt({ hash: hashA });
  const { isLoading: isConfirmingB } = useWaitForTransactionReceipt({ hash: hashB });

  const handleClaimTokens = async () => {
    if (!connectedAddress) {
      alert("Please connect your wallet first!");
      return;
    }
    if (!tokenFactoryConfig || !tokenFactoryConfig.address || !tokenFactoryConfig.abi) {
        alert("TokenFactory configuration not found. Did contracts deploy and generate correctly?");
        return;
    }
    setIsLoading(true);
    setTxHashA(undefined);
    setTxHashB(undefined);
    try {
      const hashA = await createTokenA({
          address: tokenFactoryConfig.address,
          abi: tokenFactoryConfig.abi,
          functionName: "createToken",
          args: ["MyTokenA", "MTA", parseEther("1000")], // Use parseEther for clarity
      });
      setTxHashA(hashA);
      console.log("Token A tx sent:", hashA);
      
      // Send second transaction
      const hashB = await createTokenB({
          address: tokenFactoryConfig.address,
          abi: tokenFactoryConfig.abi,
          functionName: "createToken",
          args: ["MyTokenB", "MTB", parseEther("2000")],
      });
      setTxHashB(hashB);
      console.log("Token B tx sent:", hashB);

    } catch (e) {
      console.error("Error sending token creation transactions:", e, errorA, errorB);
    } finally {
      setIsLoading(false); 
    }
  };

  return (
    <>
      <div className="flex items-center flex-col flex-grow pt-10">
        <div className="px-5">
          <h1 className="text-center">
            <span className="block text-2xl mb-2">Welcome to</span>
            <span className="block text-4xl font-bold">DEX Explorer</span> 
          </h1>
          <div className="flex justify-center items-center space-x-2 flex-col my-4">
            <p className="my-0 font-medium">Connected Address:</p>
            <Address address={connectedAddress} />
          </div>

          {/* === FAUCET BUTTON === */}
          <div className="my-8 flex justify-center">
            <button
              className="btn btn-primary"
              onClick={handleClaimTokens}
              disabled={isLoading || isConfirmingA || isConfirmingB}
            >
              {isLoading || isConfirmingA || isConfirmingB ? (
                <span className="loading loading-spinner loading-sm"></span>
              ) : (
                "Get 2 New Test Tokens"
              )}
            </button>
          </div>
          {/* === END FAUCET BUTTON === */}

          <p className="text-center text-lg">
            Explore the mechanics of a DEX built with Scaffold-ETH 2 and Foundry.
          </p>
        </div>

        <div className="flex-grow bg-base-300 w-full mt-16 px-8 py-12">
          <div className="flex justify-center items-center gap-12 flex-col md:flex-row">
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <BugAntIcon className="h-8 w-8 fill-secondary" />
              <p>
                Interact with the deployed smart contracts using the{" "}
                <Link href="/debug" passHref className="link">
                  Debug Contracts
                </Link>{" "}
                tab.
              </p>
            </div>
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <MagnifyingGlassIcon className="h-8 w-8 fill-secondary" />
              <p>
                Explore your local transactions with the{" "}
                <Link href="/blockexplorer" passHref className="link">
                  Block Explorer
                </Link>{" "}
                tab.
              </p>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
