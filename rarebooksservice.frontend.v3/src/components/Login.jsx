// src/components/Login.jsx
import React, { useState, useContext } from 'react';
import { useNavigate, Link, useLocation } from 'react-router-dom';
import axios from 'axios';
import Cookies from 'js-cookie';
import { UserContext } from '../context/UserContext';
import { API_URL } from '../api';
import ErrorMessage from './ErrorMessage';
import { 
    Button, 
    TextField, 
    Typography, 
    Container, 
    Box, 
    Paper, 
    Grid, 
    Divider, 
    InputAdornment, 
    Alert,
    CircularProgress,
    IconButton
} from '@mui/material';

// Импорт иконок
import EmailIcon from '@mui/icons-material/Email';
import LockIcon from '@mui/icons-material/Lock';
import LoginIcon from '@mui/icons-material/Login';
import PersonAddIcon from '@mui/icons-material/PersonAdd';
import Visibility from '@mui/icons-material/Visibility';
import VisibilityOff from '@mui/icons-material/VisibilityOff';
import MenuBookIcon from '@mui/icons-material/MenuBook';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const { setUser } = useContext(UserContext);
    const navigate = useNavigate();
    const location = useLocation();
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const [showPassword, setShowPassword] = useState(false);

    const handleLogin = async () => {
        if (!email.trim() || !password.trim()) {
            setError('Пожалуйста, заполните все поля.');
            return;
        }

        setError('');
        setLoading(true);
        try {
            const response = await axios.post(`${API_URL}/auth/login`, { email, password });
            Cookies.set('token', response.data.token, { expires: 7 });
            // вместо Cookies:
            //localStorage.setItem('token', response.data.token);

            // прописываем пользователя в контекст
            setUser(response.data.user);
            // попытка вернуть на исходную страницу, если была сохранена
            const stateFrom = location.state && location.state.from;
            const storedReturnTo = (() => { try { return localStorage.getItem('returnTo'); } catch (_) { return null; } })();
            if (stateFrom) {
                navigate(stateFrom, { replace: true });
            } else if (storedReturnTo) {
                // Если пользователь оформляет подписку — отправим его на страницу подписки
                navigate('/subscription', { replace: true });
            } else {
                navigate('/');
            }
        } catch (err) {
            console.error('Ошибка входа:', err);
            if (err.response && err.response.status === 401) {
                setError('Неверные учетные данные. Пожалуйста, проверьте email и пароль.');
            } else if (err.response && err.response.data && err.response.data.message) {
                setError(err.response.data.message);
            } else {
                setError('Не удалось выполнить вход. Пожалуйста, попробуйте позже.');
            }
        } finally {
            setLoading(false);
        }
    };

    const handleKeyPress = (event) => {
        if (event.key === 'Enter') {
            handleLogin();
        }
    };

    const togglePasswordVisibility = () => {
        setShowPassword(!showPassword);
    };

    return (
        <Container maxWidth="sm" sx={{ py: 8 }}>
            <Paper 
                elevation={3} 
                sx={{ 
                    p: 4, 
                    borderRadius: '12px',
                    bgcolor: '#f5f8ff',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.05)'
                }}
            >
                <Box 
                    sx={{ 
                        display: 'flex', 
                        flexDirection: 'column', 
                        alignItems: 'center',
                        mb: 3
                    }}
                >
                    <Box sx={{ 
                        display: 'flex', 
                        alignItems: 'center', 
                        gap: 1.5,
                        mb: 2
                    }}>
                        <MenuBookIcon color="primary" sx={{ fontSize: 40 }} />
                        <Typography variant="h4" component="h1" fontWeight="bold" color="primary">
                            RareBooks
                        </Typography>
                    </Box>
                    
                    <Typography variant="h5" gutterBottom fontWeight="bold">
                        Вход в систему
                    </Typography>
                    <Typography variant="body2" color="text.secondary" align="center">
                        Введите ваши учетные данные для доступа к системе оценки антикварных книг
                    </Typography>
                </Box>

                {error && (
                    <Alert severity="error" sx={{ mb: 3, borderRadius: '8px' }}>
                        {error}
                    </Alert>
                )}
                
                <Box 
                    component="form" 
                    sx={{ 
                        display: 'flex', 
                        flexDirection: 'column', 
                        gap: 3
                    }}
                    noValidate
                >
                    <TextField
                        fullWidth
                        required
                        id="email"
                        label="Email"
                        variant="outlined"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        autoComplete="username"
                        autoFocus
                        onKeyPress={handleKeyPress}
                        InputProps={{
                            startAdornment: (
                                <InputAdornment position="start">
                                    <EmailIcon color="primary" />
                                </InputAdornment>
                            ),
                        }}
                        sx={{ borderRadius: '8px' }}
                    />
                    <TextField
                        fullWidth
                        required
                        id="password"
                        type={showPassword ? 'text' : 'password'}
                        label="Пароль"
                        variant="outlined"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        autoComplete="current-password"
                        onKeyPress={handleKeyPress}
                        InputProps={{
                            startAdornment: (
                                <InputAdornment position="start">
                                    <LockIcon color="primary" />
                                </InputAdornment>
                            ),
                            endAdornment: (
                                <InputAdornment position="end">
                                    <IconButton
                                        aria-label="toggle password visibility"
                                        onClick={togglePasswordVisibility}
                                        edge="end"
                                    >
                                        {showPassword ? <VisibilityOff /> : <Visibility />}
                                    </IconButton>
                                </InputAdornment>
                            ),
                        }}
                        sx={{ borderRadius: '8px' }}
                    />
                    
                    <Button 
                        variant="contained" 
                        size="large"
                        onClick={handleLogin}
                        disabled={loading}
                        startIcon={loading ? <CircularProgress size={20} /> : <LoginIcon />}
                        sx={{ 
                            py: 1.5, 
                            borderRadius: '8px',
                            textTransform: 'none',
                            fontWeight: 'bold',
                            mt: 1
                        }}
                    >
                        {loading ? 'Вход...' : 'Войти в систему'}
                    </Button>
                </Box>
                
                <Divider sx={{ my: 3 }} />
                
                <Box sx={{ textAlign: 'center' }}>
                    <Typography variant="body1" gutterBottom>
                        Нет учетной записи?
                    </Typography>
                    <Button 
                        component={Link} 
                        to="/register" 
                        variant="outlined" 
                        startIcon={<PersonAddIcon />}
                        sx={{ 
                            mt: 1, 
                            borderRadius: '8px',
                            textTransform: 'none',
                            fontWeight: 'medium'
                        }}
                    >
                        Зарегистрироваться
                    </Button>
                </Box>
            </Paper>
            
            <Box sx={{ textAlign: 'center', mt: 4 }}>
                <Typography variant="body2" color="text.secondary">
                    RareBooks — сервис для оценки и анализа антикварных книг
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                    © {new Date().getFullYear()} RareBooks. Все права защищены.
                </Typography>
            </Box>
        </Container>
    );
};

export default Login;
