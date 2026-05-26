import { Request, Response } from 'express';

export class DemoController {
  getDashboard(req: Request, res: Response) {
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WAI Social Brain - AI SMM Agent</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      max-width: 900px;
      width: 100%;
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      font-size: 2.5em;
      margin-bottom: 10px;
    }
    .header p {
      font-size: 1.1em;
      opacity: 0.9;
    }
    .content {
      padding: 40px 30px;
    }
    .status-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      margin-bottom: 40px;
    }
    .status-card {
      background: #f8f9fa;
      padding: 20px;
      border-radius: 12px;
      border-left: 4px solid #667eea;
    }
    .status-card h3 {
      color: #667eea;
      font-size: 0.9em;
      text-transform: uppercase;
      margin-bottom: 10px;
    }
    .status-card .value {
      font-size: 2em;
      font-weight: bold;
      color: #333;
    }
    .demo-section {
      background: #f8f9fa;
      padding: 30px;
      border-radius: 12px;
      margin-bottom: 30px;
    }
    .demo-section h2 {
      margin-bottom: 20px;
      color: #333;
    }
    .form-group {
      margin-bottom: 15px;
    }
    .form-group label {
      display: block;
      margin-bottom: 8px;
      color: #555;
      font-weight: 500;
    }
    .form-group input,
    .form-group select,
    .form-group textarea {
      width: 100%;
      padding: 10px 12px;
      border: 1px solid #ddd;
      border-radius: 8px;
      font-size: 1em;
      font-family: inherit;
    }
    .form-group textarea {
      min-height: 100px;
      resize: vertical;
    }
    .button-group {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }
    button {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      padding: 12px 24px;
      border-radius: 8px;
      font-size: 1em;
      cursor: pointer;
      transition: transform 0.2s, box-shadow 0.2s;
    }
    button:hover {
      transform: translateY(-2px);
      box-shadow: 0 10px 20px rgba(102, 126, 234, 0.3);
    }
    button:active {
      transform: translateY(0);
    }
    .output {
      background: #1e1e1e;
      color: #00ff00;
      padding: 20px;
      border-radius: 8px;
      font-family: 'Monaco', 'Courier New', monospace;
      font-size: 0.9em;
      max-height: 300px;
      overflow-y: auto;
      margin-top: 15px;
    }
    .endpoint {
      background: white;
      padding: 15px;
      border-left: 3px solid #667eea;
      margin-bottom: 10px;
      border-radius: 4px;
    }
    .endpoint code {
      background: #f0f0f0;
      padding: 4px 8px;
      border-radius: 4px;
      font-family: monospace;
    }
    .features {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-top: 30px;
    }
    .feature {
      padding: 20px;
      border: 2px solid #f0f0f0;
      border-radius: 12px;
      transition: all 0.3s;
    }
    .feature:hover {
      border-color: #667eea;
      background: #f8f9ff;
    }
    .feature h3 {
      color: #667eea;
      margin-bottom: 10px;
    }
    .feature p {
      color: #666;
      font-size: 0.9em;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🧠 WAI Social Brain</h1>
      <p>AI SMM Agent - Content Planning & Publishing Platform</p>
    </div>

    <div class="content">
      <div class="status-grid">
        <div class="status-card">
          <h3>Status</h3>
          <div class="value">✅ Active</div>
        </div>
        <div class="status-card">
          <h3>API Version</h3>
          <div class="value">0.1.0</div>
        </div>
        <div class="status-card">
          <h3>AI Provider</h3>
          <div class="value">Claude</div>
        </div>
        <div class="status-card">
          <h3>Platforms</h3>
          <div class="value">8</div>
        </div>
      </div>

      <div class="demo-section">
        <h2>📋 API Endpoints</h2>
        <div class="endpoint">
          <code>GET /health</code> - Health check
        </div>
        <div class="endpoint">
          <code>POST /webhook/task</code> - Create content plan / generate content
        </div>
        <div class="endpoint">
          <code>GET /webhook/status</code> - Webhook status
        </div>
        <div class="endpoint">
          <code>GET /demo</code> - This page
        </div>
      </div>

      <div class="demo-section">
        <h2>🚀 Quick Demo - Create Content Plan</h2>
        <div class="form-group">
          <label>Social Account ID (UUID)</label>
          <input type="text" id="accountId" placeholder="550e8400-e29b-41d4-a716-446655440000"
                 value="550e8400-e29b-41d4-a716-446655440000">
        </div>
        <div class="form-group">
          <label>Project ID (UUID)</label>
          <input type="text" id="projectId" placeholder="550e8400-e29b-41d4-a716-446655440001"
                 value="550e8400-e29b-41d4-a716-446655440001">
        </div>
        <div class="form-group">
          <label>Your Message</label>
          <textarea id="message" placeholder="E.g., Create a 7-day Instagram content plan for a digital marketing agency">Create a content plan for Instagram for a marketing agency selling AI automation services</textarea>
        </div>
        <div class="button-group">
          <button onclick="testWebhook()">🎯 Send Task</button>
          <button onclick="clearOutput()">Clear</button>
        </div>
        <div id="output" class="output" style="display:none;"></div>
      </div>

      <div class="features">
        <div class="feature">
          <h3>🤖 Multi-AI Support</h3>
          <p>Claude, OpenAI, Gemini - choose your favorite AI model</p>
        </div>
        <div class="feature">
          <h3>📱 Multi-Platform</h3>
          <p>Instagram, Telegram, VK, YouTube, TikTok & more</p>
        </div>
        <div class="feature">
          <h3>📅 Smart Planning</h3>
          <p>Automatic 7-14 day content plans with AI</p>
        </div>
        <div class="feature">
          <h3>✍️ Content Generation</h3>
          <p>Captions, hashtags, image prompts - all AI-powered</p>
        </div>
        <div class="feature">
          <h3>🔐 Safe Publishing</h3>
          <p>Manual approval before any content goes live</p>
        </div>
        <div class="feature">
          <h3>🔗 Easy Integration</h3>
          <p>Webhook API for your server at 85.239.51.246</p>
        </div>
      </div>

      <div class="demo-section" style="margin-top: 40px;">
        <h2>📚 Documentation</h2>
        <p style="margin-bottom: 20px;">See README.md in the repository for full documentation.</p>
        <div style="background: white; padding: 20px; border-radius: 8px;">
          <h3 style="margin-bottom: 15px;">Webhook Payload Example:</h3>
          <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; font-family: monospace; font-size: 0.85em; overflow-x: auto;">
{
  "type": "create_content_plan",
  "socialAccountId": "550e8400-e29b-41d4-a716-446655440000",
  "projectId": "550e8400-e29b-41d4-a716-446655440001",
  "userMessage": "Create a 7-day plan for Instagram",
  "files": [],
  "references": []
}
          </div>
        </div>
      </div>
    </div>
  </div>

  <script>
    async function testWebhook() {
      const accountId = document.getElementById('accountId').value;
      const projectId = document.getElementById('projectId').value;
      const message = document.getElementById('message').value;
      const output = document.getElementById('output');

      if (!accountId || !projectId || !message) {
        alert('Please fill in all fields');
        return;
      }

      output.style.display = 'block';
      output.textContent = 'Loading...\\n';

      try {
        const response = await fetch('/webhook/task', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            type: 'create_content_plan',
            socialAccountId: accountId,
            projectId: projectId,
            userMessage: message,
            files: [],
            references: []
          })
        });

        const data = await response.json();
        output.textContent = JSON.stringify(data, null, 2);
      } catch (error) {
        output.textContent = 'Error: ' + error.message;
      }
    }

    function clearOutput() {
      document.getElementById('output').style.display = 'none';
    }
  </script>
</body>
</html>
    `;
    res.send(html);
  }
}
