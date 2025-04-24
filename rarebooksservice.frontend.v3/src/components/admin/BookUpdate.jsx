import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Button, Paper, CircularProgress,
    Card, CardContent, Grid, Alert, Switch, FormControlLabel,
    useMediaQuery, useTheme, Table, TableBody, TableCell, 
    TableContainer, TableHead, TableRow, Divider, IconButton,
    Accordion, AccordionSummary, AccordionDetails, Chip,
    Dialog, DialogTitle, DialogContent, DialogActions,
    Skeleton, Fade
} from '@mui/material';
import axios from 'axios';
import { API_URL } from '../../api';
import Cookies from 'js-cookie';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import RefreshIcon from '@mui/icons-material/Refresh';
import PauseIcon from '@mui/icons-material/Pause';
import PlayArrowIcon from '@mui/icons-material/PlayArrow';
import SyncIcon from '@mui/icons-material/Sync';
import InfoIcon from '@mui/icons-material/Info';
import ErrorIcon from '@mui/icons-material/Error';

const BookUpdate = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));
    
    const [bookUpdateStatus, setBookUpdateStatus] = useState({
        isPaused: false,
        isRunningNow: false,
        lastRunTimeUtc: null,
        nextRunTimeUtc: null,
        currentOperationName: null,
        processedCount: 0,
        lastProcessedLotId: 0,
        lastProcessedLotTitle: '',
        logs: []
    });
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [autoRefresh, setAutoRefresh] = useState(true);
    const [logDetailOpen, setLogDetailOpen] = useState(false);
    const [selectedLog, setSelectedLog] = useState(null);
    const [initialLoadComplete, setInitialLoadComplete] = useState(false);
    
    const fetchStatus = async () => {
        try {
            // Не показываем индикатор загрузки при автоматическом обновлении,
            // только меняем состояние loading
            const showLoadingIndicator = !initialLoadComplete;
            if (showLoadingIndicator) {
            setLoading(true);
            }
            
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/bookupdateservice/status`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            
            // Плавно заменяем данные
            setBookUpdateStatus(prevStatus => {
                // Если логи не изменились, сохраняем старый объект для предотвращения перерисовки
                if (JSON.stringify(prevStatus.logs) === JSON.stringify(response.data.logs)) {
                    response.data.logs = prevStatus.logs;
                }
                return response.data;
            });
            
            setError('');
            
            if (!initialLoadComplete) {
                setInitialLoadComplete(true);
            }
        } catch (err) {
            console.error('Error fetching book update status:', err);
            setError('Не удалось получить статус обновления книг');
        } finally {
            setLoading(false);
        }
    };
    
    useEffect(() => {
        fetchStatus();
        
        // Auto-refresh setup
        let intervalId;
        if (autoRefresh) {
            intervalId = setInterval(() => {
                fetchStatus();
            }, 5000); // refresh every 5 seconds
        }
        
        return () => {
            if (intervalId) clearInterval(intervalId);
        };
    }, [autoRefresh]);
    
    const handlePause = async () => {
        try {
            setLoading(true);
            const token = Cookies.get('token');
            await axios.post(`${API_URL}/bookupdateservice/pause`, null, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await fetchStatus();
        } catch (err) {
            console.error('Error pausing book update:', err);
            setError('Не удалось приостановить обновление книг');
        } finally {
            setLoading(false);
        }
    };
    
    const handleResume = async () => {
        try {
            setLoading(true);
            const token = Cookies.get('token');
            await axios.post(`${API_URL}/bookupdateservice/resume`, null, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await fetchStatus();
        } catch (err) {
            console.error('Error resuming book update:', err);
            setError('Не удалось возобновить обновление книг');
        } finally {
            setLoading(false);
        }
    };
    
    const handleRunNow = async () => {
        try {
            setLoading(true);
            const token = Cookies.get('token');
            await axios.post(`${API_URL}/bookupdateservice/runNow`, null, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await fetchStatus();
        } catch (err) {
            console.error('Error running book update:', err);
            setError('Не удалось запустить обновление книг');
        } finally {
            setLoading(false);
        }
    };
    
    const handleRunCategoryCheck = async () => {
        try {
            setLoading(true);
            const token = Cookies.get('token');
            await axios.post(`${API_URL}/bookupdateservice/runCategoryCheck`, null, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await fetchStatus();
        } catch (err) {
            console.error('Error running category check:', err);
            setError('Не удалось запустить проверку категорий');
        } finally {
            setLoading(false);
        }
    };
    
    const formatDateTime = (dateTimeString) => {
        if (!dateTimeString) return 'Н/Д';
        const date = new Date(dateTimeString);
        return new Intl.DateTimeFormat('ru-RU', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        }).format(date);
    };
    
    const getStatusText = (status) => {
        if (status.isPaused) return 'Приостановлено';
        if (status.isRunningNow) return 'Выполняется';
        return 'Ожидание';
    };
    
    const getStatusColor = (status) => {
        if (status.isPaused) return '#ff9800';
        if (status.isRunningNow) return '#4caf50';
        return '#757575';
    };
    
    // Проверяем, содержит ли logs объекты или строки
    const isStructuredLogs = Array.isArray(bookUpdateStatus.logs) && 
                          bookUpdateStatus.logs.length > 0 && 
                          typeof bookUpdateStatus.logs[0] === 'object';
    
    const handleViewLogDetail = (log) => {
        setSelectedLog(log);
        setLogDetailOpen(true);
    };

    // Скелетон для данных статуса
    const StatusSkeleton = () => (
        <Box>
            <Box sx={{ 
                display: 'flex', 
                justifyContent: 'space-between', 
                alignItems: 'flex-start',
                flexDirection: isMobile ? 'column' : 'row',
                gap: isMobile ? 2 : 0,
                mb: 2
            }}>
                <Skeleton variant="text" width={200} height={32} />
                <Skeleton variant="rounded" width={120} height={38} />
            </Box>
            
            <Grid container spacing={isMobile ? 1 : 2}>
                {[1, 2, 3, 4, 5, 6].map((item) => (
                    <Grid item xs={item % 2 === 0 ? 6 : 12} sm={6} key={item}>
                        <Skeleton variant="text" width={120} height={20} />
                        <Skeleton variant="text" width="90%" height={28} />
                    </Grid>
                ))}
            </Grid>
            
            <Divider sx={{ my: 2 }} />
            
            <Box sx={{ 
                display: 'flex', 
                gap: 2,
                flexDirection: isMobile ? 'column' : 'row',
                mt: 2
            }}>
                <Skeleton variant="rounded" width="100%" height={40} />
            </Box>
        </Box>
    );
    
    // Скелетон для логов
    const LogSkeleton = () => (
        <>
            {isMobile ? (
                <>
                    {[1, 2, 3].map((item) => (
                        <Skeleton 
                            key={item} 
                            variant="rounded" 
                            width="100%" 
                            height={90} 
                            sx={{ mb: 2 }}
                        />
                    ))}
                </>
            ) : (
                <Skeleton variant="rounded" width="100%" height={250} />
            )}
        </>
    );
    
    return (
        <Box>
            <Typography variant="h5" component="h2" gutterBottom sx={{ 
                fontWeight: 'bold', 
                color: '#2c3e50', 
                mb: 3,
                fontSize: { xs: '1.2rem', sm: '1.4rem', md: '1.5rem' }
            }}>
                Управление обновлением книг
            </Typography>
            
            {error && (
                <Alert severity="error" sx={{ mb: 3 }}>
                    {error}
                </Alert>
            )}
            
            <Box sx={{ 
                display: 'flex', 
                justifyContent: 'space-between', 
                alignItems: isMobile ? 'flex-start' : 'center', 
                mb: 2,
                flexDirection: isMobile ? 'column' : 'row',
                gap: isMobile ? 2 : 0
            }}>
                <FormControlLabel
                    control={
                        <Switch
                            checked={autoRefresh}
                            onChange={(e) => setAutoRefresh(e.target.checked)}
                            color="primary"
                        />
                    }
                    label="Автоматическое обновление"
                />
                
                <Button 
                    variant="outlined"
                    onClick={fetchStatus}
                    disabled={loading}
                    startIcon={<RefreshIcon />}
                    size={isMobile ? "small" : "medium"}
                    sx={{ width: isMobile ? '100%' : 'auto' }}
                >
                    Обновить данные
                </Button>
            </Box>
            
            {loading && !initialLoadComplete && (
                <Box sx={{ display: 'flex', justifyContent: 'center', my: 2 }}>
                    <CircularProgress size={24} />
                </Box>
            )}
            
            {/* Карточка статуса - всегда видима независимо от устройства */}
            <Card elevation={3} sx={{ mb: 3 }}>
                <CardContent sx={{ 
                    p: isMobile ? 2 : 3,
                    minHeight: isMobile ? '350px' : '250px', // Фиксированная минимальная высота
                    transition: 'all 0.3s ease', // Плавный переход
                    position: 'relative' // Для правильного позиционирования внутренних элементов
                }}>
                    {loading && !initialLoadComplete ? (
                        <StatusSkeleton />
                    ) : (
                        <Fade in={true} timeout={300}>
                            <Box>
                                <Box sx={{ 
                                    display: 'flex', 
                                    justifyContent: 'space-between', 
                                    alignItems: 'flex-start',
                                    flexDirection: isMobile ? 'column' : 'row',
                                    gap: isMobile ? 2 : 0,
                                    mb: 2
                                }}>
                                    <Typography variant="h6" component="h3" gutterBottom sx={{ mb: isMobile ? 0 : 2 }}>
                                Текущий статус
                            </Typography>
                            
                                <Box sx={{ 
                                    display: 'inline-flex', 
                                    alignItems: 'center', 
                                    gap: 1,
                                    bgcolor: getStatusColor(bookUpdateStatus) + '1A',
                                    p: 1,
                                    px: 2,
                                        borderRadius: '8px',
                                        transition: 'background-color 0.3s ease, color 0.3s ease'
                                }}>
                                    <Box sx={{ 
                                        width: 12, 
                                        height: 12, 
                                        borderRadius: '50%', 
                                            bgcolor: getStatusColor(bookUpdateStatus),
                                            transition: 'background-color 0.3s ease'
                                    }} />
                                        <Typography variant="subtitle1" fontWeight="bold" sx={{ 
                                            color: getStatusColor(bookUpdateStatus),
                                            transition: 'color 0.3s ease'
                                        }}>
                                        {getStatusText(bookUpdateStatus)}
                                    </Typography>
                                    </Box>
                                </Box>
                                
                                <Grid container spacing={isMobile ? 1 : 2}>
                                    <Grid item xs={12} sm={6}>
                                        <Typography variant="body2" color="text.secondary">
                                            Последнее обновление:
                                        </Typography>
                                        <Typography variant="body1" sx={{ mb: 1, height: '1.5rem' }}>
                                            {formatDateTime(bookUpdateStatus.lastRunTimeUtc)}
                                </Typography>
                                    </Grid>
                                    
                                    <Grid item xs={12} sm={6}>
                                        <Typography variant="body2" color="text.secondary">
                                            Следующее обновление:
                                        </Typography>
                                        <Typography variant="body1" sx={{ mb: 1, height: '1.5rem' }}>
                                            {formatDateTime(bookUpdateStatus.nextRunTimeUtc)}
                            </Typography>
                                    </Grid>

                                    <Grid item xs={12}>
                                        <Typography variant="body2" color="text.secondary">
                                            Текущая операция:
                                        </Typography>
                                        <Typography variant="body1" sx={{ mb: 1, height: '1.5rem', fontWeight: 'medium' }}>
                                            {bookUpdateStatus.currentOperationName || 'Нет активной операции'}
                                </Typography>
                                    </Grid>
                                    
                                    <Grid item xs={6}>
                                        <Typography variant="body2" color="text.secondary">
                                            Обработано лотов:
                                        </Typography>
                                        <Typography variant="body1" sx={{ mb: 1, height: '1.5rem' }}>
                                            {bookUpdateStatus.processedCount}
                            </Typography>
                                    </Grid>
                                    
                                    <Grid item xs={6}>
                                        <Typography variant="body2" color="text.secondary">
                                            Последний лот (ID):
                                        </Typography>
                                        <Typography variant="body1" sx={{ mb: 1, height: '1.5rem' }}>
                                            {bookUpdateStatus.lastProcessedLotId || 'Н/Д'}
                            </Typography>
                                    </Grid>
                                    
                                    <Grid item xs={12}>
                                        <Typography variant="body2" color="text.secondary">
                                            Строка состояния обновления:
                                        </Typography>
                                        <Typography variant="body1" sx={{ mb: 1, minHeight: '1.5rem' }}>
                                            {bookUpdateStatus.lastProcessedLotTitle || 'Нет информации'}
                                </Typography>
                                    </Grid>
                                </Grid>
                                
                                <Divider sx={{ my: 2 }} />
                            
                            <Box sx={{ 
                                display: 'flex', 
                                gap: 2,
                                    flexDirection: isMobile ? 'column' : 'row',
                                    mt: 2
                            }}>
                                {bookUpdateStatus.isRunningNow && !bookUpdateStatus.isPaused && (
                                    <Button
                                        variant="outlined"
                                        color="warning"
                                        onClick={handlePause}
                                            startIcon={<PauseIcon />}
                                            sx={{ 
                                                flex: 1,
                                                p: { xs: 1, sm: 1.5 }
                                            }}
                                    >
                                        Приостановить
                                    </Button>
                                )}
                                
                                {bookUpdateStatus.isPaused && (
                                    <Button
                                        variant="outlined"
                                        color="success"
                                        onClick={handleResume}
                                            startIcon={<PlayArrowIcon />}
                                            sx={{ 
                                                flex: 1,
                                                p: { xs: 1, sm: 1.5 }
                                            }}
                                    >
                                        Возобновить
                                    </Button>
                                )}
                                
                                {(!bookUpdateStatus.isRunningNow || bookUpdateStatus.isPaused) && (
                                    <>
                                        <Button
                                            variant="contained"
                                            onClick={handleRunNow}
                                            startIcon={<SyncIcon />}
                                            sx={{ 
                                                backgroundColor: '#E72B3D', 
                                                '&:hover': { backgroundColor: '#c4242f' },
                                                flex: 1,
                                                p: { xs: 1, sm: 1.5 }
                                            }}
                                        >
                                            Запустить сейчас
                                        </Button>
                                        
                                        <Button
                                            variant="contained"
                                            onClick={handleRunCategoryCheck}
                                            sx={{ 
                                                backgroundColor: '#5C6BC0', 
                                                '&:hover': { backgroundColor: '#3F51B5' },
                                                flex: 1,
                                                p: { xs: 1, sm: 1.5 }
                                            }}
                                        >
                                            Проверить категории (раскоментировать в BookUpdateService)
                                        </Button>
                                    </>
                                )}

                                    {/* Невидимая кнопка для стабилизации высоты, если не отображаются реальные кнопки */}
                                    {!bookUpdateStatus.isPaused && !bookUpdateStatus.isRunningNow && (
                                        <Box sx={{ visibility: 'hidden', height: 0, flex: 1 }} />
                                    )}
                                </Box>
                            </Box>
                        </Fade>
                    )}
                        </CardContent>
                    </Card>
            
            {/* Информация об обновлении - преобразуем в аккордеон для мобильных */}
            {isMobile ? (
                <Accordion elevation={3} sx={{ mb: 3 }}>
                    <AccordionSummary
                        expandIcon={<ExpandMoreIcon />}
                        aria-controls="info-accordion-content"
                        id="info-accordion-header"
                    >
                        <Typography variant="h6" component="h3">Информация об обновлении</Typography>
                    </AccordionSummary>
                    <AccordionDetails>
                        <Typography variant="body1" paragraph>
                            Процесс обновления книг отвечает за синхронизацию данных о книгах из внешних источников.
                        </Typography>
                        
                        <Typography variant="body1" paragraph>
                            По умолчанию обновление выполняется по расписанию, но вы можете управлять этим процессом вручную.
                        </Typography>
                        
                        <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                            Внимание: частое запуск обновления может увеличить нагрузку на сервер и внешние API.
                        </Typography>
                    </AccordionDetails>
                </Accordion>
            ) : (
                <Card elevation={3} sx={{ mb: 3 }}>
                        <CardContent>
                            <Typography variant="h6" component="h3" gutterBottom>
                                Информация об обновлении
                            </Typography>
                            
                            <Typography variant="body1" paragraph>
                                Процесс обновления книг отвечает за синхронизацию данных о книгах из внешних источников.
                            </Typography>
                            
                            <Typography variant="body1" paragraph>
                                По умолчанию обновление выполняется по расписанию, но вы можете управлять этим процессом вручную.
                            </Typography>
                            
                            <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                                Внимание: частое запуск обновления может увеличить нагрузку на сервер и внешние API.
                            </Typography>
                        </CardContent>
                    </Card>
            )}
            
            {/* Секция логов - адаптируем для мобильных устройств */}
            <Card elevation={3} sx={{ mb: 4 }}>
                <CardContent sx={{ 
                    p: isMobile ? 2 : 3,
                    minHeight: isMobile ? '400px' : '450px', // Фиксированная минимальная высота
                    transition: 'all 0.3s ease'
                }}>
                    <Typography variant="h6" component="h3" gutterBottom>
                        Подробная информация / логи
                    </Typography>
                    
                    {loading && !initialLoadComplete ? (
                        <LogSkeleton />
                    ) : (
                        Array.isArray(bookUpdateStatus.logs) && bookUpdateStatus.logs.length > 0 ? (
                            <Fade in={true} timeout={300}>
                        <Box sx={{ overflowX: 'auto' }}>
                            {isStructuredLogs ? (
                                        isMobile ? (
                                            <Box sx={{ minHeight: '300px' }}>
                                                {[...bookUpdateStatus.logs]
                                                    .reverse()
                                                    .slice(0, 10) // Ограничиваем количество логов для мобильной версии
                                                    .map((entry, idx) => (
                                                        <Box 
                                                            key={idx} 
                                                            sx={{ 
                                                                mb: 2, 
                                                                p: 2, 
                                                                borderRadius: 1, 
                                                                bgcolor: entry.isError ? 'rgba(244, 67, 54, 0.08)' : 'rgba(238, 238, 238, 0.5)',
                                                                border: '1px solid',
                                                                borderColor: entry.isError ? 'error.light' : 'divider',
                                                                transition: 'background-color 0.2s ease, transform 0.2s ease',
                                                                '&:hover': {
                                                                    transform: 'translateY(-2px)',
                                                                    boxShadow: '0 4px 8px rgba(0,0,0,0.1)'
                                                                }
                                                            }}
                                                            onClick={() => handleViewLogDetail(entry)}
                                                        >
                                                            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                                                                <Typography variant="caption" component="div" fontWeight="bold">
                                                                    {new Date(entry.timestamp).toLocaleString()}
                                                                </Typography>
                                                                {entry.isError && <ErrorIcon color="error" fontSize="small" />}
                                                            </Box>
                                                            
                                                            <Typography 
                                                                variant="body2" 
                                                                component="div" 
                                                                fontWeight={entry.isError ? 'bold' : 'normal'} 
                                                                color={entry.isError ? 'error.main' : 'inherit'}
                                                                sx={{
                                                                    maxHeight: '60px',
                                                                    overflow: 'hidden',
                                                                    textOverflow: 'ellipsis',
                                                                    whiteSpace: 'normal',
                                                                    display: '-webkit-box',
                                                                    WebkitLineClamp: 2,
                                                                    WebkitBoxOrient: 'vertical'
                                                                }}
                                                            >
                                                                {entry.message}
                                                            </Typography>
                                                            
                                                            <Box sx={{ mt: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                                                <Chip 
                                                                    label={entry.operationName || 'Нет операции'} 
                                                                    size="small" 
                                                                    sx={{ maxWidth: '60%', textOverflow: 'ellipsis' }}
                                                                />
                                                                <IconButton size="small" onClick={(e) => {
                                                                    e.stopPropagation();
                                                                    handleViewLogDetail(entry);
                                                                }}>
                                                                    <InfoIcon fontSize="small" />
                                                                </IconButton>
                                                            </Box>
                                                        </Box>
                                                    ))}
                                                <Typography variant="caption" color="text.secondary">
                                                    Показаны последние записи. Нажмите на запись для подробностей.
                                                </Typography>
                                            </Box>
                                        ) : (
                                            <TableContainer component={Paper} elevation={0} sx={{ 
                                                height: '350px', 
                                                maxHeight: '350px', 
                                                overflow: 'auto'
                                            }}>
                                                <Table stickyHeader size="small">
                                        <TableHead>
                                            <TableRow>
                                                <TableCell>Время</TableCell>
                                                <TableCell>Сообщение</TableCell>
                                                            <TableCell>Операция</TableCell>
                                                            <TableCell>LotId</TableCell>
                                                <TableCell>Ошибка?</TableCell>
                                                            <TableCell>Exception</TableCell>
                                            </TableRow>
                                        </TableHead>
                                        <TableBody>
                                            {[...bookUpdateStatus.logs]
                                                .reverse()
                                                .map((entry, idx) => {
                                                    const timeLocal = new Date(entry.timestamp);
                                                    return (
                                                        <TableRow
                                                            key={idx}
                                                            sx={{ 
                                                                color: entry.isError ? 'error.main' : 'inherit',
                                                                            backgroundColor: entry.isError ? 'rgba(244, 67, 54, 0.08)' : 'inherit',
                                                                            cursor: 'pointer',
                                                                            transition: 'background-color 0.2s ease',
                                                                            '&:hover': {
                                                                                backgroundColor: entry.isError ? 'rgba(244, 67, 54, 0.12)' : 'rgba(0, 0, 0, 0.04)'
                                                                            }
                                                                        }}
                                                                        onClick={() => handleViewLogDetail(entry)}
                                                        >
                                                            <TableCell sx={{ whiteSpace: 'nowrap' }}>
                                                                {timeLocal.toLocaleString()}
                                                            </TableCell>
                                                            <TableCell>{entry.message}</TableCell>
                                                                        <TableCell>{entry.operationName || '-'}</TableCell>
                                                                        <TableCell>{entry.lotId ?? '-'}</TableCell>
                                                            <TableCell>{entry.isError ? 'Да' : 'Нет'}</TableCell>
                                                                        <TableCell sx={{ 
                                                                            whiteSpace: 'pre-wrap', 
                                                                            maxWidth: '300px', 
                                                                            overflow: 'hidden', 
                                                                            textOverflow: 'ellipsis' 
                                                                        }}>
                                                                    {entry.exceptionMessage || ''}
                                                                </TableCell>
                                                        </TableRow>
                                                    );
                                                })}
                                        </TableBody>
                                    </Table>
                                </TableContainer>
                                        )
                            ) : (
                                        <Box sx={{ p: 2, bgcolor: 'grey.100', borderRadius: 1, 
                                            height: isMobile ? '300px' : '350px', 
                                            overflow: 'auto' 
                                        }}>
                                    {bookUpdateStatus.logs.map((log, index) => (
                                        <Box key={index} sx={{ mb: 1 }}>
                                            <Typography variant="body2" component="div">{log}</Typography>
                                            {index < bookUpdateStatus.logs.length - 1 && <Divider sx={{ my: 1 }} />}
                                        </Box>
                                    ))}
                                </Box>
                            )}
                        </Box>
                            </Fade>
                        ) : (
                            <Box sx={{ 
                                display: 'flex', 
                                alignItems: 'center', 
                                justifyContent: 'center',
                                height: '300px' 
                            }}>
                        <Typography variant="body1" color="text.secondary">
                            Логи пока отсутствуют.
                        </Typography>
                            </Box>
                        )
                    )}
                </CardContent>
            </Card>

            {/* Диалог с подробностями лога */}
            <Dialog
                open={logDetailOpen}
                onClose={() => setLogDetailOpen(false)}
                maxWidth="sm"
                fullWidth
                fullScreen={isMobile}
                TransitionComponent={Fade}
                transitionDuration={300}
            >
                <DialogTitle>
                    Подробности записи
                </DialogTitle>
                <DialogContent dividers>
                    {selectedLog && (
                        <Box>
                            <Grid container spacing={2}>
                                <Grid item xs={12}>
                                    <Typography variant="caption" color="text.secondary">
                                        Время:
                                    </Typography>
                                    <Typography variant="body1" gutterBottom>
                                        {new Date(selectedLog.timestamp).toLocaleString()}
                        </Typography>
                                </Grid>
                                
                                <Grid item xs={12}>
                                    <Typography variant="caption" color="text.secondary">
                                        Сообщение:
                                    </Typography>
                                    <Typography 
                                        variant="body1" 
                                        gutterBottom 
                                        fontWeight={selectedLog.isError ? 'bold' : 'normal'}
                                        color={selectedLog.isError ? 'error.main' : 'inherit'}
                                    >
                                        {selectedLog.message}
                                    </Typography>
                                </Grid>
                                    
                                        <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">
                                        Операция:
                                    </Typography>
                                    <Typography variant="body1" gutterBottom>
                                        {selectedLog.operationName || 'Не указана'}
                                    </Typography>
                                        </Grid>
                                
                                        <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">
                                        ID лота:
                                    </Typography>
                                    <Typography variant="body1" gutterBottom>
                                        {selectedLog.lotId || 'Не указан'}
                                    </Typography>
                                        </Grid>
                                
                                            <Grid item xs={12}>
                                    <Typography variant="caption" color="text.secondary">
                                        Статус:
                                    </Typography>
                                    <Typography 
                                        variant="body1" 
                                        gutterBottom
                                        color={selectedLog.isError ? 'error.main' : 'success.main'}
                                    >
                                        {selectedLog.isError ? 'Ошибка' : 'Успешно'}
                                                </Typography>
                                            </Grid>
                                
                                {selectedLog.exceptionMessage && (
                                    <Grid item xs={12}>
                                        <Typography variant="caption" color="text.secondary">
                                            Сообщение об ошибке:
                                        </Typography>
                                        <Paper 
                                            elevation={0} 
                                            sx={{ 
                                                p: 2, 
                                                bgcolor: 'error.light', 
                                                color: 'error.contrastText',
                                                maxHeight: '150px',
                                                overflow: 'auto',
                                                whiteSpace: 'pre-wrap',
                                                mt: 1
                                            }}
                                        >
                                            {selectedLog.exceptionMessage}
                                        </Paper>
                                            </Grid>
                                        )}
                                    </Grid>
                                </Box>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setLogDetailOpen(false)}>
                        Закрыть
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default BookUpdate; 