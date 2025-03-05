import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import Cookies from 'js-cookie';
import {
    Box, Typography, TableContainer, Table, TableHead, TableBody, TableRow, TableCell,
    Paper, Button, Card, CardContent, Grid, Dialog, DialogTitle, DialogContent, 
    DialogActions, FormControlLabel, Checkbox, MenuItem, Select, FormControl, InputLabel
} from '@mui/material';
import { API_URL, getUsers, updateUserSubscription, updateUserRole, getUserById } from '../../api';

const UsersPanel = () => {
    const navigate = useNavigate();
    const [users, setUsers] = useState([]);
    const [error, setError] = useState('');
    const [subPlans, setSubPlans] = useState([]);
    const [loadingPlans, setLoadingPlans] = useState(false);
    const [isMobile, setIsMobile] = useState(window.innerWidth < 768);

    // Состояние модального окна для подписок
    const [showSubModal, setShowSubModal] = useState(false);
    const [selectedUserForSub, setSelectedUserForSub] = useState(null);
    const [selectedPlanForSub, setSelectedPlanForSub] = useState(0);
    const [autoRenewForSub, setAutoRenewForSub] = useState(false);

    // Effect для проверки размера экрана
    useEffect(() => {
        const handleResize = () => setIsMobile(window.innerWidth < 768);
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);

    // Загрузка пользователей
    const loadUsers = async () => {
        try {
            const response = await getUsers();
            setUsers(response.data);
        } catch (err) {
            console.error('Error fetching users:', err);
            setError('Ошибка при загрузке пользователей');
        }
    };

    useEffect(() => {
        loadUsers();
    }, []);

    // Загрузка планов подписки
    const loadSubscriptionPlans = async () => {
        setLoadingPlans(true);
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
            setLoadingPlans(false);
        }
    };

    useEffect(() => {
        loadSubscriptionPlans();
    }, []);

    // Открываем модалку для изменения подписки
    function openSubscriptionModal(user) {
        setSelectedUserForSub(user);
        const activePlanId = user.currentSubscription?.subscriptionPlanId || 0;
        setSelectedPlanForSub(activePlanId);
        setAutoRenewForSub(user.currentSubscription?.autoRenew || false);
        setShowSubModal(true);
    }

    // Обработка назначения плана подписки
    async function handleAssignSubscriptionPlan() {
        try {
            const token = Cookies.get('token');
            const userId = selectedUserForSub.id;

            const requestBody = {
                planId: Number(selectedPlanForSub),
                autoRenew: autoRenewForSub
            };

            await axios.post(`${API_URL}/admin/user/${userId}/assign-subscription-plan`,
                requestBody,
                { headers: { Authorization: `Bearer ${token}` }
            });

            alert('Подписка обновлена');
            setShowSubModal(false);

            // Обновим список пользователей, чтобы увидеть новые данные
            loadUsers();
        } catch (err) {
            console.error('Ошибка при назначении плана подписки:', err);
            alert('Ошибка при назначении плана');
        }
    }

    // Методы работы с пользователями
    const handleUpdateUserSubscription = async (userId, hasSubscription) => {
        try {
            await updateUserSubscription(userId, hasSubscription);
            setUsers((prev) =>
                prev.map((user) =>
                    user.id === userId ? { ...user, hasSubscription } : user
                )
            );
        } catch (err) {
            console.error('Error updating subscription:', err);
            setError('Ошибка при обновлении подписки');
        }
    };

    const handleUpdateUserRole = async (userId, role) => {
        try {
            await updateUserRole(userId, role);
            setUsers((prev) =>
                prev.map((user) => (user.id === userId ? { ...user, role } : user))
            );
        } catch (err) {
            console.error('Error updating role:', err);
            setError('Ошибка при обновлении роли');
        }
    };

    const handleViewDetails = async (userId) => {
        try {
            await getUserById(userId);
            navigate(`/user/${userId}`);
        } catch (err) {
            console.error('Error fetching user details:', err);
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
                Управление пользователями
            </Typography>
            
            {error && (
                <Typography color="error" sx={{ mb: 2 }}>
                    {error}
                </Typography>
            )}
            
            {/* Desktop view - полная таблица для десктопа */}
            {!isMobile && (
                <TableContainer component={Paper} elevation={2} sx={{ mb: 4, borderRadius: '8px' }}>
                    <Table sx={{ minWidth: 650 }}>
                        <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
                            <TableRow>
                                <TableCell>Email</TableCell>
                                <TableCell>Роль</TableCell>
                                <TableCell>Активна?</TableCell>
                                <TableCell>План</TableCell>
                                <TableCell>Автопродление</TableCell>
                                <TableCell>Лимит запросов</TableCell>
                                <TableCell>Действия</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {users.map((user) => {
                                const sub = user.currentSubscription;
                                return (
                                    <TableRow key={user.id} hover>
                                        <TableCell>{user.email}</TableCell>
                                        <TableCell>{user.role || '-'}</TableCell>
                                        <TableCell>{sub ? 'Да' : 'Нет'}</TableCell>
                                        <TableCell>{sub?.subscriptionPlan?.name || '-'}</TableCell>
                                        <TableCell>{sub?.autoRenew ? 'Да' : 'Нет'}</TableCell>
                                        <TableCell>{sub?.subscriptionPlan?.monthlyRequestLimit ?? '-'}</TableCell>
                                        <TableCell>
                                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                                                <Button 
                                                    variant="contained" 
                                                    size="small"
                                                    onClick={() => openSubscriptionModal(user)}
                                                    sx={{ 
                                                        backgroundColor: '#E72B3D',
                                                        '&:hover': { backgroundColor: '#c4242f' }
                                                    }}
                                                >
                                                    Изменить подписку
                                                </Button>
                                                
                                                <Button 
                                                    variant="outlined" 
                                                    size="small"
                                                    onClick={() => handleViewDetails(user.id)}
                                                    sx={{ borderColor: '#E72B3D', color: '#E72B3D' }}
                                                >
                                                    Детали
                                                </Button>
                                                
                                                {(!user.role || user.role.toLowerCase() !== 'admin') && (
                                                    <Button 
                                                        variant="outlined" 
                                                        size="small"
                                                        onClick={() => handleUpdateUserRole(user.id, 'admin')}
                                                        sx={{ borderColor: '#2196f3', color: '#2196f3' }}
                                                    >
                                                        Сделать админом
                                                    </Button>
                                                )}
                                                
                                                {user.role && user.role.toLowerCase() === 'admin' && user.email !== 'test@test.com' && (
                                                    <Button 
                                                        variant="outlined" 
                                                        size="small"
                                                        onClick={() => handleUpdateUserRole(user.id, 'user')}
                                                        sx={{ borderColor: '#f44336', color: '#f44336' }}
                                                    >
                                                        Снять админа
                                                    </Button>
                                                )}
                                            </Box>
                                        </TableCell>
                                    </TableRow>
                                );
                            })}
                        </TableBody>
                    </Table>
                </TableContainer>
            )}
            
            {/* Mobile view - карточки вместо таблицы для мобильных */}
            {isMobile && (
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mb: 4 }}>
                    {users.map((user) => {
                        const sub = user.currentSubscription;
                        return (
                            <Card key={user.id} sx={{ mb: 2, overflow: 'visible' }}>
                                <CardContent sx={{ p: 2 }}>
                                    <Typography variant="subtitle1" fontWeight="bold" gutterBottom>
                                        {user.email}
                                    </Typography>
                                    
                                    <Grid container spacing={1} sx={{ mb: 2 }}>
                                        <Grid item xs={6}>
                                            <Typography variant="body2" color="text.secondary">Роль:</Typography>
                                            <Typography variant="body1">{user.role || '-'}</Typography>
                                        </Grid>
                                        <Grid item xs={6}>
                                            <Typography variant="body2" color="text.secondary">Активна:</Typography>
                                            <Typography variant="body1">{sub ? 'Да' : 'Нет'}</Typography>
                                        </Grid>
                                        <Grid item xs={6}>
                                            <Typography variant="body2" color="text.secondary">План:</Typography>
                                            <Typography variant="body1">{sub?.subscriptionPlan?.name || '-'}</Typography>
                                        </Grid>
                                        <Grid item xs={6}>
                                            <Typography variant="body2" color="text.secondary">Автопродление:</Typography>
                                            <Typography variant="body1">{sub?.autoRenew ? 'Да' : 'Нет'}</Typography>
                                        </Grid>
                                        <Grid item xs={12}>
                                            <Typography variant="body2" color="text.secondary">Лимит запросов:</Typography>
                                            <Typography variant="body1">{sub?.subscriptionPlan?.monthlyRequestLimit ?? '-'}</Typography>
                                        </Grid>
                                    </Grid>
                                    
                                    <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                                        <Button 
                                            variant="contained" 
                                            size="small"
                                            onClick={() => openSubscriptionModal(user)}
                                            sx={{ 
                                                backgroundColor: '#E72B3D',
                                                '&:hover': { backgroundColor: '#c4242f' },
                                                flexGrow: 1
                                            }}
                                        >
                                            Изменить подписку
                                        </Button>
                                        
                                        <Button 
                                            variant="outlined" 
                                            size="small"
                                            onClick={() => handleViewDetails(user.id)}
                                            sx={{ borderColor: '#E72B3D', color: '#E72B3D', flexGrow: 1 }}
                                        >
                                            Детали
                                        </Button>
                                        
                                        {(!user.role || user.role.toLowerCase() !== 'admin') && (
                                            <Button 
                                                variant="outlined" 
                                                size="small"
                                                onClick={() => handleUpdateUserRole(user.id, 'admin')}
                                                sx={{ borderColor: '#2196f3', color: '#2196f3', flexGrow: 1 }}
                                            >
                                                Сделать админом
                                            </Button>
                                        )}
                                        
                                        {user.role && user.role.toLowerCase() === 'admin' && user.email !== 'test@test.com' && (
                                            <Button 
                                                variant="outlined" 
                                                size="small"
                                                onClick={() => handleUpdateUserRole(user.id, 'user')}
                                                sx={{ borderColor: '#f44336', color: '#f44336', flexGrow: 1 }}
                                            >
                                                Снять админа
                                            </Button>
                                        )}
                                    </Box>
                                </CardContent>
                            </Card>
                        );
                    })}
                </Box>
            )}

            {/* Модальное окно для назначения подписки */}
            <Dialog open={showSubModal} onClose={() => setShowSubModal(false)} maxWidth="sm" fullWidth>
                <DialogTitle>Изменить подписку пользователя</DialogTitle>
                <DialogContent>
                    {selectedUserForSub && (
                        <Box sx={{ mt: 2 }}>
                            <Typography variant="subtitle1" gutterBottom>
                                Пользователь: {selectedUserForSub.email}
                            </Typography>
                            
                            <FormControl fullWidth sx={{ mt: 2 }}>
                                <InputLabel id="subscription-plan-label">План подписки</InputLabel>
                                <Select
                                    labelId="subscription-plan-label"
                                    value={selectedPlanForSub}
                                    onChange={(e) => setSelectedPlanForSub(e.target.value)}
                                    label="План подписки"
                                >
                                    <MenuItem value={0}>Нет подписки</MenuItem>
                                    {subPlans.map((plan) => (
                                        <MenuItem key={plan.id} value={plan.id}>
                                            {plan.name} - {plan.price} руб.
                                        </MenuItem>
                                    ))}
                                </Select>
                            </FormControl>
                            
                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={autoRenewForSub}
                                        onChange={(e) => setAutoRenewForSub(e.target.checked)}
                                    />
                                }
                                label="Автоматическое продление"
                                sx={{ mt: 2 }}
                            />
                        </Box>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setShowSubModal(false)}>Отмена</Button>
                    <Button 
                        onClick={handleAssignSubscriptionPlan} 
                        variant="contained" 
                        color="primary"
                    >
                        Сохранить
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default UsersPanel; 