import React, { useState, useCallback } from 'react';
import {
    Box, Typography, IconButton, Grid, Paper, CircularProgress, Alert
} from '@mui/material';
import {
    CloudUpload as UploadIcon,
    Delete as DeleteIcon,
    Star as StarIcon,
    StarBorder as StarBorderIcon
} from '@mui/icons-material';
import { useDropzone } from 'react-dropzone';

const CollectionImageUploader = ({ 
    images = [], 
    onUpload, 
    onDelete, 
    onSetMain, 
    uploading = false,
    maxFiles = 10 
}) => {
    const [error, setError] = useState('');

    const onDrop = useCallback(async (acceptedFiles) => {
        setError('');

        if (images.length + acceptedFiles.length > maxFiles) {
            setError(`Можно загрузить максимум ${maxFiles} изображений`);
            return;
        }

        for (const file of acceptedFiles) {
            // Проверка размера (10MB)
            if (file.size > 10 * 1024 * 1024) {
                setError(`Файл ${file.name} слишком большой (максимум 10MB)`);
                continue;
            }

            // Проверка типа
            if (!['image/jpeg', 'image/jpg', 'image/png', 'image/webp'].includes(file.type)) {
                setError(`Файл ${file.name} имеет неподдерживаемый формат (только JPG, PNG, WEBP)`);
                continue;
            }

            try {
                await onUpload(file);
            } catch (err) {
                setError(`Ошибка загрузки ${file.name}: ${err.message}`);
            }
        }
    }, [images, maxFiles, onUpload]);

    const { getRootProps, getInputProps, isDragActive } = useDropzone({
        onDrop,
        accept: {
            'image/jpeg': ['.jpg', '.jpeg'],
            'image/png': ['.png'],
            'image/webp': ['.webp']
        },
        multiple: true,
        disabled: uploading || images.length >= maxFiles
    });

    return (
        <Box>
            {error && (
                <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>
                    {error}
                </Alert>
            )}

            {/* Dropzone */}
            {images.length < maxFiles && (
                <Paper
                    {...getRootProps()}
                    elevation={0}
                    sx={{
                        p: 4,
                        mb: 3,
                        border: '2px dashed',
                        borderColor: isDragActive ? 'primary.main' : 'grey.400',
                        bgcolor: isDragActive ? 'action.hover' : 'grey.50',
                        cursor: uploading ? 'wait' : 'pointer',
                        textAlign: 'center',
                        transition: 'all 0.3s',
                        '&:hover': {
                            borderColor: 'primary.main',
                            bgcolor: 'action.hover'
                        }
                    }}
                >
                    <input {...getInputProps()} />
                    <UploadIcon sx={{ fontSize: 48, color: 'primary.main', mb: 2 }} />
                    <Typography variant="h6" gutterBottom>
                        {isDragActive ? 'Отпустите файлы здесь' : 'Перетащите изображения сюда'}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        или нажмите для выбора файлов
                    </Typography>
                    <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                        JPG, PNG, WEBP до 10MB • Максимум {maxFiles} изображений
                    </Typography>
                    {uploading && (
                        <Box sx={{ mt: 2 }}>
                            <CircularProgress size={24} />
                        </Box>
                    )}
                </Paper>
            )}

            {/* Превью загруженных изображений */}
            {images.length > 0 && (
                <Box>
                    <Typography variant="subtitle2" gutterBottom sx={{ mb: 2 }}>
                        Загруженные изображения ({images.length}/{maxFiles})
                    </Typography>

                    <Grid container spacing={2}>
                        {images.map((image) => (
                            <Grid item xs={6} sm={4} md={3} key={image.id}>
                                <Paper
                                    elevation={2}
                                    sx={{
                                        position: 'relative',
                                        paddingTop: '100%', // Square aspect ratio
                                        overflow: 'hidden',
                                        '&:hover .actions': {
                                            opacity: 1
                                        }
                                    }}
                                >
                                    {/* Изображение */}
                                    <Box
                                        component="img"
                                        src={image.imageUrl ? (image.imageUrl.startsWith('http') ? image.imageUrl : `${image.imageUrl}`) : image.preview}
                                        alt={image.fileName || 'Uploaded image'}
                                        sx={{
                                            position: 'absolute',
                                            top: 0,
                                            left: 0,
                                            width: '100%',
                                            height: '100%',
                                            objectFit: 'cover'
                                        }}
                                    />

                                    {/* Значок главного изображения */}
                                    {image.isMainImage && (
                                        <Box
                                            sx={{
                                                position: 'absolute',
                                                top: 8,
                                                left: 8,
                                                bgcolor: 'primary.main',
                                                color: 'white',
                                                borderRadius: '50%',
                                                p: 0.5,
                                                boxShadow: 2
                                            }}
                                        >
                                            <StarIcon fontSize="small" />
                                        </Box>
                                    )}

                                    {/* Кнопки действий */}
                                    <Box
                                        className="actions"
                                        sx={{
                                            position: 'absolute',
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            bgcolor: 'rgba(0, 0, 0, 0.7)',
                                            display: 'flex',
                                            justifyContent: 'center',
                                            gap: 1,
                                            p: 1,
                                            opacity: 0,
                                            transition: 'opacity 0.3s'
                                        }}
                                    >
                                        {!image.isMainImage && onSetMain && (
                                            <IconButton
                                                size="small"
                                                onClick={() => onSetMain(image.id)}
                                                sx={{ color: 'white' }}
                                                title="Сделать главным"
                                            >
                                                <StarBorderIcon />
                                            </IconButton>
                                        )}

                                        {onDelete && (
                                            <IconButton
                                                size="small"
                                                onClick={() => onDelete(image.id)}
                                                sx={{ color: 'white' }}
                                                title="Удалить"
                                            >
                                                <DeleteIcon />
                                            </IconButton>
                                        )}
                                    </Box>
                                </Paper>
                            </Grid>
                        ))}
                    </Grid>
                </Box>
            )}

            {images.length === 0 && !uploading && (
                <Typography variant="body2" color="text.secondary" sx={{ textAlign: 'center', mt: 2 }}>
                    Изображения не загружены
                </Typography>
            )}
        </Box>
    );
};

export default CollectionImageUploader;

