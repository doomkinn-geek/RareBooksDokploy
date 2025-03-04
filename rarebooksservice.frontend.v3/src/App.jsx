// src/App.jsx
import React, { useContext, useState } from 'react';
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
    CssBaseline,
    Drawer,
    List,
    ListItem,
    ListItemText,
    ListItemIcon,
    useMediaQuery,
    Divider
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
import './mobile.css';
import Cookies from 'js-cookie';

// Иконки
import SearchIcon from '@mui/icons-material/Search';
import PersonIcon from '@mui/icons-material/Person';
import AccessibilityNewIcon from '@mui/icons-material/AccessibilityNew';
import LanguageIcon from '@mui/icons-material/Language';
import MenuIcon from '@mui/icons-material/Menu';
import HomeIcon from '@mui/icons-material/Home';
import BookIcon from '@mui/icons-material/Book';
import CategoryIcon from '@mui/icons-material/Category';
import LoginIcon from '@mui/icons-material/Login';
import LogoutIcon from '@mui/icons-material/Logout';
import PersonAddIcon from '@mui/icons-material/PersonAdd';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';
import ContactsIcon from '@mui/icons-material/Contacts';
import DescriptionIcon from '@mui/icons-material/Description';

const NavBar = () => {
    const { user, setUser, logoutUser } = useContext(UserContext);
    const { language, setLanguage } = useContext(LanguageContext);
    const t = translations[language];
    const navigate = useNavigate();
    
    // Состояние для отслеживания открытия меню пользователя
    const [anchorEl, setAnchorEl] = useState(null);
    
    // Состояние для отслеживания открытия мобильного меню
    const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
    
    // Определяем, используется ли мобильное устройство
    const isMobile = useMediaQuery('(max-width:768px)');
    
    const handleMenu = (event) => {
        setAnchorEl(event.currentTarget);
    };
    
    const handleClose = () => {
        setAnchorEl(null);
    };
    
    const handleLogout = () => {
        // Удаляем куки
        Cookies.remove('token');
        Cookies.remove('isAdmin');
        Cookies.remove('userId');
        
        // Очищаем состояние пользователя
        logoutUser();
        
        // Закрываем меню
        handleClose();
        
        // Переходим на главную
        navigate('/');
    };
    
    const handleLogin = () => {
        navigate('/login');
    };
    
    const handleChangeLanguage = (event) => {
        setLanguage(event.target.value);
    };
    
    const toggleMobileMenu = () => {
        setMobileMenuOpen(!mobileMenuOpen);
    };
    
    const handleMobileMenuItemClick = (path) => {
        setMobileMenuOpen(false);
        navigate(path);
    };

    // Компонент мобильного меню
    const mobileMenu = (
        <Drawer 
            anchor="left" 
            open={mobileMenuOpen} 
            onClose={toggleMobileMenu}
            classes={{
                paper: 'mobile-menu-paper'
            }}
        >
            <Box
                sx={{ width: 250 }}
                role="presentation"
            >
                <List>
                    <ListItem className="mobile-menu-item" onClick={() => handleMobileMenuItemClick('/')}>
                        <ListItemIcon>
                            <HomeIcon />
                        </ListItemIcon>
                        <ListItemText primary={t.home} />
                    </ListItem>
                    <ListItem className="mobile-menu-item" onClick={() => handleMobileMenuItemClick('/categories')}>
                        <ListItemIcon>
                            <CategoryIcon />
                        </ListItemIcon>
                        <ListItemText primary={t.categories} />
                    </ListItem>
                    <Divider />
                    
                    {!user ? (
                        <>
                            <ListItem className="mobile-menu-item" onClick={() => handleMobileMenuItemClick('/login')}>
                                <ListItemIcon>
                                    <LoginIcon />
                                </ListItemIcon>
                                <ListItemText primary={t.login} />
                            </ListItem>
                            <ListItem className="mobile-menu-item" onClick={() => handleMobileMenuItemClick('/register')}>
                                <ListItemIcon>
                                    <PersonAddIcon />
                                </ListItemIcon>
                                <ListItemText primary={t.register} />
                            </ListItem>
                        </>
                    ) : (
                        <>
                            <ListItem className="mobile-menu-item" onClick={() => handleMobileMenuItemClick(`/user/${user.id}`)}>
                                <ListItemIcon>
                                    <PersonIcon />
                                </ListItemIcon>
                                <ListItemText primary={t.profile} />
                            </ListItem>
                            {user.isAdmin && (
                                <ListItem className="mobile-menu-item" onClick={() => handleMobileMenuItemClick('/admin')}>
                                    <ListItemIcon>
                                        <AdminPanelSettingsIcon />
                                    </ListItemIcon>
                                    <ListItemText primary={t.adminPanel} />
                                </ListItem>
                            )}
                            <ListItem className="mobile-menu-item" onClick={handleLogout}>
                                <ListItemIcon>
                                    <LogoutIcon />
                                </ListItemIcon>
                                <ListItemText primary={t.logout} />
                            </ListItem>
                        </>
                    )}
                    
                    <Divider />
                    <ListItem className="mobile-menu-item" onClick={() => handleMobileMenuItemClick('/terms')}>
                        <ListItemIcon>
                            <DescriptionIcon />
                        </ListItemIcon>
                        <ListItemText primary={t.terms} />
                    </ListItem>
                    <ListItem className="mobile-menu-item" onClick={() => handleMobileMenuItemClick('/contacts')}>
                        <ListItemIcon>
                            <ContactsIcon />
                        </ListItemIcon>
                        <ListItemText primary={t.contacts} />
                    </ListItem>
                </List>
            </Box>
        </Drawer>
    );

    return (
        <AppBar position="static" color="primary">
            <Container maxWidth="lg" className="header-nav-container">
                <Toolbar disableGutters>
                    {isMobile && (
                        <IconButton
                            edge="start"
                            color="inherit"
                            aria-label="menu"
                            onClick={toggleMobileMenu}
                            sx={{ mr: 2 }}
                            className="nav-icon-button"
                        >
                            <MenuIcon />
                        </IconButton>
                    )}
                    
                    <Typography
                        variant="h6"
                        noWrap
                        component={Link}
                        to="/"
                        sx={{
                            mr: 2,
                            fontWeight: 700,
                            color: 'white',
                            textDecoration: 'none',
                            flexGrow: isMobile ? 1 : 0
                        }}
                    >
                        {t.siteTitle}
                    </Typography>
                    
                    <Box sx={{ flexGrow: 1, display: { xs: 'none', md: 'flex' } }} className="nav-menu-desktop">
                        <Button
                            color="inherit"
                            component={Link}
                            to="/"
                            sx={{ my: 2, display: 'block' }}
                        >
                            {t.home}
                        </Button>
                        <Button
                            color="inherit"
                            component={Link}
                            to="/categories"
                            sx={{ my: 2, display: 'block' }}
                        >
                            {t.categories}
                        </Button>
                    </Box>
                    
                    <Box sx={{ display: 'flex', alignItems: 'center' }}>
                        <FormControl variant="outlined" size="small" sx={{ m: 1, minWidth: 120, backgroundColor: 'white', borderRadius: 1 }}>
                            <Select
                                value={language}
                                onChange={handleChangeLanguage}
                                inputProps={{
                                    name: 'language',
                                    id: 'language-select',
                                }}
                            >
                                <MenuItem value="ru">Русский</MenuItem>
                                <MenuItem value="en">English</MenuItem>
                            </Select>
                        </FormControl>
                        
                        {!isMobile && !user && (
                            <Box>
                                <Button color="inherit" onClick={handleLogin}>
                                    {t.login}
                                </Button>
                                <Button 
                                    color="inherit" 
                                    component={Link} 
                                    to="/register" 
                                    sx={{ 
                                        backgroundColor: 'rgba(255,255,255,0.1)',
                                        '&:hover': {
                                            backgroundColor: 'rgba(255,255,255,0.2)'
                                        }
                                    }}
                                >
                                    {t.register}
                                </Button>
                            </Box>
                        )}
                        
                        {!isMobile && user && (
                            <Box>
                                <IconButton
                                    size="large"
                                    aria-label="account of current user"
                                    aria-controls="menu-appbar"
                                    aria-haspopup="true"
                                    onClick={handleMenu}
                                    color="inherit"
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
                                    <MenuItem component={Link} to={`/user/${user.id}`} onClick={handleClose}>
                                        {t.profile}
                                    </MenuItem>
                                    {user.isAdmin && (
                                        <MenuItem component={Link} to="/admin" onClick={handleClose}>
                                            {t.adminPanel}
                                        </MenuItem>
                                    )}
                                    <MenuItem onClick={handleLogout}>{t.logout}</MenuItem>
                                </Menu>
                            </Box>
                        )}
                    </Box>
                </Toolbar>
            </Container>
            {mobileMenu}
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
