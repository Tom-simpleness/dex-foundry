import { ethers } from 'ethers';
import { getContract, provider, FactoryABI, PoolABI } from './ethers';
import config from '../config';
import { Pool, Swap } from '../types';

const factory = getContract(config.FACTORY_ADDRESS, FactoryABI);

const FACTORY_DEPLOYMENT_BLOCK = 7942538;

let cachedPools: Pool[] = [];
let lastFetchedBlock = FACTORY_DEPLOYMENT_BLOCK;
const swapCache: Record<string, { lastBlock: number; swaps: Swap[] }> = {};

export async function testConnection() {
  try {
    const blockNumber = await provider.getBlockNumber();
    console.log(`Connecté à la blockchain. Dernier bloc: ${blockNumber}`);
    
    const feeRecipient = await factory.getFeeRecipient().catch(e => {
      console.error("Erreur lors de l'appel à getFeeRecipient:", e.message);
      return null;
    });
    
    console.log(`Factory address: ${config.FACTORY_ADDRESS}`);
    console.log(`Fee recipient: ${feeRecipient}`);
    console.log(`Factory déployée au bloc: ${FACTORY_DEPLOYMENT_BLOCK}`);
    
    return {
      connected: true,
      blockNumber,
      feeRecipient,
      factoryDeploymentBlock: FACTORY_DEPLOYMENT_BLOCK
    };
  } catch (error) {
    console.error("Erreur de connexion:", error);
    return {
      connected: false,
      error: error instanceof Error ? error.message : String(error)
    };
  }
}

async function getAllPools(forceRefresh = false): Promise<Pool[]> {
  try {
    if (cachedPools.length > 0 && !forceRefresh) {
      console.log(`Utilisation du cache pour ${cachedPools.length} pools`);
      return cachedPools;
    }
    
    console.log("Récupération des pools via allPairs...");
    
    let allPairsLength = 0;
    let continueChecking = true;
    
    while (continueChecking) {
      try {
        await factory.allPairs(allPairsLength);
        allPairsLength++;
      } catch (error) {
        continueChecking = false;
      }
    }
    
    console.log(`Nombre de pools trouvées: ${allPairsLength}`);
    
    if (cachedPools.length === allPairsLength && !forceRefresh) {
      return cachedPools;
    }
    
    const pools: Pool[] = [];
    
    for (let i = 0; i < allPairsLength; i++) {
      try {
        const poolAddress = await factory.allPairs(i);
        
        const cachedPool = cachedPools.find(p => p.address.toLowerCase() === poolAddress.toLowerCase());
        if (cachedPool && !forceRefresh) {
          pools.push(cachedPool);
          continue;
        }
        
        console.log(`Pool ${i} address: ${poolAddress}`);
        
        const pool = getContract(poolAddress, PoolABI);
        
        const [tokenA, tokenB] = await pool.getTokens();
        console.log(`Pool ${i} tokens: ${tokenA}, ${tokenB}`);
        
        const [reserveA, reserveB] = await pool.getReserves();
        
        pools.push({
          address: poolAddress,
          tokenA,
          tokenB,
          reserveA: ethers.formatUnits(reserveA, 18),
          reserveB: ethers.formatUnits(reserveB, 18)
        });
      } catch (error) {
        console.error(`Erreur avec la pool ${i}:`, error);
      }
    }
    
    cachedPools = pools;
    
    return pools;
  } catch (error) {
    console.error("Erreur dans getAllPools:", error);
    throw error;
  }
}

