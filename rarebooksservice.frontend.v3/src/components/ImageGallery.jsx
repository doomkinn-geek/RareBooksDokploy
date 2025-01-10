//src/components/ImageGallery.jsx
import React from 'react';
import { Box, Typography, Grid } from '@mui/material';
import { API_URL } from '../api';

const ImageGallery = ({ images, thumbnails, bookId }) => {
    return (
        <Box sx={{ my: 2 }}>
            <Typography variant="h5">Изображения</Typography>
            <Grid container spacing={2}>
                {images.map((image, index) => (
                    <Grid item xs={3} key={index}>
                        <img src={`${API_URL}/books/${bookId}/images/${image}`} alt="Книга" style={{ width: '100%' }} />
                    </Grid>
                ))}
            </Grid>
            <Typography variant="h5" sx={{ mt: 2 }}>Миниатюры</Typography>
            <Grid container spacing={2}>
                {thumbnails.map((thumbnail, index) => (
                    <Grid item xs={3} key={index}>
                        <img src={`${API_URL}/books/${bookId}/thumbnails/${thumbnail}`} alt="Миниатюры книги" style={{ width: '100%' }} />
                    </Grid>
                ))}
            </Grid>
        </Box>
    );
};

export default ImageGallery;
