//src/components/UserDetailsPage.jsx
import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { getUserById, getUserSearchHistory } from '../api';
import { 
  Typography, 
  Table, 
  TableBody, 
  TableCell, 
  TableHead, 
  TableRow, 
  TablePagination, 
  Container, 
  Box, 
  Paper, 
  Grid, 
  Chip, 
  Divider, 
  Button, 
  CircularProgress,
  Card,
  CardContent,
  Alert
} from '@mui/material';

// Импорт иконок
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import PersonIcon from '@mui/icons-material/Person';
import EmailIcon from '@mui/icons-material/Email';
import BadgeIcon from '@mui/icons-material/Badge';
import VerifiedUserIcon from '@mui/icons-material/VerifiedUser';
import HistoryIcon from '@mui/icons-material/History';
import SearchIcon from '@mui/icons-material/Search';

const UserDetailsPage = () => {
    const { userId } = useParams();
    const navigate = useNavigate();
    const [user, setUser] = useState(null);
    const [searchHistory, setSearchHistory] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    useEffect(() => {
        const fetchUserData = async () => {
            try {
                setLoading(true);
                const userResponse = await getUserById(userId);
                setUser(userResponse.data);

                const historyResponse = await getUserSearchHistory(userId);
                setSearchHistory(historyResponse.data);
                setError(null);
            } catch (error) {
                console.error('Error fetching user data:', error);
                setError('Не удалось загрузить данные пользователя. Пожалуйста, попробуйте позже.');
            } finally {
                setLoading(false);
            }
        };

        fetchUserData();
    }, [userId]);

    const handleChangePage = (event, newPage) => {
        setPage(newPage);
    };

    const handleChangeRowsPerPage = (event) => {
        setRowsPerPage(+event.target.value);
        setPage(0);
    };

    // Форматирование даты
    const formatDate = (dateString) => {
        try {
            if (!dateString) return 'Не указана';
            
            const date = new Date(dateString);
            
            // Проверка валидности даты
            if (isNaN(date.getTime())) {
                return 'Некорректная дата';
            }
            
            return new Intl.DateTimeFormat('ru-RU', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            }).format(date);
        } catch (error) {
            console.error('Ошибка при форматировании даты:', error);
            return 'Некорректная дата';
        }
    };

    // Функция для генерации ссылки на поиск в зависимости от типа
    const generateSearchLink = (history) => {
        if (!history || !history.searchType || !history.query) {
            console.error('История поиска неполная:', history);
            return null;
        }

        try {
            const searchType = history.searchType.trim();
            
            // Приведение типа поиска к нижнему регистру для нечувствительного к регистру сравнения
            const searchTypeLower = searchType.toLowerCase();
            
            // Обрабатываем известные типы поиска
            if (searchTypeLower === 'title' || searchTypeLower === 'bytitle' || searchTypeLower === 'booksearchbytitle') {
                return `/searchByTitle/${encodeURIComponent(history.query)}`;
            } 
            else if (searchTypeLower === 'description' || searchTypeLower === 'bydescription' || searchTypeLower === 'booksearchbydescription') {
                return `/searchByDescription/${encodeURIComponent(history.query)}`;
            } 
            else if (searchTypeLower === 'category' || searchTypeLower === 'bycategory' || searchTypeLower === 'searchbycategory') {
                return `/searchByCategory/${encodeURIComponent(history.query)}`;
            } 
            else if (searchTypeLower === 'seller' || searchTypeLower === 'byseller' || searchTypeLower === 'searchbyseller') {
                return `/searchBySeller/${encodeURIComponent(history.query)}`;
            } 
            else if (searchTypeLower === 'pricerange' || searchTypeLower === 'bypricerange' || searchTypeLower === 'searchbooksBypricerange') {
                // Обработка диапазона цен в разных форматах
                if (history.query.includes('range:')) {
                    // Формат "range:min-max"
                    const rangeStr = history.query.replace('range:', '');
                    const [minPrice, maxPrice] = rangeStr.split('-');
                    return `/searchByPriceRange/${encodeURIComponent(minPrice)}/${encodeURIComponent(maxPrice)}`;
                } 
                else if (history.query.includes('-')) {
                    // Формат "min-max"
                    const [minPrice, maxPrice] = history.query.split('-');
                    return `/searchByPriceRange/${encodeURIComponent(minPrice)}/${encodeURIComponent(maxPrice)}`;
                } 
                else {
                    // Если формат не распознан, используем запрос как минимальную цену
                    return `/searchByPriceRange/${encodeURIComponent(history.query)}/999999`;
                }
            }
            
            // Для неизвестных типов поиска возвращаем null
            console.warn('Неизвестный тип поиска:', searchType);
            return null;
        } catch (error) {
            console.error('Ошибка при создании ссылки для истории поиска:', error, history);
            return null;
        }
    };

    if (loading) {
        return (
            <Container maxWidth="lg">
                <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '300px' }}>
                    <CircularProgress />
                </Box>
            </Container>
        );
    }

    if (error) {
        return (
            <Container maxWidth="lg" sx={{ mt: 4 }}>
                <Alert severity="error" sx={{ mb: 3, borderRadius: '12px' }}>
                    {error}
                </Alert>
                <Button 
                    variant="contained" 
                    startIcon={<ArrowBackIcon />} 
                    onClick={() => navigate(-1)}
                    sx={{ borderRadius: '8px', textTransform: 'none', fontWeight: 'bold' }}
                >
                    Вернуться назад
                </Button>
            </Container>
        );
    }

    if (!user) {
        return (
            <Container maxWidth="lg" sx={{ mt: 4 }}>
                <Alert severity="warning" sx={{ mb: 3, borderRadius: '12px' }}>
                    Пользователь не найден или у вас нет прав для просмотра информации об этом пользователе.
                </Alert>
                <Button 
                    variant="contained" 
                    startIcon={<ArrowBackIcon />} 
                    onClick={() => navigate(-1)}
                    sx={{ borderRadius: '8px', textTransform: 'none', fontWeight: 'bold' }}
                >
                    Вернуться назад
                </Button>
            </Container>
        );
    }

    return (
        <Container maxWidth="lg" sx={{ py: 4 }}>
            {/* Заголовок и кнопка назад */}
            <Box sx={{ mb: 4, display: 'flex', alignItems: 'center' }}>
                <Button 
                    onClick={() => navigate(-1)} 
                    variant="outlined" 
                    startIcon={<ArrowBackIcon />} 
                    sx={{ mr: 2, borderRadius: '8px' }}
                >
                    Назад
                </Button>
                <Typography variant="h4" component="h1" fontWeight="bold">
                    Информация о пользователе
                </Typography>
            </Box>

            {/* Информация о пользователе */}
            <Paper 
                elevation={2} 
                sx={{ 
                    p: 3, 
                    mb: 4, 
                    borderRadius: '12px', 
                    bgcolor: '#f5f8ff' 
                }}
            >
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                    <PersonIcon sx={{ fontSize: 36, color: 'primary.main', mr: 2 }} />
                    <Typography variant="h5" fontWeight="bold">
                        Данные пользователя
                    </Typography>
                </Box>

                <Grid container spacing={3}>
                    <Grid item xs={12} md={6}>
                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                                E-mail:
                            </Typography>
                            <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                <EmailIcon sx={{ mr: 1, color: 'text.secondary' }} />
                                <Typography variant="h6">{user.email}</Typography>
                            </Box>
                        </Box>

                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                                Роль:
                            </Typography>
                            <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                <BadgeIcon sx={{ mr: 1, color: 'text.secondary' }} />
                                <Chip 
                                    label={user.role || 'Пользователь'} 
                                    color={user.role === 'Admin' ? 'primary' : 'default'} 
                                    variant="outlined"
                                    sx={{ fontWeight: 'medium' }}
                                />
                            </Box>
                        </Box>
                    </Grid>
                    
                    <Grid item xs={12} md={6}>
                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                                Подписка:
                            </Typography>
                            <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                <VerifiedUserIcon sx={{ mr: 1, color: user.hasSubscription ? 'success.main' : 'error.main' }} />
                                <Chip 
                                    label={user.hasSubscription ? 'Активна' : 'Отсутствует'} 
                                    color={user.hasSubscription ? 'success' : 'error'} 
                                    sx={{ fontWeight: 'medium' }}
                                />
                            </Box>
                        </Box>
                        
                        {user.hasSubscription && user.subscription && (
                            <Box sx={{ mb: 2 }}>
                                <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                                    Действительна до:
                                </Typography>
                                <Typography variant="body1">
                                    {formatDate(user.subscription.endDate)}
                                </Typography>
                            </Box>
                        )}
                    </Grid>
                </Grid>
                
                {/* Дополнительная информация при наличии */}
                {user.registrationDate && (
                    <Box sx={{ mt: 3 }}>
                        <Divider sx={{ my: 2 }} />
                        <Typography variant="body2" color="text.secondary">
                            Зарегистрирован: {formatDate(user.registrationDate)}
                        </Typography>
                    </Box>
                )}
            </Paper>

            {/* История поиска */}
            <Paper elevation={2} sx={{ p: 3, borderRadius: '12px' }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                    <HistoryIcon sx={{ fontSize: 36, color: 'primary.main', mr: 2 }} />
                    <Typography variant="h5" fontWeight="bold">
                        История поиска
                    </Typography>
                </Box>

                {searchHistory.length > 0 ? (
                    <>
                        <Box sx={{ overflow: 'auto' }}>
                            <Table sx={{ minWidth: 650 }}>
                                <TableHead>
                                    <TableRow>
                                        <TableCell sx={{ fontWeight: 'bold' }}>Дата</TableCell>
                                        <TableCell sx={{ fontWeight: 'bold' }}>Запрос</TableCell>
                                        <TableCell sx={{ fontWeight: 'bold' }}>Тип поиска</TableCell>
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {searchHistory
                                        .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                                        .map(history => {
                                            const searchLink = generateSearchLink(history);
                                            
                                            return (
                                                <TableRow key={history.id} hover>
                                                    <TableCell>{formatDate(history.searchDate)}</TableCell>
                                                    <TableCell>
                                                        {searchLink ? (
                                                            <Link 
                                                                to={searchLink}
                                                                style={{ 
                                                                    textDecoration: 'none', 
                                                                    color: '#1976d2',
                                                                    display: 'flex',
                                                                    alignItems: 'center'
                                                                }}
                                                            >
                                                                <SearchIcon sx={{ mr: 1, fontSize: 18, color: 'primary.main' }} />
                                                                <Box 
                                                                    component="span" 
                                                                    sx={{ 
                                                                        '&:hover': { 
                                                                            textDecoration: 'underline',
                                                                            fontWeight: 'bold'
                                                                        },
                                                                        transition: 'all 0.2s',
                                                                        borderBottom: '1px dotted #1976d2'
                                                                    }}
                                                                >
                                                                    {history.query}
                                                                </Box>
                                                            </Link>
                                                        ) : (
                                                            <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                                                <SearchIcon sx={{ mr: 1, fontSize: 16, color: 'text.secondary' }} />
                                                                {history.query}
                                                            </Box>
                                                        )}
                                                    </TableCell>
                                                    <TableCell>
                                                        <Chip 
                                                            label={history.searchType} 
                                                            size="small" 
                                                            variant="outlined" 
                                                            color="primary"
                                                        />
                                                    </TableCell>
                                                </TableRow>
                                            );
                                        })}
                                </TableBody>
                            </Table>
                        </Box>
                        <TablePagination
                            component="div"
                            count={searchHistory.length}
                            page={page}
                            onPageChange={handleChangePage}
                            rowsPerPage={rowsPerPage}
                            onRowsPerPageChange={handleChangeRowsPerPage}
                            rowsPerPageOptions={[5, 10, 25]}
                            labelRowsPerPage="Записей на странице:"
                            labelDisplayedRows={({ from, to, count }) => `${from}-${to} из ${count}`}
                        />
                    </>
                ) : (
                    <Alert severity="info" sx={{ borderRadius: '8px' }}>
                        У пользователя нет истории поиска
                    </Alert>
                )}
            </Paper>
        </Container>
    );
};

export default UserDetailsPage;