async function getEventsByPages(
  contract: ethers.Contract,
  eventName: string,
  startBlock: number,
  endBlock: number,
  pageSize = 500      
): Promise<ethers.EventLog[]> {
  console.log(`Récupération des événements ${eventName} du bloc ${startBlock} au bloc ${endBlock}`);
  
  let allEvents: ethers.EventLog[] = [];
  let fromBlock = startBlock;
  
  while (fromBlock < endBlock) {
    const toBlock = Math.min(fromBlock + pageSize - 1, endBlock);
    
    try {
      const filter = contract.filters[eventName]();
      
      const events = await contract.queryFilter(filter, fromBlock, toBlock);
      
      if (events.length > 0) {
        console.log(`Trouvé ${events.length} événements ${eventName} du bloc ${fromBlock} au bloc ${toBlock}`);
      }
      
      allEvents = allEvents.concat(events as ethers.EventLog[]);
    } catch (error) {
      console.error(`Erreur lors de la récupération des événements entre les blocs ${fromBlock} et ${toBlock}:`, error);
      
      if (error && typeof error === 'object' && 'error' in error &&
          error.error && typeof error.error === 'object' && 'message' in error.error &&
          typeof error.error.message === 'string' && error.error.message.includes("Range exceeds limit")) {
        
        if (pageSize <= 100) {
          console.log("La page est déjà petite, passage à la plage suivante");
        } else {
          const newPageSize = Math.floor(pageSize / 2);
          console.log(`Réduction de la taille de page à ${newPageSize}`);
          
          const subEvents = await getEventsByPages(contract, eventName, fromBlock, toBlock, newPageSize);
          allEvents = allEvents.concat(subEvents);
          
          fromBlock = toBlock + 1;
          continue;
        }
      }
    }
    
    fromBlock = toBlock + 1;
  }
  
  return allEvents;
}

async function getSwaps(forceRefresh = false): Promise<Swap[]> {
  try {
    const currentBlock = await provider.getBlockNumber();
    const pools = await getAllPools();
    console.log(`${pools.length} pools trouvées pour rechercher des swaps`);
    
    let allSwaps: Swap[] = [];
    
    for (const poolInfo of pools) {
      try {
        const poolAddress = poolInfo.address;
        
        const poolCache = swapCache[poolAddress];
        let startBlock = FACTORY_DEPLOYMENT_BLOCK;
        
        if (poolCache && !forceRefresh) {
          startBlock = poolCache.lastBlock + 1;
          allSwaps = allSwaps.concat(poolCache.swaps);
          
          if (startBlock >= currentBlock) {
            console.log(`Cache à jour pour la pool ${poolAddress}`);
            continue;
          }
        }
        
        console.log(`Recherche des nouveaux swaps pour pool ${poolAddress} (bloc ${startBlock} au ${currentBlock})`);
        
        const pool = getContract(poolAddress, PoolABI);
        
        const events = await getEventsByPages(pool, 'Swap', startBlock, currentBlock);
        
        if (events.length > 0) {
          console.log(`${events.length} nouveaux événements Swap trouvés pour pool ${poolAddress}`);
        }
        
        const poolSwaps = events.map(event => {
          try {
            const parsedEvent = event as ethers.EventLog;
            return {
              poolAddress: poolInfo.address,
              sender: parsedEvent.args[0],
              amountIn: ethers.formatUnits(parsedEvent.args[1], 18),
              amountOut: ethers.formatUnits(parsedEvent.args[2], 18),
              tokenIn: parsedEvent.args[3],
              blockNumber: event.blockNumber,
              transactionHash: event.transactionHash
            };
          } catch (error) {
            console.error(`Erreur de parsing pour un événement Swap:`, error);
            return null;
          }
        }).filter(Boolean) as Swap[];
        
        allSwaps = allSwaps.concat(poolSwaps);
        
        swapCache[poolAddress] = {
          lastBlock: currentBlock,
          swaps: poolCache ? [...poolCache.swaps, ...poolSwaps] : poolSwaps
        };
      } catch (error) {
        console.error(`Erreur lors de la récupération des swaps pour pool ${poolInfo.address}:`, error);
      }
    }
    
    lastFetchedBlock = currentBlock;
    
    return allSwaps;
  } catch (error) {
    console.error("Erreur dans getSwaps:", error);
    throw error;
  }
}

let cachedUsers: string[] = [];
let lastUserFetch = 0;

