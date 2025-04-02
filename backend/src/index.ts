import express from 'express';
import cors from 'cors';
import apiRoutes from './routes/api';
import { testAllEndpoints } from './test/test-endpoints';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

app.use('/api', apiRoutes);

app.get('/', (_req, res) => {
  res.json({
    message: 'DEX API Server',
    endpoints: [
      '/api/test',
      '/api/pools',
      '/api/swaps',
      '/api/users',
      '/api/providers'
    ]
  });
});

// Démarrage du serveur
app.listen(PORT, async () => {
  console.log(`Server running on port ${PORT}`);
  
  setTimeout(async () => {
    try {
      await testAllEndpoints();
    } catch (error) {
      console.error("Erreur lors de l'exécution des tests d'endpoints:", error);
    }
  }, 2000);
});