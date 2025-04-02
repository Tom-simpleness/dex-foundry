# DEX Backend

This is the backend service for the DEX project. It provides API endpoints and services for the frontend application.

## Setup

```bash
npm install
```

## Development

```bash
npm run dev
```

When you run the dev command, the server will start and automatically run tests against all endpoints after 2 seconds.

You can access the API at: http://localhost:3000

## Endpoints

The following endpoints are available:

- `GET /` - API overview and endpoints list
- `GET /api/test` - Test the connection to the blockchain
- `GET /api/pools` - Get all available pools
- `GET /api/swaps` - Get all swap events
- `GET /api/users` - Get all users who performed swaps
- `GET /api/providers` - Get all liquidity providers

## Production

```bash
npm start
``` 