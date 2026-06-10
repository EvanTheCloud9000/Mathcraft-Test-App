import React from 'react';
import EmployeeList from './components/EmployeeList';
import './App.css';

const App: React.FC = () => (
  <>
    <header className="app-header">
      <h1>Employee Directory</h1>
      <p>Powered by Azure Cosmos DB</p>
    </header>
    <main>
      <EmployeeList />
    </main>
  </>
);

export default App;
