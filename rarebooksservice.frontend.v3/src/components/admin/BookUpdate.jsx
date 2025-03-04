import React, { useState, useEffect } from 'react';
import {
    Box, Typography, Button, Paper, CircularProgress,
    Card, CardContent, Grid, Alert, Switch, FormControlLabel,
    useMediaQuery, useTheme, Table, TableBody, TableCell, 
    TableContainer, TableHead, TableRow, Divider
} from '@mui/material';
import axios from 'axios';
import { API_URL } from '../../api';
import Cookies from 'js-cookie';

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
    
    const fetchStatus = async () => {
        try {
            setLoading(true);
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/bookupdateservice/status`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setBookUpdateStatus(response.data);
            setError('');
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
            
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                <FormControlLabel
                    control={
                        <Switch
                            checked={autoRefresh}
                            onChange={(e) => setAutoRefresh(e.target.checked)}
                            color="primary"
                        />
                    }
                    label="Автоматическое обновление статуса"
                />
                
                <Button 
                    variant="outlined"
                    onClick={fetchStatus}
                    disabled={loading}
                    sx={{ ml: 2 }}
                >
                    Обновить данные
                </Button>
            </Box>
            
            {loading && (
                <Box sx={{ display: 'flex', justifyContent: 'center', my: 2 }}>
                    <CircularProgress size={24} />
                </Box>
            )}
            
            <Grid container spacing={3} sx={{ mb: 4 }}>
                <Grid item xs={12} md={6}>
                    <Card elevation={3} sx={{ height: '100%' }}>
                        <CardContent>
                            <Typography variant="h6" component="h3" gutterBottom>
                                Текущий статус
                            </Typography>
                            
                            <Box sx={{ 
                                py: 2, 
                                display: 'flex', 
                                flexDirection: { xs: 'column', sm: 'row' },
                                alignItems: { xs: 'flex-start', sm: 'center' },
                                gap: 2
                            }}>
                                <Box sx={{ 
                                    display: 'inline-flex', 
                                    alignItems: 'center', 
                                    gap: 1,
                                    bgcolor: getStatusColor(bookUpdateStatus) + '1A',
                                    p: 1,
                                    px: 2,
                                    borderRadius: '8px'
                                }}>
                                    <Box sx={{ 
                                        width: 12, 
                                        height: 12, 
                                        borderRadius: '50%', 
                                        bgcolor: getStatusColor(bookUpdateStatus) 
                                    }} />
                                    <Typography variant="subtitle1" fontWeight="bold" sx={{ color: getStatusColor(bookUpdateStatus) }}>
                                        {getStatusText(bookUpdateStatus)}
                                    </Typography>
                                </Box>
                                
                                <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                                    Последнее обновление: {formatDateTime(bookUpdateStatus.lastRunTimeUtc)}
                                </Typography>
                            </Box>
                            
                            <Typography variant="body1" sx={{ mb: 2 }}>
                                Следующее обновление: {formatDateTime(bookUpdateStatus.nextRunTimeUtc)}
                            </Typography>

                            {bookUpdateStatus.currentOperationName && (
                                <Typography variant="body2" sx={{ mb: 2 }}>
                                    Текущая операция: <strong>{bookUpdateStatus.currentOperationName}</strong>
                                </Typography>
                            )}
                            
                            <Typography variant="body2" sx={{ mb: 2 }}>
                                Обработано лотов: <strong>{bookUpdateStatus.processedCount}</strong>
                            </Typography>
                            
                            <Typography variant="body2" sx={{ mb: 2 }}>
                                Последний обработанный лот (ID): <strong>{bookUpdateStatus.lastProcessedLotId || 'Н/Д'}</strong>
                            </Typography>
                            
                            {bookUpdateStatus.lastProcessedLotTitle && (
                                <Typography variant="body2" sx={{ mb: 2 }}>
                                    Строка состояния обновления: <strong>{bookUpdateStatus.lastProcessedLotTitle}</strong>
                                </Typography>
                            )}
                            
                            <Box sx={{ 
                                display: 'flex', 
                                flexWrap: 'wrap', 
                                gap: 2,
                                flexDirection: { xs: 'column', sm: 'row' } 
                            }}>
                                {bookUpdateStatus.isRunningNow && !bookUpdateStatus.isPaused && (
                                    <Button
                                        variant="outlined"
                                        color="warning"
                                        onClick={handlePause}
                                        sx={{ flex: { xs: '1', sm: '0 0 auto' } }}
                                    >
                                        Приостановить
                                    </Button>
                                )}
                                
                                {bookUpdateStatus.isPaused && (
                                    <Button
                                        variant="outlined"
                                        color="success"
                                        onClick={handleResume}
                                        sx={{ flex: { xs: '1', sm: '0 0 auto' } }}
                                    >
                                        Возобновить
                                    </Button>
                                )}
                                
                                {(!bookUpdateStatus.isRunningNow || bookUpdateStatus.isPaused) && (
                                    <Button
                                        variant="contained"
                                        onClick={handleRunNow}
                                        sx={{ 
                                            backgroundColor: '#E72B3D', 
                                            '&:hover': { backgroundColor: '#c4242f' },
                                            flex: { xs: '1', sm: '0 0 auto' }
                                        }}
                                    >
                                        Запустить сейчас
                                    </Button>
                                )}
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>
                
                <Grid item xs={12} md={6}>
                    <Card elevation={3} sx={{ height: '100%' }}>
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
                </Grid>
            </Grid>
            
            {/* Секция логов */}
            <Card elevation={3} sx={{ mb: 4 }}>
                <CardContent>
                    <Typography variant="h6" component="h3" gutterBottom>
                        Подробная информация / логи
                    </Typography>
                    
                    {Array.isArray(bookUpdateStatus.logs) && bookUpdateStatus.logs.length > 0 ? (
                        <Box sx={{ overflowX: 'auto' }}>
                            {isStructuredLogs ? (
                                <TableContainer component={Paper} elevation={0} sx={{ maxHeight: '400px', overflow: 'auto' }}>
                                    <Table stickyHeader size={isMobile ? "small" : "medium"}>
                                        <TableHead>
                                            <TableRow>
                                                <TableCell>Время</TableCell>
                                                <TableCell>Сообщение</TableCell>
                                                {!isMobile && <TableCell>Операция</TableCell>}
                                                {!isMobile && <TableCell>LotId</TableCell>}
                                                <TableCell>Ошибка?</TableCell>
                                                {!isMobile && <TableCell>Exception</TableCell>}
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
                                                                backgroundColor: entry.isError ? 'rgba(244, 67, 54, 0.08)' : 'inherit'
                                                            }}
                                                        >
                                                            <TableCell sx={{ whiteSpace: 'nowrap' }}>
                                                                {timeLocal.toLocaleString()}
                                                            </TableCell>
                                                            <TableCell>{entry.message}</TableCell>
                                                            {!isMobile && <TableCell>{entry.operationName || '-'}</TableCell>}
                                                            {!isMobile && <TableCell>{entry.lotId ?? '-'}</TableCell>}
                                                            <TableCell>{entry.isError ? 'Да' : 'Нет'}</TableCell>
                                                            {!isMobile && (
                                                                <TableCell sx={{ whiteSpace: 'pre-wrap', maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                                                    {entry.exceptionMessage || ''}
                                                                </TableCell>
                                                            )}
                                                        </TableRow>
                                                    );
                                                })}
                                        </TableBody>
                                    </Table>
                                </TableContainer>
                            ) : (
                                <Box sx={{ p: 2, bgcolor: 'grey.100', borderRadius: 1, maxHeight: '300px', overflow: 'auto' }}>
                                    {bookUpdateStatus.logs.map((log, index) => (
                                        <Box key={index} sx={{ mb: 1 }}>
                                            <Typography variant="body2" component="div">{log}</Typography>
                                            {index < bookUpdateStatus.logs.length - 1 && <Divider sx={{ my: 1 }} />}
                                        </Box>
                                    ))}
                                </Box>
                            )}
                        </Box>
                    ) : (
                        <Typography variant="body1" color="text.secondary">
                            Логи пока отсутствуют.
                        </Typography>
                    )}
                </CardContent>
            </Card>

            {/* Мобильное отображение подробностей обработки (видно только на мобильных) */}
            {isMobile && isStructuredLogs && bookUpdateStatus.logs.length > 0 && (
                <Card elevation={3} sx={{ mb: 4 }}>
                    <CardContent>
                        <Typography variant="h6" component="h3" gutterBottom>
                            Подробности последних событий
                        </Typography>
                        
                        {[...bookUpdateStatus.logs]
                            .reverse()
                            .slice(0, 5)
                            .map((entry, idx) => (
                                <Box key={idx} sx={{ mb: 2, p: 1, borderRadius: 1, bgcolor: entry.isError ? 'rgba(244, 67, 54, 0.08)' : 'rgba(238, 238, 238, 0.5)' }}>
                                    <Typography variant="caption" component="div" fontWeight="bold">
                                        {new Date(entry.timestamp).toLocaleString()}
                                    </Typography>
                                    <Typography variant="body2" component="div" fontWeight={entry.isError ? 'bold' : 'normal'} color={entry.isError ? 'error.main' : 'inherit'}>
                                        {entry.message}
                                    </Typography>
                                    
                                    <Grid container spacing={1} sx={{ mt: 1 }}>
                                        <Grid item xs={6}>
                                            <Typography variant="caption" color="text.secondary">Операция:</Typography>
                                            <Typography variant="body2">{entry.operationName || '-'}</Typography>
                                        </Grid>
                                        <Grid item xs={6}>
                                            <Typography variant="caption" color="text.secondary">LotId:</Typography>
                                            <Typography variant="body2">{entry.lotId ?? '-'}</Typography>
                                        </Grid>
                                        {entry.exceptionMessage && (
                                            <Grid item xs={12}>
                                                <Typography variant="caption" color="text.secondary">Ошибка:</Typography>
                                                <Typography variant="body2" color="error.main" sx={{ 
                                                    whiteSpace: 'pre-wrap', 
                                                    maxHeight: '60px', 
                                                    overflow: 'auto' 
                                                }}>
                                                    {entry.exceptionMessage}
                                                </Typography>
                                            </Grid>
                                        )}
                                    </Grid>
                                </Box>
                            ))}
                            
                        <Typography variant="caption" color="text.secondary">
                            Показаны 5 последних записей. Прокрутите таблицу выше для просмотра всех логов.
                        </Typography>
                    </CardContent>
                </Card>
            )}
        </Box>
    );
};

export default BookUpdate; 