async function getUsers(forceRefresh = false): Promise<string[]> {
  try {
    const currentBlock = await provider.getBlockNumber();
    
    if (cachedUsers.length > 0 && !forceRefresh && (currentBlock - lastUserFetch) < 100) {
      console.log(`Utilisation du cache pour ${cachedUsers.length} utilisateurs`);
      return cachedUsers;
    }
    
    const swaps = await getSwaps();
    console.log(`${swaps.length} swaps trouvés pour extraire les utilisateurs`);
    
    const users = [...new Set(swaps.map(swap => swap.sender))];
    
    cachedUsers = users;
    lastUserFetch = currentBlock;
    
    return users;
  } catch (error) {
    console.error("Erreur dans getUsers:", error);
    throw error;
  }
}

let cachedProviders: string[] = [];
let lastProviderFetch = 0;
const liquidityCache: Record<string, { lastBlock: number; providers: string[] }> = {};

async function getLiquidityProviders(forceRefresh = false): Promise<string[]> {
  try {
    const currentBlock = await provider.getBlockNumber();
    
    if (cachedProviders.length > 0 && !forceRefresh && (currentBlock - lastProviderFetch) < 100) {
      console.log(`Utilisation du cache pour ${cachedProviders.length} fournisseurs de liquidité`);
      return cachedProviders;
    }
    
    const pools = await getAllPools();
    console.log(`${pools.length} pools trouvées pour rechercher des providers`);
    
    let allProviders: string[] = [];
    
    for (const poolInfo of pools) {
      try {
        const poolAddress = poolInfo.address;
        
        const poolCache = liquidityCache[poolAddress];
        let startBlock = FACTORY_DEPLOYMENT_BLOCK;
        
        if (poolCache && !forceRefresh) {
          startBlock = poolCache.lastBlock + 1;
          allProviders = allProviders.concat(poolCache.providers);
          
          if (startBlock >= currentBlock) {
            console.log(`Cache à jour pour les providers de la pool ${poolAddress}`);
            continue;
          }
        }
        
        console.log(`Recherche des nouveaux providers pour pool ${poolAddress} (bloc ${startBlock} au ${currentBlock})`);
        
        const pool = getContract(poolAddress, PoolABI);
        
        const events = await getEventsByPages(pool, 'LiquidityAdded', startBlock, currentBlock);
        
        if (events.length > 0) {
          console.log(`${events.length} nouveaux événements LiquidityAdded trouvés pour pool ${poolAddress}`);
        }
        
        const poolProviders = events.map(event => {
          try {
            const parsedEvent = event as ethers.EventLog;
            return parsedEvent.args[0];
          } catch (error) {
            console.error(`Erreur de parsing pour un événement LiquidityAdded:`, error);
            return null;
          }
        }).filter(Boolean) as string[];
        
        allProviders = allProviders.concat(poolProviders);
        
        liquidityCache[poolAddress] = {
          lastBlock: currentBlock,
          providers: poolCache ? [...poolCache.providers, ...poolProviders] : poolProviders
        };
      } catch (error) {
        console.error(`Erreur lors de la récupération des providers pour pool ${poolInfo.address}:`, error);
      }
    }
    
    const providers = [...new Set(allProviders)];
    cachedProviders = providers;
    lastProviderFetch = currentBlock;
    
    return providers;
  } catch (error) {
    console.error("Erreur dans getLiquidityProviders:", error);
    throw error;
  }
}

export function clearCache() {
  cachedPools = [];
  cachedUsers = [];
  cachedProviders = [];
  lastFetchedBlock = FACTORY_DEPLOYMENT_BLOCK;
  lastUserFetch = 0;
  lastProviderFetch = 0;
  
  Object.keys(swapCache).forEach(key => {
    delete swapCache[key];
  });
  
  Object.keys(liquidityCache).forEach(key => {
    delete liquidityCache[key];
  });
  
  console.log("Cache effacé avec succès");
}

export {
  getAllPools,
  getSwaps,
  getUsers,
  getLiquidityProviders
};