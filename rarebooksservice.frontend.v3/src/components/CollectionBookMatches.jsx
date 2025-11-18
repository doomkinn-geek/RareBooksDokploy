import React from 'react';
import {
    Box, Typography, Grid, Card, CardContent, CardMedia,
    Button, Chip, CircularProgress, Alert, CardActionArea, Paper
} from '@mui/material';
import {
    CheckCircle as CheckIcon,
    TrendingUp as TrendingIcon,
    OpenInNew as OpenIcon
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { API_URL } from '../api';

const CollectionBookMatches = ({ matches = [], onSelectReference, selectedReferenceId, loading = false }) => {
    const navigate = useNavigate();

    const getMatchColor = (score) => {
        if (score >= 0.8) return 'success';
        if (score >= 0.5) return 'warning';
        return 'default';
    };

    const getMatchPercentage = (score) => {
        return Math.round(score * 100);
    };

    if (loading) {
        return (
            <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                <CircularProgress />
            </Box>
        );
    }

    if (!matches || matches.length === 0) {
        return (
            <Paper elevation={1} sx={{ p: 3, textAlign: 'center', bgcolor: 'grey.50' }}>
                <Typography variant="body1" color="text.secondary">
                    Аналоги не найдены
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                    Попробуйте обновить информацию о книге или добавить больше деталей
                </Typography>
            </Paper>
        );
    }

    return (
        <Box>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                Найдено {matches.length} {matches.length === 1 ? 'аналог' : matches.length < 5 ? 'аналога' : 'аналогов'} в базе данных
            </Typography>

            <Grid container spacing={2}>
                {matches.map((match) => {
                    const isSelected = match.matchedBookId === selectedReferenceId;

                    return (
                        <Grid item xs={12} sm={6} md={4} key={match.id || match.matchedBookId}>
                            <Card
                                elevation={isSelected ? 4 : 2}
                                sx={{
                                    height: '100%',
                                    display: 'flex',
                                    flexDirection: 'column',
                                    border: isSelected ? '2px solid' : 'none',
                                    borderColor: 'success.main',
                                    position: 'relative'
                                }}
                            >
                                {isSelected && (
                                    <Box
                                        sx={{
                                            position: 'absolute',
                                            top: 8,
                                            right: 8,
                                            bgcolor: 'success.main',
                                            color: 'white',
                                            borderRadius: '50%',
                                            p: 0.5,
                                            zIndex: 1,
                                            boxShadow: 2
                                        }}
                                    >
                                        <CheckIcon />
                                    </Box>
                                )}

                                <CardActionArea onClick={() => navigate(`/books/${match.matchedBookId}`)}>
                                    {match.thumbnailUrl ? (
                                        <CardMedia
                                            component="img"
                                            height="160"
                                            image={match.thumbnailUrl.startsWith('http') ? match.thumbnailUrl : `${API_URL}${match.thumbnailUrl}`}
                                            alt={match.title}
                                            sx={{ objectFit: 'cover' }}
                                            onError={(e) => {
                                                e.target.style.display = 'none';
                                            }}
                                        />
                                    ) : (
                                        <Box
                                            sx={{
                                                height: 160,
                                                bgcolor: 'grey.200',
                                                display: 'flex',
                                                alignItems: 'center',
                                                justifyContent: 'center'
                                            }}
                                        >
                                            <Typography variant="body2" color="text.secondary">
                                                Нет изображения
                                            </Typography>
                                        </Box>
                                    )}
                                </CardActionArea>

                                <CardContent sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column' }}>
                                    {/* Match score */}
                                    <Box sx={{ mb: 1 }}>
                                        <Chip
                                            label={`Совпадение: ${getMatchPercentage(match.score)}%`}
                                            size="small"
                                            color={getMatchColor(match.score)}
                                        />
                                    </Box>

                                    {/* Название */}
                                    <Typography variant="subtitle2" component="div" gutterBottom sx={{ 
                                        display: '-webkit-box',
                                        WebkitLineClamp: 2,
                                        WebkitBoxOrient: 'vertical',
                                        overflow: 'hidden',
                                        minHeight: '2.5em'
                                    }}>
                                        {match.title}
                                    </Typography>

                                    {/* Описание (краткое) */}
                                    {match.description && (
                                        <Typography variant="caption" color="text.secondary" sx={{ 
                                            mb: 1,
                                            display: '-webkit-box',
                                            WebkitLineClamp: 2,
                                            WebkitBoxOrient: 'vertical',
                                            overflow: 'hidden'
                                        }}>
                                            {match.description}
                                        </Typography>
                                    )}

                                    {/* Информация о продаже */}
                                    <Box sx={{ mt: 'auto', pt: 1 }}>
                                        {match.yearPublished && (
                                            <Typography variant="caption" color="text.secondary" display="block">
                                                Год: {match.yearPublished}
                                            </Typography>
                                        )}

                                        {match.categoryName && (
                                            <Typography variant="caption" color="text.secondary" display="block">
                                                Категория: {match.categoryName}
                                            </Typography>
                                        )}

                                        <Typography variant="h6" color="primary" sx={{ mt: 0.5, fontWeight: 'bold' }}>
                                            {match.price ? `${match.price.toLocaleString('ru-RU')} ₽` : 'Цена не указана'}
                                        </Typography>
                                    </Box>

                                    {/* Кнопки действий */}
                                    <Box sx={{ mt: 2, display: 'flex', gap: 1, flexDirection: 'column' }}>
                                        {!isSelected && onSelectReference && (
                                            <Button
                                                variant="contained"
                                                size="small"
                                                startIcon={<TrendingIcon />}
                                                onClick={() => onSelectReference(match.matchedBookId)}
                                                fullWidth
                                            >
                                                Использовать для оценки
                                            </Button>
                                        )}

                                        {isSelected && (
                                            <Chip
                                                label="Выбран как референс"
                                                color="success"
                                                size="small"
                                                icon={<CheckIcon />}
                                            />
                                        )}

                                        <Button
                                            variant="outlined"
                                            size="small"
                                            endIcon={<OpenIcon />}
                                            onClick={() => navigate(`/books/${match.matchedBookId}`)}
                                            fullWidth
                                        >
                                            Посмотреть детали
                                        </Button>
                                    </Box>
                                </CardContent>
                            </Card>
                        </Grid>
                    );
                })}
            </Grid>

            {matches.length > 0 && (
                <Paper elevation={0} sx={{ p: 2, mt: 3, bgcolor: 'info.light' }}>
                    <Typography variant="body2" color="info.dark">
                        💡 <strong>Подсказка:</strong> Выберите наиболее похожую книгу, чтобы автоматически установить оценку стоимости на основе цены продажи аналога.
                    </Typography>
                </Paper>
            )}
        </Box>
    );
};

export default CollectionBookMatches;

