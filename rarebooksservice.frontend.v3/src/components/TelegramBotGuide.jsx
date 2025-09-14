import React, { useContext } from 'react';
import {
    Box,
    Paper,
    Typography,
    Card,
    CardContent,
    Grid,
    Alert,
    Chip,
    Step,
    StepLabel,
    Stepper,
    StepContent,
    List,
    ListItem,
    ListItemIcon,
    ListItemText,
    Divider,
    Button
} from '@mui/material';
import {
    Telegram as TelegramIcon,
    Notifications as NotificationsIcon,
    Search as SearchIcon,
    Settings as SettingsIcon,
    CheckCircle as CheckCircleIcon,
    Info as InfoIcon,
    Star as StarIcon,
    AccessTime as AccessTimeIcon,
    MonetizationOn as MonetizationOnIcon,
    LocationOn as LocationOnIcon,
    Category as CategoryIcon,
    Message as MessageIcon
} from '@mui/icons-material';
import { LanguageContext } from '../context/LanguageContext';
import { Link } from 'react-router-dom';
import translations from '../translations';

const TelegramBotGuide = () => {
    const { language } = useContext(LanguageContext);
    const t = translations[language];
    const isRussian = language === 'RU';

    const steps = isRussian ? [
        {
            label: 'Регистрация и подписка',
            description: 'Для использования уведомлений необходима активная подписка на сервис оценки редких книг'
        },
        {
            label: 'Поиск бота в Telegram',
            description: 'Найдите бота @RareBooksReminderBot в Telegram и начните с ним диалог'
        },
        {
            label: 'Получение Telegram ID',
            description: 'Отправьте боту команду /start или любое сообщение, чтобы получить ваш Telegram ID'
        },
        {
            label: 'Подключение аккаунта',
            description: 'Перейдите в настройки уведомлений на сайте и привяжите ваш Telegram ID к аккаунту'
        },
        {
            label: 'Настройка критериев поиска',
            description: 'Создайте настройки уведомлений с интересующими вас параметрами книг'
        },
        {
            label: 'Получение уведомлений',
            description: 'Система автоматически отправит вам уведомления о новых подходящих книгах'
        }
    ] : [
        {
            label: 'Registration and Subscription',
            description: 'Active subscription to the rare books evaluation service is required to use notifications'
        },
        {
            label: 'Find Bot in Telegram',
            description: 'Find bot @RareBooksReminderBot in Telegram and start a conversation with it'
        },
        {
            label: 'Get Telegram ID',
            description: 'Send /start command or any message to the bot to receive your Telegram ID'
        },
        {
            label: 'Connect Account',
            description: 'Go to notification settings on the website and link your Telegram ID to your account'
        },
        {
            label: 'Setup Search Criteria',
            description: 'Create notification settings with book parameters that interest you'
        },
        {
            label: 'Receive Notifications',
            description: 'The system will automatically send you notifications about new matching books'
        }
    ];

    const features = isRussian ? [
        {
            icon: <SearchIcon />,
            title: 'Поиск по ключевым словам',
            description: 'Указывайте ключевые слова для поиска интересных книг (например: "Пушкин", "прижизненное издание", "автограф")'
        },
        {
            icon: <MonetizationOnIcon />,
            title: 'Фильтрация по цене',
            description: 'Устанавливайте минимальную и максимальную цену для отбора книг в нужном ценовом диапазоне'
        },
        {
            icon: <AccessTimeIcon />,
            title: 'Фильтрация по годам',
            description: 'Ограничивайте поиск по годам издания книг (например, только книги до 1917 года)'
        },
        {
            icon: <CategoryIcon />,
            title: 'Выбор категорий',
            description: 'Указывайте конкретные категории книг, которые вас интересуют'
        },
        {
            icon: <LocationOnIcon />,
            title: 'География продаж',
            description: 'Фильтруйте по городам продажи, если важно местоположение'
        },
        {
            icon: <NotificationsIcon />,
            title: 'Гибкая частота',
            description: 'Настраивайте частоту получения уведомлений от 5 минут до недели'
        }
    ] : [
        {
            icon: <SearchIcon />,
            title: 'Keyword Search',
            description: 'Specify keywords to find interesting books (e.g., "Pushkin", "first edition", "autograph")'
        },
        {
            icon: <MonetizationOnIcon />,
            title: 'Price Filtering',
            description: 'Set minimum and maximum prices to select books in the desired price range'
        },
        {
            icon: <AccessTimeIcon />,
            title: 'Year Filtering',
            description: 'Limit search by publication years (e.g., only books before 1917)'
        },
        {
            icon: <CategoryIcon />,
            title: 'Category Selection',
            description: 'Specify particular book categories that interest you'
        },
        {
            icon: <LocationOnIcon />,
            title: 'Sales Geography',
            description: 'Filter by sale cities if location matters'
        },
        {
            icon: <NotificationsIcon />,
            title: 'Flexible Frequency',
            description: 'Configure notification frequency from 5 minutes to a week'
        }
    ];

    const exampleNotification = isRussian ? {
        title: '📚 Найдена интересная книга!',
        content: [
            'Название: А.С. Пушкин. Полное собрание сочинений',
            'Описание: Прижизненное издание 1837 года в отличном состоянии...',
            'Текущая цена: 15,000 ₽',
            'Год издания: 1837',
            'Город: Москва', 
            'Дата окончания торгов: 25.12.2024 18:00',
            'Совпадения: Пушкин, прижизненное издание',
            '',
            '🔗 Перейти к лоту'
        ]
    } : {
        title: '📚 Interesting book found!',
        content: [
            'Title: A.S. Pushkin. Complete Works',
            'Description: Lifetime edition from 1837 in excellent condition...',
            'Current price: 15,000 ₽',
            'Publication year: 1837',
            'City: Moscow',
            'Auction end date: 25.12.2024 18:00',
            'Matches: Pushkin, first edition',
            '',
            '🔗 Go to lot'
        ]
    };

    const tips = isRussian ? [
        'Используйте конкретные ключевые слова: вместо "книга" лучше указать "Толстой", "Достоевский"',
        'Не устанавливайте слишком узкие критерии - можете пропустить интересные предложения',
        'Начните с более широких настроек, затем сужайте по мере необходимости',
        'Регулярно проверяйте историю уведомлений для анализа эффективности настроек',
        'Используйте тестовые уведомления для проверки работы системы',
        'Настройте частоту уведомлений в зависимости от активности на торгах'
    ] : [
        'Use specific keywords: instead of "book" better specify "Tolstoy", "Dostoevsky"',
        'Don\'t set criteria too narrow - you might miss interesting offers',
        'Start with broader settings, then narrow down as needed',
        'Regularly check notification history to analyze setting effectiveness',
        'Use test notifications to verify system operation',
        'Configure notification frequency based on auction activity'
    ];

    return (
        <Box sx={{ maxWidth: 1200, mx: 'auto', p: 3 }}>
            {/* Заголовок */}
            <Typography variant="h4" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <TelegramIcon sx={{ color: '#0088cc' }} />
                {isRussian ? 'Инструкция по работе с Telegram ботом' : 'Telegram Bot User Guide'}
            </Typography>

            {/* Описание */}
            <Alert severity="info" sx={{ mb: 4 }}>
                {isRussian 
                    ? 'Telegram бот @RareBooksReminderBot позволяет получать автоматические уведомления о появлении интересных вам редких книг на торгах. Настройте критерии поиска и получайте персонализированные уведомления прямо в Telegram.'
                    : 'Telegram bot @RareBooksReminderBot allows you to receive automatic notifications about rare books of interest appearing at auctions. Set up search criteria and get personalized notifications directly in Telegram.'
                }
            </Alert>

            {/* Пошаговая инструкция */}
            <Paper sx={{ p: 3, mb: 4 }}>
                <Typography variant="h5" gutterBottom>
                    {isRussian ? 'Пошаговая настройка' : 'Step-by-step Setup'}
                </Typography>
                
                <Stepper orientation="vertical">
                    {steps.map((step, index) => (
                        <Step key={index} active={true}>
                            <StepLabel>
                                <Typography variant="h6">{step.label}</Typography>
                            </StepLabel>
                            <StepContent>
                                <Typography>{step.description}</Typography>
                                {index === 3 && (
                                    <Box sx={{ mt: 2 }}>
                                        <Button
                                            variant="contained"
                                            component={Link}
                                            to="/notifications"
                                            startIcon={<SettingsIcon />}
                                        >
                                            {isRussian ? 'Перейти к настройкам' : 'Go to Settings'}
                                        </Button>
                                    </Box>
                                )}
                            </StepContent>
                        </Step>
                    ))}
                </Stepper>
            </Paper>

            {/* Возможности системы */}
            <Paper sx={{ p: 3, mb: 4 }}>
                <Typography variant="h5" gutterBottom>
                    {isRussian ? 'Возможности системы уведомлений' : 'Notification System Features'}
                </Typography>
                
                <Grid container spacing={3}>
                    {features.map((feature, index) => (
                        <Grid item xs={12} md={6} key={index}>
                            <Card sx={{ height: '100%' }}>
                                <CardContent>
                                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                        {feature.icon}
                                        <Typography variant="h6" sx={{ ml: 1 }}>
                                            {feature.title}
                                        </Typography>
                                    </Box>
                                    <Typography variant="body2" color="text.secondary">
                                        {feature.description}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                    ))}
                </Grid>
            </Paper>

            {/* Пример уведомления */}
            <Paper sx={{ p: 3, mb: 4 }}>
                <Typography variant="h5" gutterBottom>
                    {isRussian ? 'Пример уведомления' : 'Notification Example'}
                </Typography>
                
                <Card sx={{ maxWidth: 400, mx: 'auto', bgcolor: '#0088cc', color: 'white' }}>
                    <CardContent>
                        <Typography variant="h6" gutterBottom>
                            {exampleNotification.title}
                        </Typography>
                        {exampleNotification.content.map((line, index) => (
                            <Typography key={index} variant="body2" sx={{ mb: 0.5 }}>
                                {line}
                            </Typography>
                        ))}
                    </CardContent>
                </Card>
            </Paper>

            {/* Полезные советы */}
            <Paper sx={{ p: 3, mb: 4 }}>
                <Typography variant="h5" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <StarIcon sx={{ color: 'gold' }} />
                    {isRussian ? 'Полезные советы' : 'Helpful Tips'}
                </Typography>
                
                <List>
                    {tips.map((tip, index) => (
                        <ListItem key={index}>
                            <ListItemIcon>
                                <CheckCircleIcon color="success" />
                            </ListItemIcon>
                            <ListItemText primary={tip} />
                        </ListItem>
                    ))}
                </List>
            </Paper>

            {/* Часто задаваемые вопросы */}
            <Paper sx={{ p: 3 }}>
                <Typography variant="h5" gutterBottom>
                    {isRussian ? 'Часто задаваемые вопросы' : 'Frequently Asked Questions'}
                </Typography>
                
                <Box sx={{ mt: 3 }}>
                    <Typography variant="h6" gutterBottom>
                        {isRussian ? 'Как часто приходят уведомления?' : 'How often do notifications come?'}
                    </Typography>
                    <Typography variant="body2" paragraph>
                        {isRussian 
                            ? 'Частота зависит от ваших настроек (от 5 минут до недели) и от количества новых книг, соответствующих вашим критериям. Система проверяет новые поступления каждые 30 минут.'
                            : 'Frequency depends on your settings (from 5 minutes to a week) and the number of new books matching your criteria. The system checks for new arrivals every 30 minutes.'
                        }
                    </Typography>

                    <Typography variant="h6" gutterBottom>
                        {isRussian ? 'Можно ли настроить несколько разных критериев?' : 'Can I set up multiple different criteria?'}
                    </Typography>
                    <Typography variant="body2" paragraph>
                        {isRussian 
                            ? 'Да, вы можете создать неограниченное количество настроек уведомлений с разными критериями поиска для различных типов книг.'
                            : 'Yes, you can create unlimited notification settings with different search criteria for various types of books.'
                        }
                    </Typography>

                    <Typography variant="h6" gutterBottom>
                        {isRussian ? 'Что если бот не отвечает?' : 'What if the bot doesn\'t respond?'}
                    </Typography>
                    <Typography variant="body2" paragraph>
                        {isRussian 
                            ? 'Убедитесь, что вы правильно написали имя бота: @RareBooksReminderBot. Если проблема сохраняется, попробуйте перезапустить диалог командой /start или обратитесь в службу поддержки.'
                            : 'Make sure you spelled the bot name correctly: @RareBooksReminderBot. If the problem persists, try restarting the conversation with /start command or contact support.'
                        }
                    </Typography>

                    <Typography variant="h6" gutterBottom>
                        {isRussian ? 'Как отключить уведомления?' : 'How to disable notifications?'}
                    </Typography>
                    <Typography variant="body2">
                        {isRussian 
                            ? 'Вы можете отключить уведомления в настройках на сайте, отвязать Telegram аккаунт или просто отключить конкретные настройки уведомлений.'
                            : 'You can disable notifications in website settings, unlink your Telegram account, or simply turn off specific notification settings.'
                        }
                    </Typography>
                </Box>
            </Paper>
        </Box>
    );
};

export default TelegramBotGuide;
