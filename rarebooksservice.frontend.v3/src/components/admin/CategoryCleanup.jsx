import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Paper, Button, TextField, Alert, 
    Table, TableBody, TableCell, TableContainer, TableHead, 
    TableRow, Chip, CircularProgress, Card, CardContent,
    Divider, Grid, Dialog, DialogActions, DialogContent,
    DialogContentText, DialogTitle, TablePagination, Tooltip,
    IconButton, useMediaQuery, List, ListItem, ListItemText,
    Accordion, AccordionSummary, AccordionDetails, Collapse
} from '@mui/material';
import { getAllCategoriesWithBooksCount, analyzeCategoriesByNames, analyzeUnwantedCategories, 
    deleteCategoriesByNames, deleteUnwantedCategories } from '../../api';
import DeleteIcon from '@mui/icons-material/Delete';
import AnalyticsIcon from '@mui/icons-material/Analytics';
import WarningIcon from '@mui/icons-material/Warning';
import ErrorIcon from '@mui/icons-material/Error';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import RefreshIcon from '@mui/icons-material/Refresh';
import FilterListIcon from '@mui/icons-material/FilterList';
import ContentCopyIcon from '@mui/icons-material/ContentCopy';
import LockIcon from '@mui/icons-material/Lock';
import Cookies from 'js-cookie';
import axios from 'axios';
import { API_URL } from '../../api';
import { useTheme } from '@mui/material/styles';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import InfoIcon from '@mui/icons-material/Info';

// Функция для декодирования JWT токена
const parseJwt = (token) => {
    try {
        // Разбираем JWT токен (формат: header.payload.signature)
        const base64Url = token.split('.')[1];
        const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
        const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
            return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
        }).join(''));

        return JSON.parse(jsonPayload);
    } catch (e) {
        console.error('Ошибка разбора JWT токена:', e);
        return null;
    }
};

