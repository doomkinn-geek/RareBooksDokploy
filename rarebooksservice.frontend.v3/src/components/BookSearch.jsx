//src/components/BookSearch.jsx:
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { TextField, Button, Box } from '@mui/material';

const BookSearch = () => {
    const [title, setTitle] = useState('');
    const [description, setDescription] = useState('');
    const history = useNavigate();

    const handleSearchByTitle = () => {
        history.push(`/searchByTitle/${title}`);
    };

    const handleSearchByDescription = () => {
        history.push(`/searchByDescription/${description}`);
    };

    return (
        <Box sx={{ my: 2 }}>
            <TextField
                label="Поиск по названию"
                variant="outlined"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                fullWidth
            />
            <Button
                variant="contained"
                color="primary"
                onClick={handleSearchByTitle}
                sx={{ mt: 2 }}
            >
                Search
            </Button>
            <TextField
                label="Поиск по описанию"
                variant="outlined"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                fullWidth
                sx={{ mt: 2 }}
            />
            <Button
                variant="contained"
                color="primary"
                onClick={handleSearchByDescription}
                sx={{ mt: 2 }}
            >
                Search
            </Button>
        </Box>
    );
};

export default BookSearch;
