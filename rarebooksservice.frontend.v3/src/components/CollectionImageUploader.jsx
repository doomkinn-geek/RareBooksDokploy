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
    const [processingFiles, setProcessingFiles] = useState(new Set());

    const onDrop = useCallback(async (acceptedFiles) => {
        setError('');

        if (images.length + acceptedFiles.length > maxFiles) {
            setError(`Можно загрузить максимум ${maxFiles} изображений`);
            return;
        }

        // Добавляем файлы в список обрабатываемых
        const newProcessing = new Set(processingFiles);
        acceptedFiles.forEach(file => newProcessing.add(file.name));
        setProcessingFiles(newProcessing);

        for (const file of acceptedFiles) {
            // Проверка размера (10MB)
            if (file.size > 10 * 1024 * 1024) {
                setError(`Файл ${file.name} слишком большой (максимум 10MB)`);
                newProcessing.delete(file.name);
                setProcessingFiles(new Set(newProcessing));
                continue;
            }

            // Проверка типа
            if (!['image/jpeg', 'image/jpg', 'image/png', 'image/webp'].includes(file.type)) {
                setError(`Файл ${file.name} имеет неподдерживаемый формат (только JPG, PNG, WEBP)`);
                newProcessing.delete(file.name);
                setProcessingFiles(new Set(newProcessing));
                continue;
            }

            try {
                // Ждем завершения загрузки файла
                await onUpload(file);
                // Удаляем файл из списка обрабатываемых после успешной загрузки
                newProcessing.delete(file.name);
                setProcessingFiles(new Set(newProcessing));
            } catch (err) {
                setError(`Ошибка загрузки ${file.name}: ${err.message}`);
                newProcessing.delete(file.name);
                setProcessingFiles(new Set(newProcessing));
            }
        }
    }, [images, maxFiles, onUpload, processingFiles]);

    // Проверяем, есть ли файлы в процессе загрузки
    const isProcessing = processingFiles.size > 0 || uploading;

    const { getRootProps, getInputProps, isDragActive } = useDropzone({
        onDrop,
        accept: {
            'image/jpeg': ['.jpg', '.jpeg'],
            'image/png': ['.png'],
            'image/webp': ['.webp']
        },
        multiple: true,
        disabled: isProcessing || images.length >= maxFiles
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
                        cursor: isProcessing ? 'wait' : 'pointer',
                        textAlign: 'center',
                        transition: 'all 0.3s',
                        '&:hover': {
                            borderColor: 'primary.main',
                            bgcolor: 'action.hover'
                        }
                    }}
                >
                    <input {...getInputProps()} />
                    <UploadIcon sx={{ fontSize: { xs: 40, sm: 48 }, color: 'primary.main', mb: 2 }} />
                    <Typography variant="h6" gutterBottom sx={{ fontSize: { xs: '1rem', sm: '1.25rem' } }}>
                        {isDragActive ? 'Отпустите файлы здесь' : 'Перетащите изображения сюда'}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        или нажмите для выбора файлов
                    </Typography>
                    <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                        JPG, PNG, WEBP до 10MB • Максимум {maxFiles} изображений
                    </Typography>
                    {isProcessing && (
                        <Box sx={{ mt: 2 }}>
                            <CircularProgress size={24} />
                            <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                                Загрузка...
                            </Typography>
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
                                                boxShadow: 2,
                                                zIndex: 1
                                            }}
                                        >
                                            <StarIcon fontSize="small" />
                                        </Box>
                                    )}

                                    {/* Кнопки действий - всегда видны на мобильных, на hover на десктопе */}
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
                                            opacity: { xs: 1, md: 0 }, // Всегда видны на мобильных
                                            transition: 'opacity 0.3s'
                                        }}
                                    >
                                        {!image.isMainImage && onSetMain && (
                                            <IconButton
                                                size="small"
                                                onClick={() => onSetMain(image.id)}
                                                sx={{ 
                                                    color: 'white',
                                                    bgcolor: 'rgba(255, 255, 255, 0.1)',
                                                    '&:hover': { bgcolor: 'rgba(255, 255, 255, 0.2)' }
                                                }}
                                                title="Сделать главным"
                                            >
                                                <StarBorderIcon fontSize="small" />
                                            </IconButton>
                                        )}

                                        {onDelete && (
                                            <IconButton
                                                size="small"
                                                onClick={() => onDelete(image.id)}
                                                sx={{ 
                                                    color: 'white',
                                                    bgcolor: 'rgba(255, 255, 255, 0.1)',
                                                    '&:hover': { bgcolor: 'rgba(255, 255, 255, 0.2)' }
                                                }}
                                                title="Удалить"
                                            >
                                                <DeleteIcon fontSize="small" />
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

