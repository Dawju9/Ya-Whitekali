const fetch = require('node-fetch');
const fs = require('fs');
const path = require('path');

const SITES_FILE = './sites.json';
const REPORTS_DIR = './reports/current/';
const API_KEY = 'yourAPIKey';
const API_URL = 'https://www.googleapis.com/pagespeedonline/v5/runPagespeed';

async function fetchReports() {
  const sites = JSON.parse(fs.readFileSync(SITES_FILE));
  for (const site of sites) {
    const url = `${API_URL}?url=${encodeURIComponent(site)}&key=${API_KEY}`;
    try {
      const response = await fetch(url);
      const data = await response.json();
      const reportPath = path.join(REPORTS_DIR, `${encodeURIComponent(site)}.json`);
      fs.writeFileSync(reportPath, JSON.stringify(data, null, 2));
      console.log(`Saved report for: ${site}`);
    } catch (error) {
      console.error(`Error fetching report for ${site}:`, error);
    }
  }
}

fetchReports();
