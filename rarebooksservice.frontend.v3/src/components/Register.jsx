//src/components/Register.jsx
import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { getCaptcha, registerUser } from '../api'; // Импортируем функции из api.js
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
import PersonAddIcon from '@mui/icons-material/PersonAdd';
import RefreshIcon from '@mui/icons-material/Refresh';
import Visibility from '@mui/icons-material/Visibility';
import VisibilityOff from '@mui/icons-material/VisibilityOff';
import MenuBookIcon from '@mui/icons-material/MenuBook';
import VpnKeyIcon from '@mui/icons-material/VpnKey';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import ImageIcon from '@mui/icons-material/Image';

const Register = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [error, setError] = useState('');
    const [validationError, setValidationError] = useState('');
    const [captchaToken, setCaptchaToken] = useState('');
    const [captchaImage, setCaptchaImage] = useState(null);
    const [captchaCode, setCaptchaCode] = useState('');
    const [loading, setLoading] = useState(false);
    const [captchaLoading, setCaptchaLoading] = useState(false);
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirmPassword, setShowConfirmPassword] = useState(false);
    const navigate = useNavigate();

    const loadCaptcha = async () => {
        setCaptchaLoading(true);
        try {
            const response = await getCaptcha();
            const captchaTokenFromHeader = response.headers['x-captcha-token'];
            setCaptchaToken(captchaTokenFromHeader);

            const blob = new Blob([response.data], { type: 'image/png' });
            const url = URL.createObjectURL(blob);
            setCaptchaImage(url);
        } catch (error) {
            console.error('Ошибка получения CAPTCHA:', error);
            setError('Ошибка при загрузке защиты от ботов. Попробуйте позже.');
        } finally {
            setCaptchaLoading(false);
        }
    };

    useEffect(() => {
        loadCaptcha();
        
        // Очистка URL-объектов при размонтировании компонента
        return () => {
            if (captchaImage) {
                URL.revokeObjectURL(captchaImage);
            }
        };
    }, []);

    const validateForm = () => {
        if (!email.trim()) {
            setValidationError('Введите email адрес.');
            return false;
        }
        
        if (!email.includes('@') || !email.includes('.')) {
            setValidationError('Введите корректный email адрес.');
            return false;
        }
        
        if (!password.trim()) {
            setValidationError('Введите пароль.');
            return false;
        }
        
        if (password.length < 6) {
            setValidationError('Пароль должен содержать не менее 6 символов.');
            return false;
        }
        
        if (password !== confirmPassword) {
            setValidationError('Пароли не совпадают.');
            return false;
        }
        
        if (!captchaCode.trim()) {
            setValidationError('Введите код с картинки.');
            return false;
        }
        
        return true;
    };

    const handleRegister = async () => {
        setError('');
        setValidationError('');

        if (!validateForm()) {
            return;
        }

        setLoading(true);
        try {
            await registerUser({
                email,
                password,
                captchaToken,
                captchaCode
            });
            // Сообщаем об успешной регистрации
            navigate('/login', { 
                state: { 
                    message: 'Регистрация прошла успешно! Теперь вы можете войти в систему.',
                    severity: 'success'
                } 
            });
        } catch (error) {
            console.error('Ошибка регистрации:', error.response?.data);
            setError(error.response?.data?.error ?? 'Ошибка при регистрации. Проверьте введенные данные или попробуйте позже.');
            // Обновляем капчу при ошибке
            reloadCaptcha();
        } finally {
            setLoading(false);
        }
    };

    const reloadCaptcha = async () => {
        setError('');
        setValidationError('');
        setCaptchaCode('');
        if (captchaImage) {
            URL.revokeObjectURL(captchaImage);
        }
        setCaptchaImage(null);
        setCaptchaToken('');
        await loadCaptcha();
    };

    const handleKeyPress = (event) => {
        if (event.key === 'Enter') {
            handleRegister();
        }
    };

    const togglePasswordVisibility = () => {
        setShowPassword(!showPassword);
    };

    const toggleConfirmPasswordVisibility = () => {
        setShowConfirmPassword(!showConfirmPassword);
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
                        Регистрация
                    </Typography>
                    <Typography variant="body2" color="text.secondary" align="center">
                        Создайте учетную запись для доступа к системе оценки антикварных книг
                    </Typography>
                </Box>

                {(error || validationError) && (
                    <Alert severity="error" sx={{ mb: 3, borderRadius: '8px' }}>
                        {error || validationError}
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
                        autoComplete="email"
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
                        autoComplete="new-password"
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
                    <TextField
                        fullWidth
                        required
                        id="confirmPassword"
                        type={showConfirmPassword ? 'text' : 'password'}
                        label="Подтверждение пароля"
                        variant="outlined"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        autoComplete="new-password"
                        onKeyPress={handleKeyPress}
                        InputProps={{
                            startAdornment: (
                                <InputAdornment position="start">
                                    <VpnKeyIcon color="primary" />
                                </InputAdornment>
                            ),
                            endAdornment: (
                                <InputAdornment position="end">
                                    <IconButton
                                        aria-label="toggle confirm password visibility"
                                        onClick={toggleConfirmPasswordVisibility}
                                        edge="end"
                                    >
                                        {showConfirmPassword ? <VisibilityOff /> : <Visibility />}
                                    </IconButton>
                                </InputAdornment>
                            ),
                        }}
                        sx={{ borderRadius: '8px' }}
                    />
                    
                    <Paper elevation={1} sx={{ p: 2, borderRadius: '8px', bgcolor: '#f0f4ff' }}>
                        <Typography variant="subtitle2" fontWeight="medium" gutterBottom>
                            Защита от ботов
                        </Typography>
                        
                        <Box sx={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 2, mb: 2 }}>
                            {captchaLoading ? (
                                <Box sx={{ 
                                    display: 'flex', 
                                    justifyContent: 'center', 
                                    alignItems: 'center', 
                                    width: 180, 
                                    height: 70, 
                                    bgcolor: '#e0e0e0',
                                    borderRadius: '4px'
                                }}>
                                    <CircularProgress size={24} />
                                </Box>
                            ) : captchaImage ? (
                                <Box sx={{ 
                                    display: 'flex', 
                                    justifyContent: 'center', 
                                    alignItems: 'center', 
                                    width: 180,
                                    border: '1px solid #e0e0e0',
                                    borderRadius: '4px',
                                    overflow: 'hidden'
                                }}>
                                    <img 
                                        src={captchaImage} 
                                        alt="CAPTCHA" 
                                        style={{ maxWidth: '100%', height: 'auto' }} 
                                    />
                                </Box>
                            ) : (
                                <Box sx={{ 
                                    display: 'flex', 
                                    justifyContent: 'center', 
                                    alignItems: 'center', 
                                    width: 180, 
                                    height: 70, 
                                    bgcolor: '#e0e0e0',
                                    borderRadius: '4px'
                                }}>
                                    <ImageIcon color="disabled" />
                                </Box>
                            )}
                            
                            <Button 
                                variant="outlined" 
                                size="small" 
                                startIcon={<RefreshIcon />} 
                                onClick={reloadCaptcha}
                                disabled={captchaLoading}
                                sx={{ borderRadius: '8px', textTransform: 'none' }}
                            >
                                Обновить
                            </Button>
                        </Box>
                        
                        <TextField
                            fullWidth
                            required
                            id="captchaCode"
                            label="Код с картинки"
                            variant="outlined"
                            value={captchaCode}
                            onChange={(e) => setCaptchaCode(e.target.value)}
                            onKeyPress={handleKeyPress}
                            size="small"
                            sx={{ borderRadius: '8px' }}
                        />
                    </Paper>
                    
                    <Button 
                        variant="contained" 
                        size="large"
                        onClick={handleRegister}
                        disabled={loading}
                        startIcon={loading ? <CircularProgress size={20} /> : <PersonAddIcon />}
                        sx={{ 
                            py: 1.5, 
                            borderRadius: '8px',
                            textTransform: 'none',
                            fontWeight: 'bold',
                            mt: 1
                        }}
                    >
                        {loading ? 'Регистрация...' : 'Зарегистрироваться'}
                    </Button>
                </Box>
                
                <Divider sx={{ my: 3 }} />
                
                <Box sx={{ textAlign: 'center' }}>
                    <Typography variant="body1" gutterBottom>
                        Уже есть аккаунт?
                    </Typography>
                    <Button 
                        component={Link} 
                        to="/login" 
                        variant="outlined" 
                        startIcon={<ArrowBackIcon />}
                        sx={{ 
                            mt: 1, 
                            borderRadius: '8px',
                            textTransform: 'none',
                            fontWeight: 'medium'
                        }}
                    >
                        Вернуться к входу
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

export default Register;
