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
    CssBaseline,
    useMediaQuery,
    useTheme,
    Drawer,
    List,
    ListItem,
    ListItemText,
    ListItemIcon,
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
import FavoriteBooks from './components/FavoriteBooks';
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
import MenuIcon from '@mui/icons-material/Menu';
import HomeIcon from '@mui/icons-material/Home';
import CategoryIcon from '@mui/icons-material/Category';
import CloseIcon from '@mui/icons-material/Close';
import FavoriteIcon from '@mui/icons-material/Favorite';

const NavBar = () => {
    const { user, setUser } = useContext(UserContext);
    const { language, setLanguage } = useContext(LanguageContext);
    const navigate = useNavigate();
    const [anchorEl, setAnchorEl] = React.useState(null);
    const [drawerOpen, setDrawerOpen] = React.useState(false);
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    
    // Получаем переводы для текущего языка
    const t = translations[language];

    const handleMenu = (event) => {
        setAnchorEl(event.currentTarget);
    };

    const handleClose = () => {
        setAnchorEl(null);
    };
    
    // Управление мобильным меню
    const toggleDrawer = (open) => (event) => {
        if (event.type === 'keydown' && (event.key === 'Tab' || event.key === 'Shift')) {
            return;
        }
        setDrawerOpen(open);
    };

    // Реализация функции выхода из системы
    const handleLogout = () => {
        // Удаляем токен из cookie
        Cookies.remove('token');
        // Очищаем информацию о пользователе в контексте
        setUser(null);
        // Закрываем меню
        handleClose();
        setDrawerOpen(false);
        // Перенаправляем на главную страницу
        navigate('/');
    };

    const handleLogin = () => {
        navigate('/login');
        handleClose();
        setDrawerOpen(false);
    };

    const handleChangeLanguage = (event) => {
        setLanguage(event.target.value);
    };
    
    const handleNavigate = (path) => {
        navigate(path);
        setDrawerOpen(false);
    };
    
    // Мобильное боковое меню
    const mobileDrawer = (
        <Drawer
            anchor="left"
            open={drawerOpen}
            onClose={toggleDrawer(false)}
        >
            <Box sx={{ width: 250, pt: 2, pb: 2 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', px: 2, mb: 2 }}>
                    <Typography variant="h6" color="primary" fontWeight="bold">
                        {language === 'RU' ? 'Меню' : 'Menu'}
                    </Typography>
                    <IconButton onClick={toggleDrawer(false)}>
                        <CloseIcon />
                    </IconButton>
                </Box>
                <Divider sx={{ mb: 2 }} />
                <List>
                    <ListItem button onClick={() => handleNavigate('/')}>
                        <ListItemIcon><HomeIcon /></ListItemIcon>
                        <ListItemText primary={language === 'RU' ? 'Обзор книг' : 'Books Overview'} />
                    </ListItem>
                    <ListItem button onClick={() => handleNavigate('/categories')}>
                        <ListItemIcon><CategoryIcon /></ListItemIcon>
                        <ListItemText primary={language === 'RU' ? 'Каталог' : 'Catalog'} />
                    </ListItem>
                    {user && (
                        <ListItem button onClick={() => handleNavigate('/favorites')}>
                            <ListItemIcon><FavoriteIcon /></ListItemIcon>
                            <ListItemText primary={language === 'RU' ? 'Избранное' : 'Favorites'} />
                        </ListItem>
                    )}
                </List>
                <Divider sx={{ my: 2 }} />
                <List>
                    {user ? (
                        <>
                            <ListItem button onClick={() => handleNavigate(`/user/${user.id}`)}>
                                <ListItemIcon><PersonIcon /></ListItemIcon>
                                <ListItemText primary={language === 'RU' ? 'Мой профиль' : 'My Profile'} />
                            </ListItem>
                            <ListItem button onClick={() => handleNavigate('/subscription')}>
                                <ListItemIcon><AccessibilityNewIcon /></ListItemIcon>
                                <ListItemText primary={language === 'RU' ? 'Подписка' : 'Subscription'} />
                            </ListItem>
                            {user.role && user.role.toLowerCase() === 'admin' && (
                                <ListItem button onClick={() => handleNavigate('/admin')}>
                                    <ListItemIcon><SearchIcon /></ListItemIcon>
                                    <ListItemText primary={t.adminPanel} />
                                </ListItem>
                            )}
                            <Divider sx={{ my: 1 }} />
                            <ListItem button onClick={handleLogout}>
                                <ListItemText primary={t.logout} sx={{ color: 'error.main' }} />
                            </ListItem>
                        </>
                    ) : (
                        <ListItem button onClick={handleLogin}>
                            <ListItemIcon><PersonIcon /></ListItemIcon>
                            <ListItemText primary={t.login} />
                        </ListItem>
                    )}
                </List>
                <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2 }}>
                    <FormControl size="small" sx={{ minWidth: 70 }}>
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
            </Box>
        </Drawer>
    );

    return (
        <AppBar position="static" elevation={0} sx={{ backgroundColor: 'white', color: 'black' }}>
            <Container maxWidth="xl">
                <Toolbar sx={{ justifyContent: 'space-between', py: { xs: 1, md: 0 } }}>
                    {/* Кнопка меню для мобильных устройств */}
                    {isMobile && (
                        <IconButton
                            edge="start"
                            color="inherit"
                            aria-label="menu"
                            onClick={toggleDrawer(true)}
                            sx={{ mr: 1 }}
                        >
                            <MenuIcon />
                        </IconButton>
                    )}
                    
                    {/* Левая часть */}
                    {!isMobile && (
                        <Box sx={{ display: 'flex' }}>
                            <Button color="inherit" component={Link} to="/">
                                {language === 'RU' ? 'Обзор книг' : 'Books Overview'}
                            </Button>
                            <Button color="inherit" component={Link} to="/categories">
                                {language === 'RU' ? 'Каталог' : 'Catalog'}
                            </Button>
                            {user && (
                                <Button 
                                    color="inherit" 
                                    component={Link} 
                                    to="/favorites"
                                    startIcon={<FavoriteIcon />}
                                >
                                    {language === 'RU' ? 'Избранное' : 'Favorites'}
                                </Button>
                            )}
                        </Box>
                    )}

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
                            flexGrow: isMobile ? 1 : 0,
                            justifyContent: isMobile ? 'center' : 'flex-start'
                        }}
                    >
                        {language === 'RU' ? 'РК' : 'RB'}
                    </Typography>

                    {/* Правая часть */}
                    <Box sx={{ display: 'flex', alignItems: 'center' }}>
                        {!isMobile && (
                            <>
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
                            </>
                        )}
                        
                        {/* Переключатель языка для мобильных устройств */}
                        {isMobile && (
                            <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                <FormControl size="small" sx={{ minWidth: 70 }}>
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
                        )}
                    </Box>
                </Toolbar>
            </Container>
            {mobileDrawer}
        </AppBar>
    );
};

