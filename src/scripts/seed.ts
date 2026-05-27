import dotenv from 'dotenv';
import { AppDataSource } from '../config/database';
import { SeedDataService } from '../services/SeedDataService';

dotenv.config();

async function main() {
  try {
    console.log('\n🚀 Initializing database...\n');

    await AppDataSource.initialize();
    console.log('✅ Database connected\n');

    const seedService = new SeedDataService();
    await seedService.seedAll();

    console.log('✨ All done! Your demo data is ready.\n');
    console.log('🌐 Start the server: npm run dev');
    console.log('📊 Dashboard: http://localhost:3000/demo\n');

    process.exit(0);
  } catch (error: any) {
    console.error('\n❌ Error during seeding:', error.message);
    console.error(error);
    process.exit(1);
  }
}

main();
