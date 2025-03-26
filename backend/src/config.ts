import dotenv from 'dotenv';
dotenv.config();

export default {
  RPC_URL: process.env.RPC_URL || "http://localhost:8545",
  FACTORY_ADDRESS: process.env.FACTORY_ADDRESS || "",
  CHAIN_ID: parseInt(process.env.CHAIN_ID || "")
};