const dbName = process.env.COSMOS_DATABASE || 'employeedb';
const containerName = process.env.COSMOS_CONTAINER || 'employees';

if (process.env.USE_MOCK_DATA === 'true') {
  const mockEmployees = [
    { id: '1', name: 'Alice Johnson',  department: 'Engineering', jobTitle: 'Senior Engineer' },
    { id: '2', name: 'Bob Smith',      department: 'Marketing',   jobTitle: 'Marketing Manager' },
    { id: '3', name: 'Carol White',    department: 'Engineering', jobTitle: 'DevOps Engineer' },
    { id: '4', name: 'David Brown',    department: 'HR',          jobTitle: 'HR Business Partner' },
    { id: '5', name: 'Eve Davis',      department: 'Finance',     jobTitle: 'Financial Analyst' },
    { id: '6', name: 'Frank Miller',   department: 'Engineering', jobTitle: 'Tech Lead' },
    { id: '7', name: 'Grace Wilson',   department: 'Marketing',   jobTitle: 'Content Strategist' },
    { id: '8', name: 'Henry Moore',    department: 'Finance',     jobTitle: 'CFO' },
  ];

  const container = {
    items: {
      query: () => ({ fetchAll: async () => ({ resources: [...mockEmployees].sort((a, b) => a.name.localeCompare(b.name)) }) }),
      create: async () => {},
    },
  };

  module.exports = { container, dbName, containerName };
} else {
  const { CosmosClient } = require('@azure/cosmos');
  const { DefaultAzureCredential } = require('@azure/identity');

  const endpoint = process.env.COSMOS_ENDPOINT;
  if (!endpoint) throw new Error('COSMOS_ENDPOINT environment variable is required');

  const credential = new DefaultAzureCredential();
  const client = new CosmosClient({ endpoint, aadCredentials: credential });
  const database = client.database(dbName);
  const container = database.container(containerName);

  module.exports = { container, dbName, containerName };
}
