const express = require('express');
const { container } = require('./cosmos');
const employeeRoutes = require('./routes/employees');

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json());

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.use('/api/employees', employeeRoutes);

async function seedIfEmpty() {
  try {
    const { resources } = await container.items
      .query({ query: 'SELECT VALUE COUNT(1) FROM c' })
      .fetchAll();

    if (resources[0] === 0) {
      const employees = [
        { id: '1', name: 'Alice Johnson',  department: 'Engineering', jobTitle: 'Senior Engineer' },
        { id: '2', name: 'Bob Smith',      department: 'Marketing',   jobTitle: 'Marketing Manager' },
        { id: '3', name: 'Carol White',    department: 'Engineering', jobTitle: 'DevOps Engineer' },
        { id: '4', name: 'David Brown',    department: 'HR',          jobTitle: 'HR Business Partner' },
        { id: '5', name: 'Eve Davis',      department: 'Finance',     jobTitle: 'Financial Analyst' },
        { id: '6', name: 'Frank Miller',   department: 'Engineering', jobTitle: 'Tech Lead' },
        { id: '7', name: 'Grace Wilson',   department: 'Marketing',   jobTitle: 'Content Strategist' },
        { id: '8', name: 'Henry Moore',    department: 'Finance',     jobTitle: 'CFO' },
      ];

      await Promise.all(employees.map(e => container.items.create(e)));
      console.log('Database seeded with sample employees');
    }
  } catch (err) {
    // Non-fatal — the app still serves requests; seeding can be retried on next restart
    console.error('Seeding skipped:', err.message);
  }
}

app.listen(PORT, async () => {
  console.log(`API listening on port ${PORT}`);
  await seedIfEmpty();
});
