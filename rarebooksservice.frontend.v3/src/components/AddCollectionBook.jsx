import React, { useState } from 'react';
import {
    Box, Typography, TextField, Button, Paper, Alert, CircularProgress, Grid
} from '@mui/material';
import { Save as SaveIcon, ArrowBack as BackIcon, Search as SearchIcon } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { API_URL } from '../api';
import Cookies from 'js-cookie';
import CollectionImageUploader from './CollectionImageUploader';

const AddCollectionBook = () => {
    const navigate = useNavigate();
    const [formData, setFormData] = useState({
        title: '',
        author: '',
        yearPublished: '',
        description: '',
        notes: '',
        purchasePrice: '',
        purchaseDate: ''
    });
    const [images, setImages] = useState([]);
    const [loading, setLoading] = useState(false);
    const [uploading, setUploading] = useState(false);
    const [error, setError] = useState('');
    const [newBookId, setNewBookId] = useState(null);

    const handleChange = (e) => {
        setFormData({
            ...formData,
            [e.target.name]: e.target.value
        });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');

        if (!formData.title.trim()) {
            setError('Название книги обязательно для заполнения');
            return;
        }

        try {
            setLoading(true);
            const token = Cookies.get('token');

            const bookData = {
                title: formData.title,
                author: formData.author || null,
                yearPublished: formData.yearPublished ? parseInt(formData.yearPublished) : null,
                description: formData.description || null,
                notes: formData.notes || null,
                purchasePrice: formData.purchasePrice ? parseFloat(formData.purchasePrice) : null,
                purchaseDate: formData.purchaseDate || null
            };

            const response = await axios.post(`${API_URL}/usercollection`, bookData, {
                headers: { Authorization: `Bearer ${token}` }
            });

            const bookId = response.data.id;
            setNewBookId(bookId);

            // Если есть изображения, загружаем их
            if (images.length > 0) {
                await uploadImages(bookId);
            }

            // Переходим на страницу книги
            navigate(`/collection/${bookId}`);
        } catch (err) {
            console.error('Error adding book:', err);
            setError(err.response?.data?.error || 'Не удалось добавить книгу');
        } finally {
            setLoading(false);
        }
    };

    const uploadImages = async (bookId) => {
        const token = Cookies.get('token');
        
        for (const image of images) {
            if (image.file) {
                const formData = new FormData();
                formData.append('file', image.file);

                try {
                    await axios.post(
                        `${API_URL}/usercollection/${bookId}/images`,
                        formData,
                        {
                            headers: {
                                Authorization: `Bearer ${token}`,
                                'Content-Type': 'multipart/form-data'
                            }
                        }
                    );
                } catch (err) {
                    console.error('Error uploading image:', err);
                }
            }
        }
    };

    const handleImageUpload = async (file) => {
        setUploading(true);
        try {
            // Создаем preview
            const preview = URL.createObjectURL(file);
            const newImage = {
                id: Date.now(), // Временный ID
                file: file,
                preview: preview,
                fileName: file.name,
                isMainImage: images.length === 0 // Первое изображение делаем главным
            };

            setImages([...images, newImage]);
        } catch (err) {
            console.error('Error preparing image:', err);
            throw err;
        } finally {
            setUploading(false);
        }
    };

    const handleImageDelete = (imageId) => {
        const updatedImages = images.filter(img => img.id !== imageId);
        
        // Если удалили главное изображение, делаем главным первое из оставшихся
        if (images.find(img => img.id === imageId)?.isMainImage && updatedImages.length > 0) {
            updatedImages[0].isMainImage = true;
        }
        
        setImages(updatedImages);
    };

    const handleSetMainImage = (imageId) => {
        setImages(images.map(img => ({
            ...img,
            isMainImage: img.id === imageId
        })));
    };

    return (
        <Box sx={{ maxWidth: 900, mx: 'auto', p: { xs: 2, md: 3 } }}>
            <Box sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 2 }}>
                <Button
                    startIcon={<BackIcon />}
                    onClick={() => navigate('/collection')}
                    variant="outlined"
                >
                    Назад
                </Button>
                <Typography variant="h4" component="h1" sx={{ fontWeight: 'bold', flexGrow: 1 }}>
                    Добавить книгу в коллекцию
                </Typography>
            </Box>

            {error && (
                <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>
                    {error}
                </Alert>
            )}

            <Paper elevation={2} sx={{ p: 3 }}>
                <form onSubmit={handleSubmit}>
                    <Grid container spacing={3}>
                        <Grid item xs={12}>
                            <TextField
                                label="Название книги"
                                name="title"
                                value={formData.title}
                                onChange={handleChange}
                                fullWidth
                                required
                                variant="outlined"
                            />
                        </Grid>

                        <Grid item xs={12} sm={6}>
                            <TextField
                                label="Автор"
                                name="author"
                                value={formData.author}
                                onChange={handleChange}
                                fullWidth
                                variant="outlined"
                            />
                        </Grid>

                        <Grid item xs={12} sm={6}>
                            <TextField
                                label="Год издания"
                                name="yearPublished"
                                type="number"
                                value={formData.yearPublished}
                                onChange={handleChange}
                                fullWidth
                                variant="outlined"
                                inputProps={{ min: 1000, max: new Date().getFullYear() }}
                            />
                        </Grid>

                        <Grid item xs={12}>
                            <TextField
                                label="Описание и состояние"
                                name="description"
                                value={formData.description}
                                onChange={handleChange}
                                fullWidth
                                multiline
                                rows={4}
                                variant="outlined"
                                placeholder="Опишите состояние книги, особенности издания..."
                            />
                        </Grid>

                        <Grid item xs={12}>
                            <TextField
                                label="Личные заметки"
                                name="notes"
                                value={formData.notes}
                                onChange={handleChange}
                                fullWidth
                                multiline
                                rows={3}
                                variant="outlined"
                                placeholder="Ваши заметки о книге..."
                            />
                        </Grid>

                        <Grid item xs={12}>
                            <Typography variant="h6" gutterBottom sx={{ mt: 2, mb: 1 }}>
                                Информация о покупке (необязательно)
                            </Typography>
                        </Grid>

                        <Grid item xs={12} sm={6}>
                            <TextField
                                label="Цена покупки"
                                name="purchasePrice"
                                type="number"
                                value={formData.purchasePrice}
                                onChange={handleChange}
                                fullWidth
                                variant="outlined"
                                InputProps={{
                                    startAdornment: <Box component="span" sx={{ mr: 1 }}>₽</Box>,
                                }}
                                inputProps={{ min: 0, step: 0.01 }}
                                helperText="Сколько заплатили за книгу"
                            />
                        </Grid>

                        <Grid item xs={12} sm={6}>
                            <TextField
                                label="Дата покупки"
                                name="purchaseDate"
                                type="date"
                                value={formData.purchaseDate}
                                onChange={handleChange}
                                fullWidth
                                variant="outlined"
                                InputLabelProps={{ shrink: true }}
                                inputProps={{ max: new Date().toISOString().split('T')[0] }}
                                helperText="Когда приобрели книгу"
                            />
                        </Grid>

                        <Grid item xs={12}>
                            <Typography variant="h6" gutterBottom sx={{ mt: 2, mb: 2 }}>
                                Изображения
                            </Typography>
                            <CollectionImageUploader
                                images={images}
                                onUpload={handleImageUpload}
                                onDelete={handleImageDelete}
                                onSetMain={handleSetMainImage}
                                uploading={uploading}
                                maxFiles={10}
                            />
                        </Grid>

                        <Grid item xs={12}>
                            <Box sx={{ display: 'flex', gap: 2, justifyContent: 'flex-end', mt: 2 }}>
                                <Button
                                    variant="outlined"
                                    onClick={() => navigate('/collection')}
                                    disabled={loading}
                                >
                                    Отмена
                                </Button>

                                <Button
                                    type="submit"
                                    variant="contained"
                                    startIcon={loading ? <CircularProgress size={20} /> : <SaveIcon />}
                                    disabled={loading || !formData.title.trim()}
                                >
                                    {loading ? 'Сохранение...' : 'Сохранить и найти аналоги'}
                                </Button>
                            </Box>
                        </Grid>
                    </Grid>
                </form>
            </Paper>

            <Paper elevation={1} sx={{ p: 2, mt: 3, bgcolor: 'info.light', color: 'info.contrastText' }}>
                <Typography variant="body2">
                    💡 <strong>Совет:</strong> После сохранения книги система автоматически найдет похожие книги из базы данных для оценки стоимости вашего экземпляра.
                </Typography>
            </Paper>
        </Box>
    );
};

export default AddCollectionBook;

