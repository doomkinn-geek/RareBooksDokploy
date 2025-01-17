// src/App.jsx
import React from 'react';
import { BrowserRouter as Router, Route, Routes, Link } from 'react-router-dom';
import { UserProvider } from './context/UserContext';
import Home from './components/Home';
import Login from './components/Login';
import Register from './components/Register';
import SubscriptionPage from './components/SubscriptionPage';
import AdminPanel from './components/AdminPanel';
import UserDetailsPage from './components/UserDetailsPage';
import PrivateRoute from './components/PrivateRoute';
import BookSearchByTitle from './components/BookSearchByTitle';
import BookSearchByDescription from './components/BookSearchByDescription';
import SearchByCategory from './components/SearchByCategory';
import SearchBySeller from './components/SearchBySeller';
import SearchBooksByPriceRange from './components/SearchBooksByPriceRange';
import BookDetail from './components/BookDetail';
import InitialSetupPage from './components/InitialSetupPage';
import TermsOfService from './components/TermsOfService';
import Contacts from './components/Contacts';
import './style.css';

const App = () => {
    return (
        <UserProvider>
            <Router>
                <div className="container">
                    <header className="header">
                        <h1>
                            <Link to="/" style={{ color: '#fff', textDecoration: 'none' }}>
                                Сервис Редких Книг
                            </Link>
                        </h1>
                    </header>

                    <Routes>
                        {/* Оборачиваем "/" в PrivateRoute */}
                        <Route element={<PrivateRoute />}>
                            <Route path="/" element={<Home />} />

                            {/* Остальные приватные роуты */}
                            <Route path="/subscription" element={<SubscriptionPage />} />
                            <Route path="/admin" element={<AdminPanel />} />
                            <Route path="/books/:id" element={<BookDetail />} />
                            <Route path="/searchByTitle/:title" element={<BookSearchByTitle />} />
                            <Route path="/searchByDescription/:description" element={<BookSearchByDescription />} />
                            <Route path="/searchByCategory/:categoryId" element={<SearchByCategory />} />
                            <Route path="/searchBySeller/:sellerName" element={<SearchBySeller />} />
                            <Route path="/searchByPriceRange/:minPrice/:maxPrice" element={<SearchBooksByPriceRange />} />
                            <Route path="/user/:userId" element={<UserDetailsPage />} />
                            <Route path="/initial-setup" element={<InitialSetupPage />} />
                        </Route>

                        {/* А публичные роуты, не требующие авторизации */}
                        <Route path="/login" element={<Login />} />
                        <Route path="/register" element={<Register />} />
                        <Route path="/terms" element={<TermsOfService />} />
                        <Route path="/contacts" element={<Contacts />} />
                    </Routes>

                    <footer className="footer">
                        <div className="footer-content">
                            <p>&copy; 2025 Сервис Редких Книг</p>
                            <div className="footer-links">
                                <Link to="/terms" className="footer-link">Публичная оферта</Link>
                                <Link to="/contacts" className="footer-link">Контакты</Link>
                            </div>
                        </div>
                    </footer>
                </div>
            </Router>
        </UserProvider>
    );
};

export default App;
