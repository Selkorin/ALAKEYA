# 🚀 Deployment Guide - WAI Social Brain

## Quick Deploy Options

### Option 1: Railway.app (⭐ Recommended - Free + PostgreSQL)

**Pros:**
- ✅ Free tier with $5/month credits
- ✅ Built-in PostgreSQL database
- ✅ Easy GitHub integration
- ✅ Automatic deployments
- ✅ Custom domain support

**Steps:**

1. **Go to https://railway.app** and sign up (use GitHub)

2. **Create new project** → "Deploy from GitHub"

3. **Connect your GitHub repo** (fork or push this repo to your GitHub)

4. **Railway auto-detects Node.js project**

5. **Add PostgreSQL plugin:**
   - In Railway dashboard, click "Add Service"
   - Search "PostgreSQL"
   - Add it

6. **Set environment variables:**
   - In the Node service settings, add these variables:
   ```
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   ANTHROPIC_API_KEY=sk-ant-xxx...
   NODE_ENV=production
   PORT=3000
   ```

7. **Deploy!**
   - Railway will automatically deploy on every push
   - Your app will be at something like `https://wai-social-agent-production.up.railway.app`

**Cost:** ~$5/month for database + compute (comes with $5 free credits)

---

### Option 2: Render.com (Free, but slower)

**Pros:**
- ✅ Free tier
- ✅ PostgreSQL included
- ✅ GitHub integration

**Steps:**

1. Go to https://render.com

2. Click "New +" → "Web Service"

3. Connect GitHub repo

4. Configure:
   - **Name:** `wai-social-agent`
   - **Runtime:** Node
   - **Build Command:** `npm install && npm run build`
   - **Start Command:** `npm start`

5. Add environment variables same as Railway

6. Add PostgreSQL database in dashboard

---

### Option 3: Vercel (Alternative for API-only)

**Note:** Vercel is optimized for Next.js, not Express. Use Railway or Render instead.

---

### Option 4: Fly.io (Free + Good Performance)

**Pros:**
- ✅ Free tier
- ✅ Good performance
- ✅ PostgreSQL support

**Steps:**

1. Install `flyctl`:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. Sign up:
   ```bash
   fly auth signup
   ```

3. Create app:
   ```bash
   fly launch
   ```

4. Add PostgreSQL:
   ```bash
   fly postgres create
   ```

5. Deploy:
   ```bash
   fly deploy
   ```

---

## Environment Variables Needed

```env
# Database (auto-set by Railway)
DATABASE_URL=postgresql://user:password@host:5432/wai_social_agent

# Alternative if using separate DB:
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=wai_social_agent

# API Keys
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GOOGLE_GEMINI_API_KEY=...

# Server
NODE_ENV=production
PORT=3000

# Social Media (add as you integrate)
TELEGRAM_BOT_TOKEN=...
INSTAGRAM_ACCESS_TOKEN=...

# Security
JWT_SECRET=your-random-secret-key
```

---

## Verify Deployment

After deployment, visit:

```
https://your-deployed-url/demo
```

You should see a purple dashboard with API demo form.

Test the health endpoint:
```bash
curl https://your-deployed-url/health
# Should return: {"status":"ok","service":"WAI Social Agent","version":"0.1.0"}
```

---

## Database Setup After Deploy

Once deployed, you need to initialize the database:

```bash
# Via Railway CLI:
railway run npx typeorm migration:run

# Or via SSH:
ssh into the deployment and run migrations
```

For development/testing without a real database:
- The app will attempt to connect
- If it fails, it will still allow `/demo` and `/health` endpoints
- Real webhook tasks require a working database

---

## Monitoring

### Railway Dashboard
- View logs: `Railway Dashboard → Your App → Logs`
- Monitor metrics: CPU, Memory, Network
- View deployments history

### Health Checks
Set up health check monitoring:
```
GET /health
Expected: {"status":"ok",...}
Check every 60 seconds
```

---

## Custom Domain

### On Railway

1. In project settings, go to "Domains"
2. Add custom domain
3. Update DNS records from your registrar
4. Free SSL certificate auto-generated

Example: `wai-social.yourdomain.com`

---

## Webhook Integration

Once deployed, update your server webhook calls:

**From:**
```
http://localhost:3000/webhook/task
```

**To:**
```
https://your-railway-app.up.railway.app/webhook/task
```

**Or with custom domain:**
```
https://wai-social.yourdomain.com/webhook/task
```

---

## Troubleshooting

### "Database connection error"
- Check `DATABASE_URL` environment variable
- Ensure PostgreSQL service is added
- Check credentials

### "Port already in use"
- Railway/Render automatically assigns PORT
- Don't hardcode port in your code

### "Build fails"
- Check build logs in dashboard
- Ensure `package.json` has correct scripts
- Run `npm run build` locally to test

### "Module not found"
- Clear node_modules: `rm -rf node_modules package-lock.json`
- Reinstall: `npm install`
- Push again

---

## Next Steps

1. ✅ Deploy to Railway
2. ✅ Test `/demo` dashboard
3. ✅ Configure API keys
4. 🔄 Add Instagram OAuth integration
5. 🔄 Connect to your server webhook
6. 🔄 Add AI content generation

---

## Cost Breakdown

| Service | Free Tier | Paid |
|---------|-----------|------|
| Railway | $5 credits/month | $0.50/GB RAM |
| PostgreSQL | Included | Included |
| Bandwidth | Included | Included |
| Domain | Subdomain only | +$10/year (custom) |

**Total monthly cost:** $0 - $5

---

Questions? Check the main README.md or open an issue on GitHub.
