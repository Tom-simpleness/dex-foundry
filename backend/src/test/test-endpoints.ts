import * as dex from '../services/dex';

// Fonction pour tester tous les endpoints
export async function testAllEndpoints() {
  console.log("=================================================");
  console.log("DÉMARRAGE DES TESTS DE TOUS LES ENDPOINTS");
  console.log("=================================================");

  // Test de la connexion
  try {
    console.log("\n📡 TEST DE CONNEXION RPC:");
    const connection = await dex.testConnection();
    console.log("✅ Résultat:", JSON.stringify(connection, null, 2));
  } catch (error) {
    console.error("❌ Erreur lors du test de connexion:", error);
  }

  // Test des pools
  try {
    console.log("\n🏊 TEST DES POOLS:");
    const pools = await dex.getAllPools();
    console.log(`✅ ${pools.length} pools trouvées:`, pools.length > 0 ? JSON.stringify(pools[0], null, 2) : "Aucune pool");
  } catch (error) {
    console.error("❌ Erreur lors du test des pools:", error);
  }

  // Test des swaps
  try {
    console.log("\n🔄 TEST DES SWAPS:");
    const swaps = await dex.getSwaps();
    console.log(`✅ ${swaps.length} swaps trouvés:`, swaps.length > 0 ? JSON.stringify(swaps[0], null, 2) : "Aucun swap");
  } catch (error) {
    console.error("❌ Erreur lors du test des swaps:", error);
  }

  // Test des utilisateurs
  try {
    console.log("\n👤 TEST DES UTILISATEURS:");
    const users = await dex.getUsers();
    console.log(`✅ ${users.length} utilisateurs trouvés:`, users.length > 0 ? JSON.stringify(users.slice(0, 5), null, 2) : "Aucun utilisateur");
  } catch (error) {
    console.error("❌ Erreur lors du test des utilisateurs:", error);
  }

  // Test des providers
  try {
    console.log("\n💰 TEST DES PROVIDERS:");
    const providers = await dex.getLiquidityProviders();
    console.log(`✅ ${providers.length} providers trouvés:`, providers.length > 0 ? JSON.stringify(providers.slice(0, 5), null, 2) : "Aucun provider");
  } catch (error) {
    console.error("❌ Erreur lors du test des providers:", error);
  }

  console.log("\n=================================================");
  console.log("FIN DES TESTS");
  console.log("=================================================");
} 