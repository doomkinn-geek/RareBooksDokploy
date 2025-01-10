// src/components/ErrorMessage.jsx
import React from 'react';
import { Typography } from '@mui/material';

const ErrorMessage = ({ message }) => {
    if (!message) return null;
    return (
        <Typography variant="body1" color="error" sx={{ my: 2 }}>
            {message}
        </Typography>
    );
};

export default ErrorMessage;
