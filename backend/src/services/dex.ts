import { ethers } from 'ethers';
import { getContract, provider, FactoryABI, PoolABI } from './ethers';
import config from '../config';
import { Pool, Swap } from '../types';

// Instance du contrat Factory
const factory = getContract(config.FACTORY_ADDRESS, FactoryABI);

// Tester la connexion RPC
export async function testConnection() {
  try {
    const blockNumber = await provider.getBlockNumber();
    console.log(`Connecté à la blockchain. Dernier bloc: ${blockNumber}`);
    
    // Vérifier le contrat Factory
    const pairsLength = await factory.allPairsLength().catch(e => {
      console.error("Erreur lors de l'appel à allPairsLength:", e.message);
      return null;
    });
    
    console.log(`Factory address: ${config.FACTORY_ADDRESS}`);
    console.log(`Nombre de pools: ${pairsLength}`);
    
    return {
      connected: true,
      blockNumber,
      pairsLength
    };
  } catch (error) {
    console.error("Erreur de connexion:", error);
    return {
      connected: false,
      error: error instanceof Error ? error.message : String(error)
    };
  }
}

// Récupérer toutes les pools
async function getAllPools(): Promise<Pool[]> {
  try {
    // Récupérer le nombre de pools (appel de fonction au lieu de propriété)
    const poolCount = await factory.allPairsLength();
    console.log(`Nombre de pools trouvées: ${poolCount}`);
    
    const pools: Pool[] = [];
    
    for (let i = 0; i < poolCount; i++) {
      try {
        const poolAddress = await factory.allPairs(i);
        console.log(`Pool ${i} address: ${poolAddress}`);
        
        const pool = getContract(poolAddress, PoolABI);
        
        // Récupérer les tokens de la pool
        const [tokenA, tokenB] = await pool.getTokens();
        console.log(`Pool ${i} tokens: ${tokenA}, ${tokenB}`);
        
        // Récupérer les réserves
        const [reserveA, reserveB] = await pool.getReserves();
        
        pools.push({
          address: poolAddress,
          tokenA,
          tokenB,
          reserveA: ethers.formatUnits(reserveA, 18), // Conversion plus sûre
          reserveB: ethers.formatUnits(reserveB, 18)
        });
      } catch (error) {
        console.error(`Erreur avec la pool ${i}:`, error);
      }
    }
    
    return pools;
  } catch (error) {
    console.error("Erreur dans getAllPools:", error);
    throw error;
  }
}

// Récupérer les swaps (avec filtrage des événements)
async function getSwaps(): Promise<Swap[]> {
  try {
    const pools = await getAllPools();
    console.log(`${pools.length} pools trouvées pour rechercher des swaps`);
    
    let swaps: Swap[] = [];
    
    for (const poolInfo of pools) {
      const pool = getContract(poolInfo.address, PoolABI);
      
      try {
        // Filtrer les événements Swap
        const filter = pool.filters.Swap();
        console.log(`Recherche des swaps pour pool ${poolInfo.address}`);
        
        const events = await pool.queryFilter(filter);
        console.log(`${events.length} événements Swap trouvés pour pool ${poolInfo.address}`);
        
        // Pour Ethers v6, nous devons utiliser parseLog pour obtenir les args
        const poolSwaps = events.map(event => {
          // Utilise le casting pour accéder aux arguments typés
          try {
            const parsedEvent = event as ethers.EventLog;
            return {
              poolAddress: poolInfo.address,
              sender: parsedEvent.args[0], // Premier arg est sender
              amountIn: ethers.formatUnits(parsedEvent.args[1], 18), // Deuxième arg est amountIn 
              amountOut: ethers.formatUnits(parsedEvent.args[2], 18), // Troisième arg est amountOut
              tokenIn: parsedEvent.args[3], // Quatrième arg est tokenIn
              blockNumber: event.blockNumber,
              transactionHash: event.transactionHash
            };
          } catch (error) {
            console.error(`Erreur de parsing pour un événement Swap:`, error);
            return null;
          }
        }).filter(Boolean) as Swap[];
        
        swaps = swaps.concat(poolSwaps);
      } catch (error) {
        console.error(`Erreur lors de la récupération des swaps pour pool ${poolInfo.address}:`, error);
      }
    }
    
    return swaps;
  } catch (error) {
    console.error("Erreur dans getSwaps:", error);
    throw error;
  }
}

// Récupérer les utilisateurs (swappers)
async function getUsers(): Promise<string[]> {
  try {
    const swaps = await getSwaps();
    console.log(`${swaps.length} swaps trouvés pour extraire les utilisateurs`);
    
    // Ensemble unique d'adresses
    const users = [...new Set(swaps.map(swap => swap.sender))];
    return users;
  } catch (error) {
    console.error("Erreur dans getUsers:", error);
    throw error;
  }
}

// Récupérer les liquidity providers
async function getLiquidityProviders(): Promise<string[]> {
  try {
    const pools = await getAllPools();
    console.log(`${pools.length} pools trouvées pour rechercher des providers`);
    
    let providers: string[] = [];
    
    for (const poolInfo of pools) {
      try {
        const pool = getContract(poolInfo.address, PoolABI);
        
        // Filtrer les événements LiquidityAdded
        const filter = pool.filters.LiquidityAdded();
        const events = await pool.queryFilter(filter);
        console.log(`${events.length} événements LiquidityAdded trouvés pour pool ${poolInfo.address}`);
        
        const poolProviders = events.map(event => {
          try {
            // Utilise le casting pour accéder aux arguments typés
            const parsedEvent = event as ethers.EventLog;
            return parsedEvent.args[0]; // Premier arg est provider
          } catch (error) {
            console.error(`Erreur de parsing pour un événement LiquidityAdded:`, error);
            return null;
          }
        }).filter(Boolean) as string[];
        
        providers = providers.concat(poolProviders);
      } catch (error) {
        console.error(`Erreur lors de la récupération des providers pour pool ${poolInfo.address}:`, error);
      }
    }
    
    // Ensemble unique d'adresses
    return [...new Set(providers)];
  } catch (error) {
    console.error("Erreur dans getLiquidityProviders:", error);
    throw error;
  }
}

export {
  getAllPools,
  getSwaps,
  getUsers,
  getLiquidityProviders
};