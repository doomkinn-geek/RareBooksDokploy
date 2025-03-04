//src/components/UserDetailsPage.jsx
import React, { useEffect, useState, useContext } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { getUserProfile, getUserSearchHistoryNew, getUserById, getUserSearchHistory } from '../api';
import { UserContext } from '../context/UserContext';
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
    const { user: currentUser } = useContext(UserContext);

    useEffect(() => {
        const fetchUserData = async () => {
            // Если контекст пользователя еще загружается, просто ждем
            if (currentUser === null) {
                // Не меняем статус загрузки, если это первый рендер
                return;
            }
            
            try {
                setLoading(true);
                
                // Проверяем валидность userId
                if (!userId) {
                    console.error('UserId is undefined');
                    setError('Идентификатор пользователя не указан');
                    setLoading(false);
                    return;
                }

                // Проверяем права доступа
                const isAdmin = currentUser && currentUser.role && currentUser.role.toLowerCase() === 'admin';
                const isCurrentUser = currentUser && userId === currentUser.id;
                
                // Если пользователь не админ и пытается просмотреть чужой профиль
                if (!isAdmin && !isCurrentUser) {
                    console.error('Access denied: trying to view another user profile without admin rights');
                    setError('У вас нет доступа к этой информации. Вы можете просматривать только свой профиль.');
                    setLoading(false);
                    return;
                }

                let userResponse;
                let historyResponse;

                // Используем новые методы API для обычных пользователей и старые для администраторов
                if (isAdmin) {
                    // Администратор может использовать старые методы
                    console.log('Using admin methods for userId:', userId);
                    userResponse = await getUserById(userId);
                    historyResponse = await getUserSearchHistory(userId);
                } else {
                    // Обычные пользователи используют новые методы
                    console.log('Using regular methods for userId:', userId);
                    userResponse = await getUserProfile(userId);
                    historyResponse = await getUserSearchHistoryNew(userId);
                }
                
                setUser(userResponse.data);
                setSearchHistory(historyResponse.data);
                setError(null);
            } catch (error) {
                console.error('Error fetching user data:', error);
                if (error.response && error.response.status === 403) {
                    setError('У вас нет доступа к этой информации. Вы можете просматривать только свой профиль.');
                } else {
                    setError('Не удалось загрузить данные пользователя. Пожалуйста, попробуйте позже.');
                }
            } finally {
                setLoading(false);
            }
        };

        fetchUserData();
    }, [userId, currentUser]); // Добавляем currentUser в зависимости

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
        <Container maxWidth="lg" sx={{ py: { xs: 2, md: 4 } }}>
            {/* Заголовок и кнопка назад */}
            <Box sx={{ 
                mb: { xs: 2, md: 4 }, 
                display: 'flex', 
                flexDirection: { xs: 'column', sm: 'row' }, 
                alignItems: { xs: 'flex-start', sm: 'center' },
                gap: { xs: 2, sm: 0 }
            }}>
                <Button 
                    onClick={() => navigate(-1)} 
                    variant="outlined" 
                    startIcon={<ArrowBackIcon />} 
                    sx={{ 
                        mr: { xs: 0, sm: 2 }, 
                        borderRadius: '8px',
                        alignSelf: { xs: 'flex-start', sm: 'auto' }
                    }}
                >
                    Назад
                </Button>
                <Typography 
                    variant="h4" 
                    component="h1" 
                    fontWeight="bold"
                    sx={{ 
                        fontSize: { xs: '1.5rem', sm: '2rem', md: '2.125rem' }
                    }}
                >
                    {currentUser && userId === currentUser.id ? 'Мой профиль' : 'Информация о пользователе'}
                </Typography>
            </Box>

            {/* Информация о пользователе */}
            <Paper 
                elevation={2} 
                sx={{ 
                    p: { xs: 2, md: 3 }, 
                    mb: { xs: 3, md: 4 }, 
                    borderRadius: '12px', 
                    bgcolor: '#f5f8ff' 
                }}
            >
                <Box sx={{ 
                    display: 'flex', 
                    alignItems: 'center', 
                    mb: { xs: 2, md: 3 }
                }}>
                    <PersonIcon sx={{ fontSize: { xs: 28, md: 36 }, color: 'primary.main', mr: 2 }} />
                    <Typography 
                        variant="h5" 
                        fontWeight="bold"
                        sx={{ fontSize: { xs: '1.25rem', md: '1.5rem' } }}
                    >
                        Данные пользователя
                    </Typography>
                </Box>

                <Grid container spacing={2}>
                    <Grid item xs={12} md={6}>
                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                                E-mail:
                            </Typography>
                            <Box sx={{ display: 'flex', alignItems: 'center', wordBreak: 'break-word' }}>
                                <EmailIcon sx={{ mr: 1, color: 'text.secondary', flexShrink: 0 }} />
                                <Typography variant="h6" sx={{ fontSize: { xs: '1rem', md: '1.25rem' } }}>
                                    {user.email}
                                </Typography>
                            </Box>
                        </Box>

                        <Box sx={{ mb: 2 }}>
                            <Typography variant="subtitle1" color="text.secondary" gutterBottom>
                                Роль:
                            </Typography>
                            <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                <BadgeIcon sx={{ mr: 1, color: 'text.secondary', flexShrink: 0 }} />
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
                                <VerifiedUserIcon sx={{ 
                                    mr: 1, 
                                    color: user.hasSubscription ? 'success.main' : 'error.main',
                                    flexShrink: 0
                                }} />
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
            <Paper 
                elevation={2} 
                sx={{ 
                    p: { xs: 2, md: 3 }, 
                    borderRadius: '12px' 
                }}
            >
                <Box sx={{ 
                    display: 'flex', 
                    alignItems: 'center', 
                    mb: { xs: 2, md: 3 } 
                }}>
                    <HistoryIcon sx={{ fontSize: { xs: 28, md: 36 }, color: 'primary.main', mr: 2 }} />
                    <Typography 
                        variant="h5" 
                        fontWeight="bold"
                        sx={{ fontSize: { xs: '1.25rem', md: '1.5rem' } }}
                    >
                        История поиска
                    </Typography>
                </Box>

                {searchHistory.length > 0 ? (
                    <>
                        <Box sx={{ 
                            overflow: 'auto',
                            '&::-webkit-scrollbar': {
                                height: '8px',
                            },
                            '&::-webkit-scrollbar-thumb': {
                                backgroundColor: 'rgba(0,0,0,0.2)',
                                borderRadius: '4px',
                            },
                        }}>
                            <Table sx={{ 
                                minWidth: { xs: 300, sm: 500, md: 650 }
                            }}>
                                <TableHead>
                                    <TableRow>
                                        <TableCell sx={{ 
                                            fontWeight: 'bold',
                                            padding: { xs: '8px 6px', md: '16px' }
                                        }}>Дата</TableCell>
                                        <TableCell sx={{ 
                                            fontWeight: 'bold',
                                            padding: { xs: '8px 6px', md: '16px' }
                                        }}>Запрос</TableCell>
                                        <TableCell sx={{ 
                                            fontWeight: 'bold',
                                            padding: { xs: '8px 6px', md: '16px' }
                                        }}>Тип поиска</TableCell>
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {searchHistory
                                        .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                                        .map(history => {
                                            const searchLink = generateSearchLink(history);
                                            
                                            return (
                                                <TableRow key={history.id} hover>
                                                    <TableCell sx={{ 
                                                        padding: { xs: '8px 6px', md: '16px' },
                                                        whiteSpace: { xs: 'nowrap', md: 'normal' }
                                                    }}>
                                                        {formatDate(history.searchDate)}
                                                    </TableCell>
                                                    <TableCell sx={{ 
                                                        padding: { xs: '8px 6px', md: '16px' },
                                                        maxWidth: { xs: '120px', sm: '200px', md: 'none' },
                                                        overflow: 'hidden',
                                                        textOverflow: 'ellipsis'
                                                    }}>
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
                                                                <SearchIcon sx={{ mr: 1, fontSize: 18, color: 'primary.main', flexShrink: 0 }} />
                                                                <Box 
                                                                    component="span" 
                                                                    sx={{ 
                                                                        '&:hover': { 
                                                                            textDecoration: 'underline',
                                                                            fontWeight: 'bold'
                                                                        },
                                                                        transition: 'all 0.2s',
                                                                        borderBottom: '1px dotted #1976d2',
                                                                        overflow: 'hidden',
                                                                        textOverflow: 'ellipsis',
                                                                        whiteSpace: { xs: 'nowrap', md: 'normal' }
                                                                    }}
                                                                >
                                                                    {history.query}
                                                                </Box>
                                                            </Link>
                                                        ) : (
                                                            <Box sx={{ 
                                                                display: 'flex', 
                                                                alignItems: 'center',
                                                                overflow: 'hidden',
                                                                textOverflow: 'ellipsis',
                                                                whiteSpace: { xs: 'nowrap', md: 'normal' }
                                                            }}>
                                                                <SearchIcon sx={{ mr: 1, fontSize: 16, color: 'text.secondary', flexShrink: 0 }} />
                                                                <span>{history.query}</span>
                                                            </Box>
                                                        )}
                                                    </TableCell>
                                                    <TableCell sx={{ 
                                                        padding: { xs: '8px 6px', md: '16px' }
                                                    }}>
                                                        <Chip 
                                                            label={history.searchType} 
                                                            size="small" 
                                                            variant="outlined" 
                                                            color="primary"
                                                            sx={{
                                                                height: { xs: '24px', md: '32px' },
                                                                fontSize: { xs: '0.75rem', md: '0.875rem' }
                                                            }}
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
                            labelRowsPerPage="Записей:"
                            labelDisplayedRows={({ from, to, count }) => `${from}-${to} из ${count}`}
                            sx={{
                                '.MuiTablePagination-toolbar': {
                                    flexWrap: 'wrap',
                                    justifyContent: { xs: 'center', sm: 'flex-end' },
                                    padding: { xs: '8px 0', md: '8px' }
                                },
                                '.MuiTablePagination-displayedRows': {
                                    margin: { xs: '8px 0', md: 0 }
                                },
                                '.MuiTablePagination-selectLabel': {
                                    margin: { xs: '8px 0', md: 0 }
                                }
                            }}
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