// Создаем внутренний компонент, который будет использовать контексты
const AppContent = () => {
    const { language } = useContext(LanguageContext);
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    
    return (
        <Box sx={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
            <NavBar />

            <Box component="main" sx={{ flex: 1, py: { xs: 2, md: 4 } }}>
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
                            <Route path="/favorites" element={<FavoriteBooks />} />
                            <Route path="/searchByTitle/:title" element={<BookSearchByTitle />} />
                            <Route path="/searchByDescription/:description" element={<BookSearchByDescription />} />
                            <Route path="/searchByCategory/:categoryId" element={<SearchByCategory />} />
                            <Route path="/searchBySeller/:sellerName" element={<SearchBySeller />} />
                            <Route path="/searchByPriceRange/:minPrice/:maxPrice" element={<SearchBooksByPriceRange />} />
                            {/* Страница профиля пользователя - доступна всем авторизованным пользователям для своего профиля и админам для всех профилей */}
                            <Route path="/user/:userId" element={<UserDetailsPage />} />
                            <Route path="/user" element={<UserDetailsPage />} />
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
                        alignItems: { xs: 'center', sm: 'flex-start' },
                        gap: { xs: 2, sm: 0 }
                    }}>
                        <Box sx={{ 
                            display: 'flex', 
                            mb: { xs: 2, sm: 0 },
                            flexDirection: { xs: 'column', sm: 'row' },
                            gap: { xs: 1.5, sm: 2 },
                            alignItems: 'center'
                        }}>
                            <Button component={Link} to="/terms" color="inherit" sx={{ px: { xs: 1, sm: 2 } }}>
                                {language === 'RU' ? 'Публичная оферта' : 'Terms of Service'}
                            </Button>
                            <Button component={Link} to="/contacts" color="inherit" sx={{ px: { xs: 1, sm: 2 } }}>
                                {language === 'RU' ? 'Контакты' : 'Contacts'}
                            </Button>
                        </Box>
                        <Typography variant="body2" color="text.secondary" align={isMobile ? 'center' : 'right'}>
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
