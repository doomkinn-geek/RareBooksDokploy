//src/components/UserDetailsPage.jsx
import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { getUserById, getUserSearchHistory } from '../api';
import { Typography, Table, TableBody, TableCell, TableHead, TableRow, TablePagination } from '@mui/material';

const UserDetailsPage = () => {
    const { userId } = useParams();
    const [user, setUser] = useState(null);
    const [searchHistory, setSearchHistory] = useState([]);
    const [loading, setLoading] = useState(true);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    useEffect(() => {
        const fetchUserData = async () => {
            try {
                const userResponse = await getUserById(userId);
                setUser(userResponse.data);

                const historyResponse = await getUserSearchHistory(userId);
                setSearchHistory(historyResponse.data);
            } catch (error) {
                console.error('Error fetching user data:', error);
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

    if (loading) {
        return <div className="loading-indicator">Загрузка...</div>;
    }

    if (!user) {
        return <div className="no-user-message">Пользователь не найден</div>;
    }

    return (
        <div className="user-details-container">
            <div className="user-details-header">
                <Typography variant="h4" gutterBottom>
                    Подробности о пользователе:
                </Typography>
                <Typography variant="body1">E-mail: {user.email}</Typography>
                <Typography variant="body1">Роль: {user.role}</Typography>
                <Typography variant="body1">Подписка: {user.hasSubscription ? 'Да' : 'Нет'}</Typography>
            </div>

            <div className="user-history-section">
                <Typography variant="h5" gutterBottom className="section-title">
                    История поиска:
                </Typography>
                <div className="user-history-table-wrapper">
                    <Table className="user-history-table">
                        <TableHead>
                            <TableRow>
                                <TableCell>Дата</TableCell>
                                <TableCell>Запрос</TableCell>
                                <TableCell>Тип</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {searchHistory.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage).map(history => (
                                <TableRow key={history.id}>
                                    <TableCell>{new Date(history.searchDate).toLocaleString()}</TableCell>
                                    <TableCell>{history.query}</TableCell>
                                    <TableCell>{history.searchType}</TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                </div>
                <TablePagination
                    component="div"
                    count={searchHistory.length}
                    page={page}
                    onPageChange={handleChangePage}
                    rowsPerPage={rowsPerPage}
                    onRowsPerPageChange={handleChangeRowsPerPage}
                    rowsPerPageOptions={[5, 10, 25]}
                />
            </div>
        </div>
    );
};

export default UserDetailsPage;
