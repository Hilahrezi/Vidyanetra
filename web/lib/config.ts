const rawBase = process.env.API_BASE ?? 'http://127.0.0.1:8000';

// Membersihkan trailing slash dan akhiran /api jika tidak sengaja terketik
export const API_BASE = rawBase.trim().replace(/\/+$/, '').replace(/\/api$/, '');

export const TOKEN_COOKIE = 'ag_token';
