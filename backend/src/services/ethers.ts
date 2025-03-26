import { ethers } from 'ethers';
import config from '../config';

// Import des ABI
import * as FactoryABIFile from '../../abi/PoolFactory.json';
import * as PoolABIFile from '../../abi/Pool.json';

// Extraire la propriété "abi" des fichiers
const FactoryABI = FactoryABIFile.abi;
const PoolABI = PoolABIFile.abi;

// Provider
const provider = new ethers.JsonRpcProvider(config.RPC_URL);

// Fonction pour créer une instance de contrat
function getContract(address: string, abi: any): ethers.Contract {
  return new ethers.Contract(address, abi, provider);
}

export {
  provider,
  getContract,
  FactoryABI,
  PoolABI
};