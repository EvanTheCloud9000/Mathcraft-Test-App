const { Router } = require('express');
const { container } = require('../cosmos');

const router = Router();

router.get('/', async (req, res) => {
  try {
    const { resources } = await container.items
      .query('SELECT c.id, c.name, c.department, c.jobTitle FROM c ORDER BY c.name')
      .fetchAll();
    res.json(resources);
  } catch (err) {
    console.error('Failed to fetch employees:', err.message);
    res.status(500).json({ error: 'Failed to fetch employees' });
  }
});

module.exports = router;
