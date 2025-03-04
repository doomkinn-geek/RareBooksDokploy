// src/App.jsx
import React, { useContext } from 'react';
import { BrowserRouter as Router, Route, Routes, Link, useNavigate } from 'react-router-dom';
import { 
    AppBar, 
    Toolbar, 
    Typography, 
    Button, 
    IconButton, 
    Box, 
    Container, 
    Menu, 
    MenuItem,
    Select,
    FormControl,
    InputLabel,
    ThemeProvider,
    CssBaseline
} from '@mui/material';
import { UserProvider, UserContext } from './context/UserContext';
import { LanguageProvider, LanguageContext } from './context/LanguageContext';
import translations from './translations';
import Home from './components/Home';
import Login from './components/Login';
import Register from './components/Register';
import SubscriptionPage from './components/SubscriptionPage';
import SubscriptionSuccess from './components/SubscriptionSuccess';
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
import Categories from './components/Categories';
import theme from './theme';
import './style.css';
import Cookies from 'js-cookie';

// Иконки
import SearchIcon from '@mui/icons-material/Search';
import PersonIcon from '@mui/icons-material/Person';
import AccessibilityNewIcon from '@mui/icons-material/AccessibilityNew';
import LanguageIcon from '@mui/icons-material/Language';

const NavBar = () => {
    const { user, setUser } = useContext(UserContext);
    const { language, setLanguage } = useContext(LanguageContext);
    const navigate = useNavigate();
    const [anchorEl, setAnchorEl] = React.useState(null);
    
    // Получаем переводы для текущего языка
    const t = translations[language];

    const handleMenu = (event) => {
        setAnchorEl(event.currentTarget);
    };

    const handleClose = () => {
        setAnchorEl(null);
    };

    // Реализация функции выхода из системы
    const handleLogout = () => {
        // Удаляем токен из cookie
        Cookies.remove('token');
        // Очищаем информацию о пользователе в контексте
        setUser(null);
        // Закрываем меню
        handleClose();
        // Перенаправляем на главную страницу
        navigate('/');
    };

    const handleLogin = () => {
        navigate('/login');
        handleClose();
    };

    const handleChangeLanguage = (event) => {
        setLanguage(event.target.value);
    };

    return (
        <AppBar position="static" elevation={0} sx={{ backgroundColor: 'white', color: 'black' }}>
            <Container maxWidth="xl">
                <Toolbar sx={{ justifyContent: 'space-between' }}>
                    {/* Левая часть */}
                    <Box sx={{ display: 'flex' }}>
                        <Button color="inherit" component={Link} to="/">
                            {language === 'RU' ? 'Обзор книг' : 'Books Overview'}
                        </Button>
                        <Button color="inherit" component={Link} to="/categories">
                            {language === 'RU' ? 'Каталог' : 'Catalog'}
                        </Button>
                    </Box>

                    {/* Центральная часть - логотип */}
                    <Typography
                        variant="h4"
                        component={Link}
                        to="/"
                        sx={{
                            display: { xs: 'none', md: 'flex' },
                            fontWeight: 'bold',
                            color: 'primary.main',
                            textDecoration: 'none',
                            letterSpacing: '1px'
                        }}
                    >
                        {language === 'RU' ? 'Редкие Книги' : 'Rare Books'}
                    </Typography>

                    {/* Мобильный логотип */}
                    <Typography
                        variant="h5"
                        component={Link}
                        to="/"
                        sx={{
                            display: { xs: 'flex', md: 'none' },
                            fontWeight: 'bold',
                            color: 'primary.main',
                            textDecoration: 'none',
                        }}
                    >
                        {language === 'RU' ? 'РК' : 'RB'}
                    </Typography>

                    {/* Правая часть */}
                    <Box sx={{ display: 'flex', alignItems: 'center' }}>
                        <IconButton
                            color="inherit"
                            aria-label="account"
                            aria-controls="menu-appbar"
                            aria-haspopup="true"
                            onClick={handleMenu}
                        >
                            <PersonIcon />
                        </IconButton>
                        <Menu
                            id="menu-appbar"
                            anchorEl={anchorEl}
                            anchorOrigin={{
                                vertical: 'bottom',
                                horizontal: 'right',
                            }}
                            keepMounted
                            transformOrigin={{
                                vertical: 'top',
                                horizontal: 'right',
                            }}
                            open={Boolean(anchorEl)}
                            onClose={handleClose}
                        >
                            {user ? (
                                [
                                    <MenuItem key="profile" onClick={() => { navigate(`/user/${user.id}`); handleClose(); }}>
                                        {language === 'RU' ? 'Мой профиль' : 'My Profile'}
                                    </MenuItem>,
                                    <MenuItem key="subscription" onClick={() => { navigate('/subscription'); handleClose(); }}>
                                        {language === 'RU' ? 'Подписка' : 'Subscription'}
                                    </MenuItem>,
                                    user.role && user.role.toLowerCase() === 'admin' && (
                                        <MenuItem key="admin" onClick={() => { navigate('/admin'); handleClose(); }}>
                                            {t.adminPanel}
                                        </MenuItem>
                                    ),
                                    <MenuItem key="logout" onClick={handleLogout}>
                                        {t.logout}
                                    </MenuItem>
                                ]
                            ) : (
                                <MenuItem onClick={handleLogin}>{t.login}</MenuItem>
                            )}
                        </Menu>
                        <FormControl size="small" sx={{ ml: 1, minWidth: 70 }}>
                            <Select
                                value={language}
                                onChange={handleChangeLanguage}
                                sx={{ 
                                    height: '36px',
                                    '.MuiOutlinedInput-notchedOutline': { 
                                        border: 'none' 
                                    }
                                }}
                            >
                                <MenuItem value="RU">RU</MenuItem>
                                <MenuItem value="EN">EN</MenuItem>
                            </Select>
                        </FormControl>
                    </Box>
                </Toolbar>
            </Container>
        </AppBar>
    );
};

