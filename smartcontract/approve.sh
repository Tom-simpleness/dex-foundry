#!/bin/bash

# Charger les variables d'environnement
set -a
source .env
set +a

# Approve TokenA
cast send 0x5329fdb58915b27a104ea8ecc24e3c871c6b6025 "approve(address,uint256)" 0x830dd10768dfdd87b6a1885c42b96c13f327d9d1 5000000000000000000000 --rpc-url sepolia --private-key $PRIVATE_KEY

# Approve TokenB
cast send 0x71686439c90b330a3cb15e77f8766675ce8c6ee0 "approve(address,uint256)" 0x830dd10768dfdd87b6a1885c42b96c13f327d9d1 10000000000000000000000 --rpc-url sepolia --private-key $PRIVATE_KEY 