const CategoryCleanup = () => {
    // Состояния для анализа и удаления произвольных категорий
    const [categoryNames, setCategoryNames] = useState('');
    const [analysisResult, setAnalysisResult] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [accessDenied, setAccessDenied] = useState(false);
    const [tokenInfo, setTokenInfo] = useState(null);

    // Состояния для анализа и удаления нежелательных категорий
    const [unwantedAnalysisResult, setUnwantedAnalysisResult] = useState(null);
    const [unwantedLoading, setUnwantedLoading] = useState(false);

    // Состояние для диалога подтверждения
    const [confirmDialogOpen, setConfirmDialogOpen] = useState(false);
    const [confirmAction, setConfirmAction] = useState(null);
    const [confirmData, setConfirmData] = useState(null);

    // Состояние для списка всех категорий
    const [categories, setCategories] = useState([]);
    const [loadingCategories, setLoadingCategories] = useState(false);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [showOnlyUnwanted, setShowOnlyUnwanted] = useState(false);

    // Добавляем определение мобильного устройства
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('md'));
    
    // Добавляем состояние для раскрытых элементов на мобильном
    const [expandedCategory, setExpandedCategory] = useState(null);
    
    // Загрузка списка категорий при монтировании компонента
    useEffect(() => {
        // Проверяем и анализируем токен, затем проверяем права через API
        const token = Cookies.get('token');
        if (token) {
            const decodedToken = parseJwt(token);
            setTokenInfo(decodedToken);
            console.log("Декодированный токен:", decodedToken);
            
            // Проверяем роли в токене (для отладки)
            const roles = decodedToken?.["http://schemas.microsoft.com/ws/2008/06/identity/claims/role"];
            console.log("Роли пользователя из токена:", roles);
            
            // Вместо проверки роли только из токена, проверяем роль через API
            checkUserRole().then(isAdmin => {
                if (isAdmin) {
                    loadCategories();
                }
            });
        } else {
            console.log("Токен не найден!");
            setAccessDenied(true);
            setError('Токен авторизации не найден. Пожалуйста, выполните вход в систему.');
        }
    }, []);

    // Функция для прямой проверки роли пользователя через API
    const checkUserRole = async () => {
        setLoading(true);
        try {
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/auth/user`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            console.log("Данные пользователя:", response.data);
            
            // Проверяем права из API-ответа
            const isAdmin = response.data.role === 'Admin';
            console.log("Пользователь является администратором:", isAdmin);
            
            if (!isAdmin) {
                setAccessDenied(true);
                setError('Пользователь не имеет роли Admin. Обратитесь к администратору для получения необходимых прав.');
                return false;
            }
            
            return true;
        } catch (err) {
            console.error('Ошибка при проверке роли пользователя:', err);
            setError(`Ошибка при проверке роли: ${err.message}`);
            setAccessDenied(true);
            return false;
        } finally {
            setLoading(false);
        }
    };

    // Функция загрузки списка категорий
    const loadCategories = async () => {
        setLoadingCategories(true);
        setError('');
        setAccessDenied(false);

        try {
            // Логируем заголовки перед запросом
            const token = Cookies.get('token');
            console.log("Токен для запроса:", token);
            console.log("Заголовки:", { Authorization: `Bearer ${token}` });
            
            const response = await getAllCategoriesWithBooksCount();
            console.log("Ответ от API:", response);
            setCategories(response.data);
        } catch (err) {
            console.error('Ошибка при загрузке категорий:', err);
            console.log("Детали ошибки:", err.response);
            if (err.response && err.response.status === 403) {
                setAccessDenied(true);
                setError('Доступ запрещен. Для работы с этим разделом требуются права администратора.');
            } else {
                setError(err.response?.data?.message || `Произошла ошибка при загрузке списка категорий: ${err.message}`);
            }
        } finally {
            setLoadingCategories(false);
        }
    };

    // Обработка изменения страницы
    const handleChangePage = (event, newPage) => {
        setPage(newPage);
    };

    // Обработка изменения количества строк на странице
    const handleChangeRowsPerPage = (event) => {
        setRowsPerPage(parseInt(event.target.value, 10));
        setPage(0);
    };

    // Анализ произвольных категорий
    const handleAnalyzeCategories = async () => {
        if (!categoryNames.trim()) {
            setError('Пожалуйста, введите названия категорий, разделенные запятыми');
            return;
        }

        setLoading(true);
        setError('');
        setSuccess('');
        setAnalysisResult(null);

        try {
            const namesToAnalyze = categoryNames.split(',').map(name => name.trim());
            const response = await analyzeCategoriesByNames(namesToAnalyze);
            setAnalysisResult(response.data);
        } catch (err) {
            console.error('Ошибка при анализе категорий:', err);
            setError(err.response?.data?.message || 'Произошла ошибка при анализе категорий');
        } finally {
            setLoading(false);
        }
    };

    // Анализ нежелательных категорий
    const handleAnalyzeUnwantedCategories = async () => {
        setUnwantedLoading(true);
        setError('');
        setSuccess('');
        setUnwantedAnalysisResult(null);

        try {
            const response = await analyzeUnwantedCategories();
            setUnwantedAnalysisResult(response.data);
        } catch (err) {
            console.error('Ошибка при анализе нежелательных категорий:', err);
            setError(err.response?.data?.message || 'Произошла ошибка при анализе нежелательных категорий');
        } finally {
            setUnwantedLoading(false);
        }
    };

    // Открытие диалога подтверждения удаления
    const openConfirmDialog = (action, data) => {
        setConfirmAction(action);
        setConfirmData(data);
        setConfirmDialogOpen(true);
    };

    // Закрытие диалога подтверждения
    const closeConfirmDialog = () => {
        setConfirmDialogOpen(false);
        setConfirmAction(null);
        setConfirmData(null);
    };

    // Удаление произвольных категорий
    const handleDeleteCategories = async () => {
        setLoading(true);
        setError('');
        setSuccess('');

        try {
            const namesToDelete = confirmData;
            const response = await deleteCategoriesByNames(namesToDelete);
            setSuccess(response.data.message || 'Категории успешно удалены');
            setAnalysisResult(null); // Сбрасываем результат анализа после удаления
            loadCategories(); // Перезагружаем список категорий
        } catch (err) {
            console.error('Ошибка при удалении категорий:', err);
            setError(err.response?.data?.message || 'Произошла ошибка при удалении категорий');
        } finally {
            setLoading(false);
            closeConfirmDialog();
        }
    };

    // Удаление нежелательных категорий
    const handleDeleteUnwantedCategories = async () => {
        setUnwantedLoading(true);
        setError('');
        setSuccess('');

        try {
            const response = await deleteUnwantedCategories();
            setSuccess(response.data.message || 'Нежелательные категории успешно удалены');
            setUnwantedAnalysisResult(null); // Сбрасываем результат анализа после удаления
            loadCategories(); // Перезагружаем список категорий
        } catch (err) {
            console.error('Ошибка при удалении нежелательных категорий:', err);
            setError(err.response?.data?.message || 'Произошла ошибка при удалении нежелательных категорий');
        } finally {
            setUnwantedLoading(false);
            closeConfirmDialog();
        }
    };

    // Обработка подтверждения действия
    const handleConfirmAction = () => {
        if (confirmAction === 'deleteCategories') {
            handleDeleteCategories();
        } else if (confirmAction === 'deleteUnwantedCategories') {
            handleDeleteUnwantedCategories();
        } else if (confirmAction === 'deleteSingleCategory') {
            const categoryName = confirmData;
            handleDeleteCategories();
        }
    };

    // Функция для отображения диалога подтверждения
    const renderConfirmDialog = () => {
        let title = 'Подтверждение удаления';
        let content = 'Вы уверены, что хотите удалить выбранные категории?';

        if (confirmAction === 'deleteCategories' && confirmData) {
            const categoryCount = confirmData.length;
            content = `Вы собираетесь удалить ${categoryCount} ${categoryCount === 1 ? 'категорию' : 'категории/й'}: ${confirmData.join(', ')}.\n\nЭта операция не может быть отменена. Хотите продолжить?`;
        } else if (confirmAction === 'deleteUnwantedCategories') {
            content = 'Вы собираетесь удалить все нежелательные категории ("unknown" и "interested") и связанные с ними книги. Эта операция не может быть отменена. Хотите продолжить?';
        } else if (confirmAction === 'deleteSingleCategory') {
            content = `Вы собираетесь удалить категорию "${confirmData}" и все связанные с ней книги. Эта операция не может быть отменена. Хотите продолжить?`;
        }

        return (
            <Dialog
                open={confirmDialogOpen}
                onClose={closeConfirmDialog}
            >
                <DialogTitle>{title}</DialogTitle>
                <DialogContent>
                    <DialogContentText>
                        {content}
                    </DialogContentText>
                </DialogContent>
                <DialogActions>
                    <Button onClick={closeConfirmDialog}>Отмена</Button>
                    <Button 
                        onClick={handleConfirmAction} 
                        color="error" 
                        variant="contained"
                        startIcon={<DeleteIcon />}
                    >
                        Удалить
                    </Button>
                </DialogActions>
            </Dialog>
        );
    };

    // Фильтрация категорий
    const filteredCategories = showOnlyUnwanted
        ? categories.filter(category => category.isUnwanted)
        : categories;

    // Форматирование даты
    const formatDate = (dateString) => {
        if (!dateString) return '-';
        const date = new Date(dateString);
        return date.toLocaleString('ru-RU');
    };

    // Функция для обработки нажатий на категорию в мобильном представлении
    const handleCategoryExpand = (categoryId) => {
        setExpandedCategory(expandedCategory === categoryId ? null : categoryId);
    };

    // Мобильное представление категории
    const renderMobileCategoryItem = (category) => {
        const isExpanded = expandedCategory === category.id;
        
        return (
            <Paper 
                elevation={1} 
                sx={{ 
                    mb: 1, 
                    overflow: 'hidden',
                    borderLeft: category.isUnwanted ? '4px solid #f44336' : '4px solid #4caf50'
                }}
                key={category.id}
            >
                <ListItem 
                    button 
                    onClick={() => handleCategoryExpand(category.id)}
                    sx={{ 
                        p: 2, 
                        display: 'flex', 
                        flexDirection: 'column', 
                        alignItems: 'flex-start'
                    }}
                >
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', width: '100%', mb: 1 }}>
                        <Typography variant="subtitle1" sx={{ fontWeight: 'medium' }}>
                            {category.name}
                        </Typography>
                        <Box>
                            {category.isUnwanted ? (
                                <Chip 
                                    label="Нежелательная" 
                                    color="error" 
                                    size="small" 
                                    icon={<WarningIcon />} 
                                />
                            ) : (
                                <Chip 
                                    label="Обычная" 
                                    color="success" 
                                    size="small" 
                                />
                            )}
                        </Box>
                    </Box>
                    
                    <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', width: '100%' }}>
                        <Chip 
                            label={`ID: ${category.id}`}
                            size="small" 
                            variant="outlined"
                        />
                        <Chip 
                            label={`Книг: ${category.booksCount}`} 
                            color={category.booksCount > 0 ? "primary" : "default"} 
                            size="small" 
                        />
                    </Box>
                </ListItem>
                
                <Collapse in={isExpanded} timeout="auto" unmountOnExit>
                    <Box sx={{ p: 2, pt: 0, bgcolor: 'background.default' }}>
                        <List dense disablePadding>
                            <ListItem>
                                <ListItemText 
                                    primary="Уникальные" 
                                    secondary={
                                        <Chip 
                                            label={category.uniqueBooksCount}
                                            color={category.uniqueBooksCount < category.booksCount ? "warning" : "success"}
                                            size="small"
                                        />
                                    }
                                />
                            </ListItem>
                            <ListItem>
                                <ListItemText 
                                    primary="Эксклюзивные" 
                                    secondary={
                                        <Chip 
                                            label={category.exclusiveBooksCount}
                                            color={category.exclusiveBooksCount === 0 ? "default" : 
                                                  category.exclusiveBooksCount < category.uniqueBooksCount ? "warning" : "success"}
                                            size="small"
                                        />
                                    }
                                />
                            </ListItem>
                            <ListItem>
                                <ListItemText 
                                    primary="Дубликаты" 
                                    secondary={
                                        category.hasDuplicates ? (
                                            <Chip 
                                                label={category.duplicateCount}
                                                color="warning"
                                                size="small"
                                                icon={<ContentCopyIcon />}
                                            />
                                        ) : (
                                            <Chip 
                                                label="Уникальная"
                                                color="default"
                                                size="small"
                                            />
                                        )
                                    }
                                />
                            </ListItem>
                            <ListItem>
                                <ListItemText 
                                    primary="Создана" 
                                    secondary={formatDate(category.createdDate)}
                                />
                            </ListItem>
                            <ListItem>
                                <ListItemText 
                                    primary="Обновлена" 
                                    secondary={formatDate(category.lastUpdatedDate)}
                                />
                            </ListItem>
                        </List>
                        
                        <Button
                            variant="contained"
                            color="error"
                            fullWidth
                            onClick={() => {
                                openConfirmDialog('deleteCategories', [category.name]);
                            }}
                            startIcon={<DeleteIcon />}
                            sx={{ mt: 2 }}
                        >
                            {category.hasDuplicates 
                                ? `Удалить все с именем "${category.name}" (${category.duplicateCount} шт.)`
                                : "Удалить категорию"}
                        </Button>
                    </Box>
                </Collapse>
            </Paper>
        );
    };

    // Если доступ запрещен, показываем соответствующее сообщение и отладочную информацию
    if (accessDenied) {
        return (
            <Box sx={{ mt: 3, p: 3 }}>
                <Paper elevation={3} sx={{ p: 4, textAlign: 'center' }}>
                    <LockIcon color="error" sx={{ fontSize: 60, mb: 2 }} />
                    <Typography variant="h5" gutterBottom color="error">
                        Доступ запрещен
                    </Typography>
                    <Typography variant="body1" paragraph>
                        Для доступа к этому разделу требуются права администратора.
                    </Typography>
                    <Typography variant="body2" color="text.secondary" paragraph>
                        Пожалуйста, обратитесь к администратору системы если вам необходим доступ к этой функциональности.
                    </Typography>
                    
                    {tokenInfo && (
                        <Box sx={{ mt: 4, p: 2, bgcolor: 'grey.100', borderRadius: 1 }}>
                            <Typography variant="subtitle2" gutterBottom>
                                Отладочная информация:
                            </Typography>
                            <Typography variant="body2" component="pre" sx={{ textAlign: 'left', overflow: 'auto' }}>
                                {JSON.stringify(tokenInfo, null, 2)}
                            </Typography>
                        </Box>
                    )}
                    
                    <Button 
                        variant="outlined" 
                        color="primary" 
                        onClick={checkUserRole}
                        sx={{ mt: 2 }}
                        disabled={loading}
                    >
                        Проверить роль пользователя
                        {loading && <CircularProgress size={24} sx={{ ml: 1 }} />}
                    </Button>
                    
                    {success && (
                        <Alert severity="info" sx={{ mt: 2 }}>
                            {success}
                        </Alert>
                    )}
                </Paper>
            </Box>
        );
    }

    return (
        <Box>
            {renderConfirmDialog()}
            
            {/* Общие сообщения об ошибках и успешных операциях */}
            {error && (
                <Alert severity="error" sx={{ mb: 3 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center' }}>
                        <ErrorIcon sx={{ mr: 1 }} />
                        {error}
                    </Box>
                </Alert>
            )}

            {success && (
                <Alert severity="success" sx={{ mb: 3 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center' }}>
                        <CheckCircleIcon sx={{ mr: 1 }} />
                        {success}
                    </Box>
                </Alert>
            )}

            {/* Таблица категорий (для десктопа) или список (для мобильного) */}
            <Card elevation={3} sx={{ borderRadius: '12px', mb: 3 }}>
                <CardContent>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                        <Typography variant="h6" component="h3" sx={{ fontWeight: 'bold', color: '#2c3e50' }}>
                            Все категории
                        </Typography>
                        <Box>
                            <Tooltip title="Показать только нежелательные категории">
                                <IconButton 
                                    color={showOnlyUnwanted ? "primary" : "default"} 
                                    onClick={() => setShowOnlyUnwanted(!showOnlyUnwanted)}
                                >
                                    <FilterListIcon />
                                </IconButton>
                            </Tooltip>
                            <Tooltip title="Обновить список">
                                <IconButton 
                                    onClick={loadCategories} 
                                    disabled={loadingCategories}
                                >
                                    {loadingCategories ? <CircularProgress size={24} /> : <RefreshIcon />}
                                </IconButton>
                            </Tooltip>
                        </Box>
                    </Box>

                    {/* Десктопная версия - таблица */}
                    {!isMobile && (
                        <TableContainer component={Paper} elevation={0} sx={{ borderRadius: '8px' }}>
                            <Table size="small">
                                <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                                    <TableRow>
                                        <TableCell width="50">ID</TableCell>
                                        <TableCell>Название</TableCell>
                                        <TableCell align="right">Книги</TableCell>
                                        <TableCell align="right">Уникальные</TableCell>
                                        <TableCell align="right">Эксклюзивные</TableCell>
                                        <TableCell>Статус</TableCell>
                                        <TableCell>Дубликаты</TableCell>
                                        <TableCell>Создана</TableCell>
                                        <TableCell>Обновлена</TableCell>
                                        <TableCell align="right">Действия</TableCell>
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {loadingCategories ? (
                                        <TableRow>
                                            <TableCell colSpan={10} align="center" sx={{ py: 3 }}>
                                                <CircularProgress size={30} />
                                            </TableCell>
                                        </TableRow>
                                    ) : filteredCategories.length === 0 ? (
                                        <TableRow>
                                            <TableCell colSpan={10} align="center" sx={{ py: 3 }}>
                                                <Typography variant="body2" color="text.secondary">
                                                    {showOnlyUnwanted 
                                                        ? 'Нежелательные категории не найдены' 
                                                        : 'Категории не найдены'}
                                                </Typography>
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        filteredCategories
                                            .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                                            .map((category) => (
                                                <TableRow key={category.id} hover>
                                                    <TableCell>{category.id}</TableCell>
                                                    <TableCell>{category.name}</TableCell>
                                                    <TableCell align="right">
                                                        <Tooltip title="Общее количество книг в категории">
                                                            <Chip 
                                                                label={category.booksCount} 
                                                                color={category.booksCount > 0 ? "primary" : "default"} 
                                                                size="small" 
                                                            />
                                                        </Tooltip>
                                                    </TableCell>
                                                    <TableCell align="right">
                                                        <Tooltip title="Количество уникальных книг (без дубликатов)">
                                                            <Chip 
                                                                label={category.uniqueBooksCount}
                                                                color={category.uniqueBooksCount < category.booksCount ? "warning" : "success"}
                                                                size="small"
                                                            />
                                                        </Tooltip>
                                                    </TableCell>
                                                    <TableCell align="right">
                                                        <Tooltip title="Книги, присутствующие только в этой категории">
                                                            <Chip 
                                                                label={category.exclusiveBooksCount}
                                                                color={category.exclusiveBooksCount === 0 ? "default" : 
                                                                      category.exclusiveBooksCount < category.uniqueBooksCount ? "warning" : "success"}
                                                                size="small"
                                                            />
                                                        </Tooltip>
                                                    </TableCell>
                                                    <TableCell>
                                                        {category.isUnwanted ? (
                                                            <Chip 
                                                                label="Нежелательная" 
                                                                color="error" 
                                                                size="small" 
                                                                icon={<WarningIcon />} 
                                                            />
                                                        ) : (
                                                            <Chip 
                                                                label="Обычная" 
                                                                color="success" 
                                                                size="small" 
                                                            />
                                                        )}
                                                    </TableCell>
                                                    <TableCell>
                                                        {category.hasDuplicates ? (
                                                            <Tooltip title={`Найдено ${category.duplicateCount} категорий с таким именем`}>
                                                                <Chip 
                                                                    label={category.duplicateCount}
                                                                    color="warning"
                                                                    size="small"
                                                                    icon={<ContentCopyIcon />}
                                                                />
                                                            </Tooltip>
                                                        ) : (
                                                            <Chip 
                                                                label="Уникальная"
                                                                color="default"
                                                                size="small"
                                                            />
                                                        )}
                                                    </TableCell>
                                                    <TableCell>{formatDate(category.createdDate)}</TableCell>
                                                    <TableCell>{formatDate(category.lastUpdatedDate)}</TableCell>
                                                    <TableCell align="right">
                                                        <Tooltip title={
                                                            category.hasDuplicates 
                                                                ? `Удалить все категории с именем "${category.name}" (${category.duplicateCount} шт.)`
                                                                : "Удалить категорию"
                                                        }>
                                                            <IconButton 
                                                                size="small" 
                                                                color="error"
                                                                onClick={() => {
                                                                    openConfirmDialog('deleteCategories', [category.name]);
                                                                }}
                                                            >
                                                                <DeleteIcon fontSize="small" />
                                                            </IconButton>
                                                        </Tooltip>
                                                    </TableCell>
                                                </TableRow>
                                            ))
                                    )}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    )}
                    
                    {/* Мобильная версия - список */}
                    {isMobile && (
                        <Box>
                            {loadingCategories ? (
                                <Box sx={{ display: 'flex', justifyContent: 'center', p: 3 }}>
                                    <CircularProgress size={30} />
                                </Box>
                            ) : filteredCategories.length === 0 ? (
                                <Box sx={{ textAlign: 'center', p: 3 }}>
                                    <Typography variant="body2" color="text.secondary">
                                        {showOnlyUnwanted 
                                            ? 'Нежелательные категории не найдены' 
                                            : 'Категории не найдены'}
                                    </Typography>
                                </Box>
                            ) : (
                                <Box>
                                    {filteredCategories
                                        .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                                        .map(category => renderMobileCategoryItem(category))
                                    }
                                </Box>
                            )}
                        </Box>
                    )}

                    <TablePagination
                        rowsPerPageOptions={isMobile ? [5, 10, 25] : [5, 10, 25, 50]}
                        component="div"
                        count={filteredCategories.length}
                        rowsPerPage={rowsPerPage}
                        page={page}
                        onPageChange={handleChangePage}
                        onRowsPerPageChange={handleChangeRowsPerPage}
                        labelRowsPerPage={isMobile ? "Строк:" : "Строк на странице:"}
                        labelDisplayedRows={({ from, to, count }) => `${from}-${to} из ${count}`}
                    />
                </CardContent>
            </Card>

            {/* Секции "Произвольные категории" и "Нежелательные категории" */}
            {isMobile ? (
                // Мобильная версия - аккордеоны друг под другом
                <Box>
                    {/* Произвольные категории */}
                    <Accordion 
                        elevation={3} 
                        sx={{ 
                            borderRadius: '12px !important', 
                            mb: 2,
                            '&:before': { display: 'none' } // Убираем линию сверху
                        }}
                    >
                        <AccordionSummary
                            expandIcon={<ExpandMoreIcon />}
                            sx={{ 
                                borderRadius: '12px',
                                backgroundColor: '#f9f9f9' 
                            }}
                        >
                            <Typography variant="subtitle1" sx={{ fontWeight: 'bold' }}>
                                Произвольные категории
                            </Typography>
                        </AccordionSummary>
                        <AccordionDetails>
                            <Typography variant="body2" color="text.secondary" paragraph>
                                Анализируйте и удаляйте категории по названиям, указав их вручную
                            </Typography>
                            
                            <Divider sx={{ my: 2 }} />
                            
                            <Box sx={{ mb: 3 }}>
                                <TextField
                                    fullWidth
                                    label="Названия категорий"
                                    variant="outlined"
                                    value={categoryNames}
                                    onChange={(e) => setCategoryNames(e.target.value)}
                                    placeholder="Введите названия через запятую"
                                    helperText="Например: unknown, interested, draft"
                                    disabled={loading}
                                    sx={{ mb: 2 }}
                                />
                                
                                <Box sx={{ display: 'flex', gap: 1, mb: 2 }}>
                                    <Button
                                        variant="contained"
                                        color="primary"
                                        onClick={handleAnalyzeCategories}
                                        disabled={loading || !categoryNames.trim()}
                                        fullWidth
                                        startIcon={loading ? <CircularProgress size={20} /> : <AnalyticsIcon />}
                                    >
                                        Анализ
                                    </Button>
                                    
                                    <Button
                                        variant="contained"
                                        color="error"
                                        onClick={() => {
                                            if (categoryNames) {
                                                const namesToDelete = categoryNames.split(',').map(name => name.trim());
                                                openConfirmDialog('deleteCategories', namesToDelete);
                                            }
                                        }}
                                        disabled={loading || !categoryNames.trim()}
                                        fullWidth
                                        startIcon={<DeleteIcon />}
                                    >
                                        Удалить
                                    </Button>
                                </Box>
                                
                                {analysisResult && (
                                    <Paper elevation={1} sx={{ p: 2, borderRadius: '8px', backgroundColor: '#f8f9fa' }}>
                                        <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 'bold' }}>
                                            Результаты анализа:
                                        </Typography>
                                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 2 }}>
                                            <Box>
                                                <Typography variant="body2">
                                                    Категорий: <Chip label={analysisResult.categoriesCount} color="primary" size="small" sx={{ ml: 1 }} />
                                                </Typography>
                                            </Box>
                                            <Box>
                                                <Typography variant="body2">
                                                    Всего книг: <Chip label={analysisResult.booksCount} color="secondary" size="small" sx={{ ml: 1 }} />
                                                </Typography>
                                            </Box>
                                        </Box>
                                        <Typography variant="body2" sx={{ mt: 1, color: 'text.secondary', fontSize: '0.75rem' }}>
                                            * Общее количество книг может включать дубликаты
                                        </Typography>
                                        
                                        {analysisResult.categoriesCount > 0 && (
                                            <Button
                                                variant="outlined"
                                                color="error"
                                                size="small"
                                                onClick={() => {
                                                    const namesToDelete = categoryNames.split(',').map(name => name.trim());
                                                    openConfirmDialog('deleteCategories', namesToDelete);
                                                }}
                                                startIcon={<DeleteIcon />}
                                                sx={{ mt: 2 }}
                                                fullWidth
                                            >
                                                Удалить найденные категории
                                            </Button>
                                        )}
                                    </Paper>
                                )}
                            </Box>
                        </AccordionDetails>
                    </Accordion>

                    {/* Нежелательные категории */}
                    <Accordion 
                        elevation={3} 
                        sx={{ 
                            borderRadius: '12px !important', 
                            mb: 2,
                            '&:before': { display: 'none' } // Убираем линию сверху
                        }}
                    >
                        <AccordionSummary
                            expandIcon={<ExpandMoreIcon />}
                            sx={{ 
                                borderRadius: '12px',
                                backgroundColor: '#f9f9f9' 
                            }}
                        >
                            <Typography variant="subtitle1" sx={{ fontWeight: 'bold' }}>
                                Нежелательные категории
                            </Typography>
                        </AccordionSummary>
                        <AccordionDetails>
                            <Typography variant="body2" color="text.secondary" paragraph>
                                Анализируйте и удаляйте стандартные нежелательные категории ("unknown" и "interested")
                            </Typography>
                            
                            <Divider sx={{ my: 2 }} />
                            
                            <Box sx={{ mb: 3 }}>
                                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1, mb: 2 }}>
                                    <Button
                                        variant="contained"
                                        color="primary"
                                        onClick={handleAnalyzeUnwantedCategories}
                                        disabled={unwantedLoading}
                                        startIcon={unwantedLoading ? <CircularProgress size={20} /> : <AnalyticsIcon />}
                                        fullWidth
                                    >
                                        Анализировать нежелательные
                                    </Button>
                                    
                                    <Button
                                        variant="contained"
                                        color="error"
                                        onClick={() => openConfirmDialog('deleteUnwantedCategories')}
                                        disabled={unwantedLoading}
                                        startIcon={<DeleteIcon />}
                                        fullWidth
                                    >
                                        Удалить нежелательные
                                    </Button>
                                </Box>
                                
                                {unwantedAnalysisResult && (
                                    <Paper elevation={1} sx={{ p: 2, borderRadius: '8px', backgroundColor: '#f8f9fa' }}>
                                        <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 'bold' }}>
                                            Результаты анализа:
                                        </Typography>
                                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 2 }}>
                                            <Box>
                                                <Typography variant="body2">
                                                    Категорий: <Chip label={unwantedAnalysisResult.categoriesCount} color="primary" size="small" sx={{ ml: 1 }} />
                                                </Typography>
                                            </Box>
                                            <Box>
                                                <Typography variant="body2">
                                                    Книг: <Chip label={unwantedAnalysisResult.booksCount} color="secondary" size="small" sx={{ ml: 1 }} />
                                                </Typography>
                                            </Box>
                                        </Box>
                                        
                                        {unwantedAnalysisResult.categoriesCount > 0 && (
                                            <Button
                                                variant="outlined"
                                                color="error"
                                                size="small"
                                                onClick={() => openConfirmDialog('deleteUnwantedCategories')}
                                                startIcon={<DeleteIcon />}
                                                sx={{ mt: 2 }}
                                            >
                                                Удалить нежелательные категории
                                            </Button>
                                        )}
                                    </Paper>
                                )}
                                
                                <Alert severity="warning" sx={{ mt: 2 }}>
                                    <Box sx={{ display: 'flex', alignItems: 'flex-start' }}>
                                        <WarningIcon sx={{ mr: 1, mt: 0.5 }} fontSize="small" />
                                        <Typography variant="body2" sx={{ fontSize: '0.875rem' }}>
                                            Нежелательные категории: <strong>unknown</strong> и <strong>interested</strong> часто создаются автоматически и могут содержать некорректно классифицированные книги.
                                        </Typography>
                                    </Box>
                                </Alert>
                            </Box>
                        </AccordionDetails>
                    </Accordion>
                </Box>
            ) : (
                // Десктопная версия - сетка с двумя колонками
                <Grid container spacing={3}>
                    {/* Секция для произвольных категорий */}
                    <Grid item xs={12} md={6}>
                        <Card elevation={3} sx={{ borderRadius: '12px', height: '100%' }}>
                            <CardContent>
                                <Typography variant="h6" component="h3" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50' }}>
                                    Произвольные категории
                                </Typography>
                                <Typography variant="body2" color="text.secondary" paragraph>
                                    Анализируйте и удаляйте категории по названиям, указав их вручную
                                </Typography>
                                
                                <Divider sx={{ my: 2 }} />
                                
                                <Box sx={{ mb: 3 }}>
                                    <TextField
                                        fullWidth
                                        label="Названия категорий"
                                        variant="outlined"
                                        value={categoryNames}
                                        onChange={(e) => setCategoryNames(e.target.value)}
                                        placeholder="Введите названия категорий через запятую"
                                        helperText="Например: unknown, interested, draft"
                                        disabled={loading}
                                        sx={{ mb: 2 }}
                                    />
                                    
                                    <Button
                                        variant="contained"
                                        color="primary"
                                        onClick={handleAnalyzeCategories}
                                        disabled={loading || !categoryNames.trim()}
                                        startIcon={loading ? <CircularProgress size={20} /> : <AnalyticsIcon />}
                                        sx={{ mr: 1 }}
                                    >
                                        Анализировать
                                    </Button>
                                    
                                    <Button
                                        variant="contained"
                                        color="error"
                                        onClick={() => {
                                            if (categoryNames) {
                                                const namesToDelete = categoryNames.split(',').map(name => name.trim());
                                                openConfirmDialog('deleteCategories', namesToDelete);
                                            }
                                        }}
                                        disabled={loading || !categoryNames.trim()}
                                        startIcon={<DeleteIcon />}
                                    >
                                        Удалить
                                    </Button>
                                </Box>
                                
                                {analysisResult && (
                                    <Paper elevation={1} sx={{ p: 2, borderRadius: '8px', backgroundColor: '#f8f9fa' }}>
                                        <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 'bold' }}>
                                            Результаты анализа:
                                        </Typography>
                                        <Typography variant="body2">
                                            Категорий: <Chip label={analysisResult.categoriesCount} color="primary" size="small" sx={{ ml: 1 }} />
                                        </Typography>
                                        <Typography variant="body2">
                                            Всего книг: <Chip label={analysisResult.booksCount} color="secondary" size="small" sx={{ ml: 1 }} />
                                        </Typography>
                                        <Typography variant="body2" sx={{ mt: 1, color: 'text.secondary' }}>
                                            * Общее количество книг может включать дубликаты, если книги присутствуют в нескольких категориях
                                        </Typography>
                                        
                                        {analysisResult.categoriesCount > 0 && (
                                            <Button
                                                variant="outlined"
                                                color="error"
                                                size="small"
                                                onClick={() => {
                                                    const namesToDelete = categoryNames.split(',').map(name => name.trim());
                                                    openConfirmDialog('deleteCategories', namesToDelete);
                                                }}
                                                startIcon={<DeleteIcon />}
                                                sx={{ mt: 2 }}
                                            >
                                                Удалить найденные категории
                                            </Button>
                                        )}
                                    </Paper>
                                )}
                            </CardContent>
                        </Card>
                    </Grid>

                    {/* Секция для нежелательных категорий */}
                    <Grid item xs={12} md={6}>
                        <Card elevation={3} sx={{ borderRadius: '12px', height: '100%' }}>
                            <CardContent>
                                <Typography variant="h6" component="h3" gutterBottom sx={{ fontWeight: 'bold', color: '#2c3e50' }}>
                                    Нежелательные категории
                                </Typography>
                                <Typography variant="body2" color="text.secondary" paragraph>
                                    Анализируйте и удаляйте стандартные нежелательные категории ("unknown" и "interested")
                                </Typography>
                                
                                <Divider sx={{ my: 2 }} />
                                
                                <Box sx={{ mb: 3, display: 'flex', gap: 1 }}>
                                    <Button
                                        variant="contained"
                                        color="primary"
                                        onClick={handleAnalyzeUnwantedCategories}
                                        disabled={unwantedLoading}
                                        startIcon={unwantedLoading ? <CircularProgress size={20} /> : <AnalyticsIcon />}
                                        fullWidth
                                    >
                                        Анализировать нежелательные
                                    </Button>
                                    
                                    <Button
                                        variant="contained"
                                        color="error"
                                        onClick={() => openConfirmDialog('deleteUnwantedCategories')}
                                        disabled={unwantedLoading}
                                        startIcon={<DeleteIcon />}
                                        fullWidth
                                    >
                                        Удалить нежелательные
                                    </Button>
                                </Box>
                                
                                {unwantedAnalysisResult && (
                                    <Paper elevation={1} sx={{ p: 2, borderRadius: '8px', backgroundColor: '#f8f9fa' }}>
                                        <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 'bold' }}>
                                            Результаты анализа нежелательных категорий:
                                        </Typography>
                                        <Typography variant="body2">
                                            Категорий: <Chip label={unwantedAnalysisResult.categoriesCount} color="primary" size="small" sx={{ ml: 1 }} />
                                        </Typography>
                                        <Typography variant="body2">
                                            Книг: <Chip label={unwantedAnalysisResult.booksCount} color="secondary" size="small" sx={{ ml: 1 }} />
                                        </Typography>
                                        
                                        {unwantedAnalysisResult.categoriesCount > 0 && (
                                            <Button
                                                variant="outlined"
                                                color="error"
                                                size="small"
                                                onClick={() => openConfirmDialog('deleteUnwantedCategories')}
                                                startIcon={<DeleteIcon />}
                                                sx={{ mt: 2 }}
                                            >
                                                Удалить нежелательные категории
                                            </Button>
                                        )}
                                    </Paper>
                                )}
                                
                                <Alert severity="warning" sx={{ mt: 3 }}>
                                    <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                        <WarningIcon sx={{ mr: 1 }} />
                                        <Typography variant="body2">
                                            Нежелательные категории: <strong>unknown</strong> и <strong>interested</strong> часто создаются автоматически и содержат книги, которые могут быть некорректно классифицированы.
                                        </Typography>
                                    </Box>
                                </Alert>
                            </CardContent>
                        </Card>
                    </Grid>
                </Grid>
            )}
        </Box>
    );
};

export default CategoryCleanup; 