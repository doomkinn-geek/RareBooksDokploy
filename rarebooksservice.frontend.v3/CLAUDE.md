# 📚 RareBooksService Frontend Guide

## 🛠️ Commands
| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server with hot module replacement |
| `npm run build` | Create optimized production build |
| `npm run preview` | Preview the production build locally |
| `npm run lint` | Run ESLint to check code quality |

## 🎨 Code Style

### Component Structure
- ✅ Use functional components with hooks 
- ✅ Follow PascalCase for component files (e.g., `BookDetail.jsx`)
- ✅ Use named exports for components

### State & Data Flow
- 📊 Global state: React Context (`UserContext.jsx`)
- 🔄 API calls: Use axios with functions from `api.js`
- 🔐 Auth: Token storage via js-cookie

### Syntax & Formatting
- 📝 Imports order: React → external libs → internal modules
- 🔤 Naming: camelCase (variables/functions), PascalCase (components)
- 💬 Comments in Russian, code variables in English

## 🧩 Common Patterns
- 🌐 Use `API_URL` constant for all endpoints
- 🔒 Include `getAuthHeaders()` for auth requests
- 📷 Use `responseType: 'blob'` for image downloads
- 📄 Implement pagination for list components