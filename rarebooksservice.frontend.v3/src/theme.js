import { createTheme, responsiveFontSizes } from '@mui/material/styles';

const baseTheme = createTheme({
    palette: {
        primary: {
            main: '#E72B3D',
        },
        secondary: {
            main: '#2c3e50',
        },
        background: {
            default: '#FFFFFF',
            paper: '#F8F9FA',
        },
        text: {
            primary: '#333333',
            secondary: '#666666',
        },
    },
    typography: {
        fontFamily: '"Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
        h1: {
            fontWeight: 600,
            fontSize: '2.5rem',
            '@media (max-width:600px)': {
                fontSize: '2rem',
            },
        },
        h4: {
            fontWeight: 600,
            '@media (max-width:600px)': {
                fontSize: '1.4rem',
            },
        },
        body1: {
            fontSize: '1rem',
        },
        button: {
            textTransform: 'none',
            fontWeight: 500,
        },
    },
    shape: {
        borderRadius: 8,
    },
    components: {
        MuiButton: {
            styleOverrides: {
                root: {
                    boxShadow: 'none',
                    '&:hover': {
                        boxShadow: 'none',
                    },
                    '@media (max-width:600px)': {
                        padding: '8px 16px',
                        fontSize: '0.875rem',
                    },
                },
            },
        },
        MuiCard: {
            styleOverrides: {
                root: {
                    '@media (max-width:600px)': {
                        margin: '8px 0',
                    },
                },
            },
        },
        MuiContainer: {
            styleOverrides: {
                root: {
                    '@media (max-width:600px)': {
                        padding: '0 12px',
                    },
                },
            },
        },
        MuiDialog: {
            styleOverrides: {
                paper: {
                    '@media (max-width:600px)': {
                        margin: '16px',
                        width: 'calc(100% - 32px)',
                        maxHeight: 'calc(100% - 32px)',
                    },
                },
            },
        },
    },
    breakpoints: {
        values: {
            xs: 0,
            sm: 600,
            md: 960,
            lg: 1280,
            xl: 1920,
        },
    },
});

// Применяем автоматическую адаптацию размеров шрифта
const theme = responsiveFontSizes(baseTheme);

export default theme;
