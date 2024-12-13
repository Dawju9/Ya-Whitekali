const fs = require('fs');
const path = require('path');

const CURRENT_DIR = './reports/current/';
const ARCHIVED_DIR = './reports/archived/';
const MAX_AGE_DAYS = 30;

function cleanOldReports() {
  const files = fs.readdirSync(CURRENT_DIR);
  const now = new Date();

  files.forEach(file => {
    const filePath = path.join(CURRENT_DIR, file);
    const stats = fs.statSync(filePath);
    const ageDays = (now - stats.mtime) / (1000 * 60 * 60 * 24);

    if (ageDays > MAX_AGE_DAYS) {
      const archivedPath = path.join(ARCHIVED_DIR, file);
      const data = JSON.parse(fs.readFileSync(filePath));
      const summary = {
        url: data.id,
        date: data.lighthouseResult.fetchTime,
        performance: data.lighthouseResult.categories.performance.score,
      };
      fs.writeFileSync(archivedPath, JSON.stringify(summary, null, 2));
      fs.unlinkSync(filePath);
      console.log(`Archived and removed old report: ${file}`);
    }
  });
}

cleanOldReports();
