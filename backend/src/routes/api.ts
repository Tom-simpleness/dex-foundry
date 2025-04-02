import express, { Request, Response } from 'express';
import * as dex from '../services/dex';

const router = express.Router();

router.get('/test', async (_req: Request, res: Response) => {
  try {
    const status = await dex.testConnection();
    res.json(status);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: errorMessage });
  }
});

router.get('/pools', async (_req: Request, res: Response) => {
  try {
    const pools = await dex.getAllPools();
    res.json(pools);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: errorMessage });
  }
});

router.get('/swaps', async (_req: Request, res: Response) => {
  try {
    const swaps = await dex.getSwaps();
    res.json(swaps);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: errorMessage });
  }
});

router.get('/users', async (_req: Request, res: Response) => {
  try {
    const users = await dex.getUsers();
    res.json(users);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: errorMessage });
  }
});

router.get('/providers', async (_req: Request, res: Response) => {
  try {
    const providers = await dex.getLiquidityProviders();
    res.json(providers);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    res.status(500).json({ error: errorMessage });
  }
});

export default router;