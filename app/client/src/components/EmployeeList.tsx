import React, { useEffect, useState } from 'react';
import { Employee } from '../types/Employee';

function initials(name: string) {
  return name.split(' ').map(p => p[0]).join('').slice(0, 2).toUpperCase();
}

const AVATAR_COLORS = ['#0078d4','#107c10','#d83b01','#8764b8','#038387','#c43e1c','#005a9e','#00b294'];

function avatarColor(id: string) {
  const n = id.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0);
  return AVATAR_COLORS[n % AVATAR_COLORS.length];
}

const EmployeeList: React.FC = () => {
  const [all, setAll] = useState<Employee[]>([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/employees')
      .then(res => {
        if (!res.ok) throw new Error(`Server returned ${res.status}`);
        return res.json();
      })
      .then((data: Employee[]) => { setAll(data); setLoading(false); })
      .catch(err => { setError(err.message); setLoading(false); });
  }, []);

  const q = query.trim().toLowerCase();
  const results = q
    ? all.filter(e =>
        e.name.toLowerCase().includes(q) ||
        e.department.toLowerCase().includes(q) ||
        e.jobTitle.toLowerCase().includes(q)
      )
    : [];

  return (
    <div className="search-page">
      <div className="search-box">
        <svg className="search-icon" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="8.5" cy="8.5" r="5.5" stroke="#9ca3af" strokeWidth="1.75"/>
          <path d="M13 13l3.5 3.5" stroke="#9ca3af" strokeWidth="1.75" strokeLinecap="round"/>
        </svg>
        <input
          className="search-input"
          type="text"
          placeholder="Search by name, department, or job title…"
          value={query}
          onChange={e => setQuery(e.target.value)}
          autoFocus
        />
        {query && (
          <button className="search-clear" onClick={() => setQuery('')} aria-label="Clear">
            ✕
          </button>
        )}
      </div>

      {loading && <p className="state-message">Loading…</p>}
      {error && <p className="state-message error">Error: {error}</p>}

      {!loading && !error && !q && (
        <p className="state-message hint">{all.length} employees — start typing to search</p>
      )}

      {!loading && !error && q && results.length === 0 && (
        <p className="state-message">No results for "{query}"</p>
      )}

      {results.length > 0 && (
        <div className="results-list">
          {results.map(emp => (
            <div className="employee-card" key={emp.id}>
              <div className="avatar" style={{ background: avatarColor(emp.id) }}>
                {initials(emp.name)}
              </div>
              <div className="employee-info">
                <div className="employee-name">{emp.name}</div>
                <div className="employee-meta">{emp.jobTitle}</div>
              </div>
              <span className={`dept-badge dept-${emp.department.toLowerCase().replace(/\s+/g, '-')}`}>
                {emp.department}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default EmployeeList;