// Создаем внутренний компонент, который будет использовать контексты
const AppContent = () => {
    const { language } = useContext(LanguageContext);
    
    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
            <NavBar />

            <Box component="main" sx={{ flex: 1, py: 4 }}>
                <Container>
                    <Routes>
                        {/* Главная страница теперь общедоступная */}
                        <Route path="/" element={<Home />} />
                        
                        {/* Публичная страница категорий */}
                        <Route path="/categories" element={<Categories />} />

                        {/* Закрытая часть за PrivateRoute */}
                        <Route element={<PrivateRoute />}>
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

                        {/* Публичные маршруты */}
                        <Route path="/login" element={<Login />} />
                        <Route path="/register" element={<Register />} />
                        <Route path="/terms" element={<TermsOfService />} />
                        <Route path="/contacts" element={<Contacts />} />
                        <Route path="/subscription-success" element={<SubscriptionSuccess />} />
                    </Routes>
                </Container>
            </Box>

            <Box component="footer" sx={{ 
                py: 3, 
                mt: 'auto',
                backgroundColor: 'background.paper',
                borderTop: '1px solid',
                borderColor: 'divider'
            }}>
                <Container maxWidth="xl">
                    <Box sx={{ 
                        display: 'flex', 
                        justifyContent: 'space-between',
                        flexDirection: { xs: 'column', sm: 'row' },
                        alignItems: { xs: 'center', sm: 'flex-start' }
                    }}>
                        <Box sx={{ display: 'flex', mb: { xs: 2, sm: 0 } }}>
                            <Button component={Link} to="/terms" color="inherit" sx={{ mr: 2 }}>
                                {language === 'RU' ? 'Публичная оферта' : 'Terms of Service'}
                            </Button>
                            <Button component={Link} to="/contacts" color="inherit">
                                {language === 'RU' ? 'Контакты' : 'Contacts'}
                            </Button>
                        </Box>
                        <Typography variant="body2" color="text.secondary">
                            &copy; 2025 {language === 'RU' ? 'Сервис Редких Книг' : 'Rare Books Service'}
                        </Typography>
                    </Box>
                </Container>
            </Box>
        </Box>
    );
};

const App = () => {
    return (
        <ThemeProvider theme={theme}>
            <CssBaseline />
            <LanguageProvider>
                <UserProvider>
                    <Router>
                        <AppContent />
                    </Router>
                </UserProvider>
            </LanguageProvider>
        </ThemeProvider>
    );
};

export default App;
