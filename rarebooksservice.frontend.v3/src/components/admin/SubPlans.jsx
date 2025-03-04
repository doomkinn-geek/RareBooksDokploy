import React, { useState, useEffect } from 'react';
import {
    Box, Typography, TextField, Button, Table, TableBody, 
    TableCell, TableContainer, TableHead, TableRow, Paper,
    Alert, CircularProgress, Grid, Card, CardContent,
    useMediaQuery, useTheme, FormControlLabel, Switch
} from '@mui/material';
import axios from 'axios';
import { API_URL, getAuthHeaders } from '../../api';
import Cookies from 'js-cookie';

const SubPlans = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));
    
    const [subPlans, setSubPlans] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    
    // Форма для нового или редактируемого плана
    const [editMode, setEditMode] = useState(false);
    const [planName, setPlanName] = useState('');
    const [monthlyPrice, setMonthlyPrice] = useState('');
    const [yearlyPrice, setYearlyPrice] = useState('');
    const [monthlyRequestLimit, setMonthlyRequestLimit] = useState('');
    const [description, setDescription] = useState('');
    const [isActive, setIsActive] = useState(true);
    const [editingPlanId, setEditingPlanId] = useState(null);
    
    const loadSubscriptionPlans = async () => {
        setLoading(true);
        setError('');
        try {
            const token = Cookies.get('token');
            const response = await axios.get(`${API_URL}/SubscriptionPlans`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setSubPlans(response.data);
        } catch (err) {
            console.error('Error fetching subscription plans:', err);
            setError('Не удалось загрузить планы подписки.');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadSubscriptionPlans();
    }, []);
    
    const clearForm = () => {
        setPlanName('');
        setMonthlyPrice('');
        setYearlyPrice('');
        setMonthlyRequestLimit('');
        setDescription('');
        setIsActive(true);
        setEditingPlanId(null);
        setEditMode(false);
    };
    
    const handleDeletePlan = async (planId) => {
        if (!window.confirm('Вы уверены, что хотите удалить этот план?')) return;
        
        try {
            setLoading(true);
            const token = Cookies.get('token');
            await axios.delete(`${API_URL}/SubscriptionPlans/${planId}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            await loadSubscriptionPlans();
        } catch (error) {
            console.error('Error deleting plan:', error);
            setError('Не удалось удалить план подписки.');
        } finally {
            setLoading(false);
        }
    };
    
    const handleEditPlan = (plan) => {
        setPlanName(plan.name);
        setMonthlyPrice(plan.monthlyPrice?.toString() || plan.price?.toString() || '');
        setYearlyPrice(plan.yearlyPrice?.toString() || '');
        setMonthlyRequestLimit(plan.monthlyRequestLimit?.toString() || '');
        setDescription(plan.description || '');
        setIsActive(plan.isActive !== undefined ? plan.isActive : true);
        setEditingPlanId(plan.id);
        setEditMode(true);
    };
    
    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        
        try {
            // Проверка обязательных полей
            if (!planName.trim()) {
                setError('Название плана обязательно для заполнения');
                return;
            }
            
            if (!monthlyPrice.trim() || isNaN(parseFloat(monthlyPrice)) || parseFloat(monthlyPrice) < 0) {
                setError('Укажите корректную цену (число больше или равно 0)');
                return;
            }
            
            if (!monthlyRequestLimit.trim() || isNaN(parseInt(monthlyRequestLimit, 10)) || parseInt(monthlyRequestLimit, 10) <= 0) {
                setError('Укажите корректный лимит запросов (целое число больше 0)');
                return;
            }
            
            const planData = {
                name: planName.trim(),
                price: parseFloat(monthlyPrice),
                monthlyPrice: parseFloat(monthlyPrice),
                yearlyPrice: yearlyPrice.trim() ? parseFloat(yearlyPrice) : parseFloat(monthlyPrice),
                monthlyRequestLimit: parseInt(monthlyRequestLimit, 10),
                description: description.trim(),
                isActive: isActive
            };
            
            console.log('Отправляем данные плана:', planData);
            
            setLoading(true);
            const token = Cookies.get('token');
            
            if (editMode && editingPlanId) {
                console.log(`Обновляем план с ID ${editingPlanId}`);
                
                await axios.put(`${API_URL}/SubscriptionPlans/${editingPlanId}`, planData, {
                    headers: { 
                        Authorization: `Bearer ${token}`,
                        'Content-Type': 'application/json'
                    }
                });
                
                console.log('План успешно обновлен');
            } else {
                console.log('Создаем новый план');
                
                const response = await axios.post(`${API_URL}/SubscriptionPlans`, planData, {
                    headers: { 
                        Authorization: `Bearer ${token}`,
                        'Content-Type': 'application/json'
                    }
                });
                
                console.log('План успешно создан с ID:', response.data.id);
            }
            
            clearForm();
            await loadSubscriptionPlans();
        } catch (error) {
            console.error('Error saving plan:', error);
            setError(
                `Не удалось сохранить план подписки. ${error.response?.data || error.message || 'Проверьте консоль для деталей.'}`
            );
        } finally {
            setLoading(false);
        }
    };
    
    return (
        <Box>
            <Typography variant="h5" component="h2" gutterBottom sx={{ 
                fontWeight: 'bold', 
                color: '#2c3e50', 
                mb: 3,
                fontSize: { xs: '1.2rem', sm: '1.4rem', md: '1.5rem' }
            }}>
                {editMode ? 'Редактирование плана подписки' : 'Добавление нового плана подписки'}
            </Typography>
            
            {error && (
                <Alert severity="error" sx={{ mb: 3 }}>
                    {error}
                </Alert>
            )}
            
            <Box component="form" onSubmit={handleSubmit} sx={{ mb: 4 }}>
                <Grid container spacing={2}>
                    <Grid item xs={12} sm={6} md={3}>
                        <TextField
                            label="Название плана"
                            fullWidth
                            required
                            variant="outlined"
                            value={planName}
                            onChange={(e) => setPlanName(e.target.value)}
                            sx={{ mb: { xs: 2, sm: 0 } }}
                        />
                    </Grid>
                    <Grid item xs={12} sm={6} md={3}>
                        <TextField
                            label="Цена в месяц"
                            type="number"
                            fullWidth
                            required
                            variant="outlined"
                            value={monthlyPrice}
                            onChange={(e) => setMonthlyPrice(e.target.value)}
                            sx={{ mb: { xs: 2, sm: 0 } }}
                        />
                    </Grid>
                    <Grid item xs={12} sm={6} md={3}>
                        <TextField
                            label="Цена в год"
                            type="number"
                            fullWidth
                            variant="outlined"
                            value={yearlyPrice}
                            onChange={(e) => setYearlyPrice(e.target.value)}
                            sx={{ mb: { xs: 2, sm: 0 } }}
                        />
                    </Grid>
                    <Grid item xs={12} sm={6} md={3}>
                        <TextField
                            label="Лимит запросов в месяц"
                            type="number"
                            fullWidth
                            required
                            variant="outlined"
                            value={monthlyRequestLimit}
                            onChange={(e) => setMonthlyRequestLimit(e.target.value)}
                        />
                    </Grid>
                    <Grid item xs={12}>
                        <TextField
                            label="Описание"
                            fullWidth
                            multiline
                            rows={3}
                            variant="outlined"
                            value={description}
                            onChange={(e) => setDescription(e.target.value)}
                            sx={{ mb: 2 }}
                        />
                    </Grid>
                    <Grid item xs={12}>
                        <FormControlLabel
                            control={
                                <Switch
                                    checked={isActive}
                                    onChange={(e) => setIsActive(e.target.checked)}
                                    color="primary"
                                />
                            }
                            label="План активен"
                            sx={{ mb: 2 }}
                        />
                    </Grid>
                    <Grid item xs={12}>
                        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
                            <Button
                                type="submit"
                                variant="contained"
                                sx={{ backgroundColor: '#E72B3D', '&:hover': { backgroundColor: '#c4242f' } }}
                                disabled={loading}
                            >
                                {editMode ? 'Сохранить изменения' : 'Добавить план'}
                            </Button>
                            
                            {editMode && (
                                <Button
                                    variant="outlined"
                                    onClick={clearForm}
                                    sx={{ borderColor: '#E72B3D', color: '#E72B3D' }}
                                    disabled={loading}
                                >
                                    Отменить
                                </Button>
                            )}
                        </Box>
                    </Grid>
                </Grid>
            </Box>
            
            <Typography variant="h5" component="h2" gutterBottom sx={{ 
                fontWeight: 'bold', 
                color: '#2c3e50', 
                mb: 3,
                fontSize: { xs: '1.2rem', sm: '1.4rem', md: '1.5rem' }
            }}>
                Существующие планы подписки
            </Typography>
            
            {loading ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', my: 4 }}>
                    <CircularProgress />
                </Box>
            ) : (
                <>
                    {/* Desktop view */}
                    {!isMobile && (
                        <TableContainer component={Paper} elevation={2} sx={{ mb: 4, borderRadius: '8px' }}>
                            <Table sx={{ minWidth: 650 }}>
                                <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                                    <TableRow>
                                        <TableCell>Название</TableCell>
                                        <TableCell>Цена (месяц)</TableCell>
                                        <TableCell>Цена (год)</TableCell>
                                        <TableCell>Лимит запросов</TableCell>
                                        <TableCell>Статус</TableCell>
                                        <TableCell>Описание</TableCell>
                                        <TableCell>Действия</TableCell>
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {subPlans.map((plan) => (
                                        <TableRow key={plan.id} hover>
                                            <TableCell>{plan.name}</TableCell>
                                            <TableCell>{plan.monthlyPrice || plan.price} руб.</TableCell>
                                            <TableCell>{plan.yearlyPrice || '-'} руб.</TableCell>
                                            <TableCell>{plan.monthlyRequestLimit}</TableCell>
                                            <TableCell>{plan.isActive ? 'Активен' : 'Неактивен'}</TableCell>
                                            <TableCell>{plan.description || '-'}</TableCell>
                                            <TableCell>
                                                <Box sx={{ display: 'flex', gap: 1 }}>
                                                    <Button
                                                        variant="outlined"
                                                        size="small"
                                                        onClick={() => handleEditPlan(plan)}
                                                        sx={{ borderColor: '#2196f3', color: '#2196f3' }}
                                                    >
                                                        Редактировать
                                                    </Button>
                                                    <Button
                                                        variant="outlined"
                                                        size="small"
                                                        onClick={() => handleDeletePlan(plan.id)}
                                                        sx={{ borderColor: '#f44336', color: '#f44336' }}
                                                    >
                                                        Удалить
                                                    </Button>
                                                </Box>
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    )}
                    
                    {/* Mobile view */}
                    {isMobile && (
                        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mb: 4 }}>
                            {subPlans.map((plan) => (
                                <Card key={plan.id} sx={{ mb: 2 }}>
                                    <CardContent sx={{ p: 2 }}>
                                        <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                            {plan.name}
                                        </Typography>
                                        
                                        <Grid container spacing={1} sx={{ mb: 2 }}>
                                            <Grid item xs={6}>
                                                <Typography variant="body2" color="text.secondary">Цена (месяц):</Typography>
                                                <Typography variant="body1">{plan.monthlyPrice || plan.price} руб.</Typography>
                                            </Grid>
                                            <Grid item xs={6}>
                                                <Typography variant="body2" color="text.secondary">Цена (год):</Typography>
                                                <Typography variant="body1">{plan.yearlyPrice || '-'} руб.</Typography>
                                            </Grid>
                                            <Grid item xs={6}>
                                                <Typography variant="body2" color="text.secondary">Лимит запросов:</Typography>
                                                <Typography variant="body1">{plan.monthlyRequestLimit}</Typography>
                                            </Grid>
                                            <Grid item xs={6}>
                                                <Typography variant="body2" color="text.secondary">Статус:</Typography>
                                                <Typography variant="body1">{plan.isActive ? 'Активен' : 'Неактивен'}</Typography>
                                            </Grid>
                                            {plan.description && (
                                                <Grid item xs={12}>
                                                    <Typography variant="body2" color="text.secondary">Описание:</Typography>
                                                    <Typography variant="body1">{plan.description}</Typography>
                                                </Grid>
                                            )}
                                        </Grid>
                                        
                                        <Box sx={{ display: 'flex', gap: 1 }}>
                                            <Button
                                                variant="outlined"
                                                size="small"
                                                onClick={() => handleEditPlan(plan)}
                                                sx={{ 
                                                    borderColor: '#2196f3', 
                                                    color: '#2196f3',
                                                    flexGrow: 1
                                                }}
                                            >
                                                Редактировать
                                            </Button>
                                            <Button
                                                variant="outlined"
                                                size="small"
                                                onClick={() => handleDeletePlan(plan.id)}
                                                sx={{ 
                                                    borderColor: '#f44336', 
                                                    color: '#f44336',
                                                    flexGrow: 1
                                                }}
                                            >
                                                Удалить
                                            </Button>
                                        </Box>
                                    </CardContent>
                                </Card>
                            ))}
                        </Box>
                    )}
                </>
            )}
        </Box>
    );
};

export default SubPlans; 