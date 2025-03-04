// Словарь переводов для всех текстов интерфейса
const translations = {
    // Русский язык (по умолчанию)
    RU: {
        // Навигация и общие элементы
        login: 'Войти',
        register: 'Регистрация',
        logout: 'Выйти из системы',
        search: 'Искать',
        exactMatch: 'Точное соответствие',
        getSubscription: 'Оформить подписку',
        adminPanel: 'Панель администратора',
        
        // Главный заголовок
        mainTitle: 'Оценка антикварных книг',
        mainSubtitle: 'Узнайте рыночную стоимость вашей книги с помощью базы данных реальных продаж',
        startEvaluation: 'Начать оценку',
        
        // Поиск
        titleSearch: 'Поиск по названию',
        bookTitle: 'Название книги',
        advancedSearch: 'Расширенный поиск для оценки книг',
        descriptionSearch: 'Поиск по описанию',
        descriptionSearchHint: 'Поиск книг по ключевым словам в описании. Введите фрагмент текста, который может содержаться в описании антикварной книги.',
        keywordsPlaceholder: 'Ключевые слова из описания',
        priceRangeSearch: 'Поиск по ценовому диапазону',
        priceRangeSearchHint: 'Найдите книги в определенном ценовом диапазоне для более точной оценки стоимости вашей коллекции.',
        minPrice: 'Минимальная цена',
        maxPrice: 'Максимальная цена',
        
        // Информационный блок
        howItWorks: 'Как работает оценка антикварных книг',
        serviceDescription: 'Наш сервис предоставляет доступ к обширной базе данных реальных продаж антикварных книг. Алгоритм позволяет определить примерную рыночную стоимость вашей книги на основе анализа подобных экземпляров, которые уже были проданы.',
        findAnalogs: 'Поиск аналогов',
        findAnalogsDesc: 'Найдите книги с похожими характеристиками по названию, описанию или цене',
        dataAnalysis: 'Анализ данных',
        dataAnalysisDesc: 'Изучите историю продаж, характеристики аукционов и финальные цены',
        getEstimate: 'Получение оценки',
        getEstimateDesc: 'Определите ориентировочную стоимость вашей книги на основе рыночных данных',
        subscriptionPromo: 'Для получения полного доступа к базе данных и детальной статистике, пожалуйста, оформите подписку.',
        
        // Статус подписки
        subscriptionStatus: 'Статус подписки',
        active: 'Активна',
        inactive: 'Не активна',
        subscriptionType: 'Тип подписки',
        standard: 'Стандартная',
        validUntil: 'Действует до',
        dateNotSpecified: 'Не указана',
        
        // Уведомления и ошибки
        logoutSuccess: 'Вы успешно вышли из системы',
        authRequired: 'Сначала авторизуйтесь, чтобы выполнять поиск.',
        apiCheckingConnection: 'Проверка соединения с API...',
        apiConnected: 'API подключен',
        apiConnectionError: 'Ошибка подключения к API',
        
        // Обратная связь
        feedback: 'Обратная связь',
        feedbackPlaceholder: 'Ваш отзыв или предложение',
        cancel: 'Отмена',
        send: 'Отправить'
    },
    
    // Английский язык
    EN: {
        // Navigation and common elements
        login: 'Login',
        register: 'Register',
        logout: 'Logout',
        search: 'Search',
        exactMatch: 'Exact match',
        getSubscription: 'Get Subscription',
        adminPanel: 'Admin Panel',
        
        // Main header
        mainTitle: 'Antique Book Appraisal',
        mainSubtitle: 'Discover the market value of your books using a database of real sales',
        startEvaluation: 'Start Appraisal',
        
        // Search
        titleSearch: 'Search by Title',
        bookTitle: 'Book title',
        advancedSearch: 'Advanced Search for Book Appraisal',
        descriptionSearch: 'Search by Description',
        descriptionSearchHint: 'Search for books by keywords in their description. Enter a text fragment that might be contained in an antique book description.',
        keywordsPlaceholder: 'Keywords from description',
        priceRangeSearch: 'Search by Price Range',
        priceRangeSearchHint: 'Find books in a specific price range for a more accurate valuation of your collection.',
        minPrice: 'Minimum price',
        maxPrice: 'Maximum price',
        
        // Information block
        howItWorks: 'How Antique Book Appraisal Works',
        serviceDescription: 'Our service provides access to an extensive database of real antique book sales. The algorithm determines the approximate market value of your book based on analysis of similar copies that have already been sold.',
        findAnalogs: 'Find Similar Items',
        findAnalogsDesc: 'Find books with similar characteristics by title, description, or price',
        dataAnalysis: 'Data Analysis',
        dataAnalysisDesc: 'Explore sales history, auction characteristics, and final prices',
        getEstimate: 'Get an Estimate',
        getEstimateDesc: 'Determine the approximate value of your book based on market data',
        subscriptionPromo: 'For full access to the database and detailed statistics, please get a subscription.',
        
        // Subscription status
        subscriptionStatus: 'Subscription Status',
        active: 'Active',
        inactive: 'Inactive',
        subscriptionType: 'Subscription Type',
        standard: 'Standard',
        validUntil: 'Valid until',
        dateNotSpecified: 'Not specified',
        
        // Notifications and errors
        logoutSuccess: 'You have successfully logged out',
        authRequired: 'Please login first to perform searches.',
        apiCheckingConnection: 'Checking API connection...',
        apiConnected: 'API connected',
        apiConnectionError: 'API connection error',
        
        // Feedback
        feedback: 'Feedback',
        feedbackPlaceholder: 'Your feedback or suggestion',
        cancel: 'Cancel',
        send: 'Send'
    }
};

export default translations; 