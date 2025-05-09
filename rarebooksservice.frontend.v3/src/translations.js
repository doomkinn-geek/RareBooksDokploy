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
        send: 'Отправить',
        
        // Блок оценки антикварных книг (renderAntiqueBooksValuationInfo)
        professionalAppraisal: 'Профессиональная оценка антикварных книг',
        collectorsIntro: 'Коллекционируете редкие книги или занимаетесь антиквариатом? Теперь у вас есть инструмент, который раскрывает реальную рыночную стоимость редких книг!',
        howItWorksTitle: 'Как это работает',
        realSalesDatabase: 'База данных реальных продаж',
        realSalesDesc: 'Наш сервис — это уникальная база данных продаж антикварных и редких книг, собранная с одного из популярнейших порталов торговли редкими изданиями России.',
        salesRecords: '230 000+ продаж',
        salesRecordsDesc: 'с реальными ценами и подробным описанием каждого лота.',
        subscription: 'Оформление подписки',
        subscriptionDesc: 'Для доступа к полной базе данных и инструментам оценки необходимо оформить подписку. Это обеспечивает точность результатов и постоянное обновление информации.',
        fromPricePerMonth: 'от 50₽/месяц',
        subscriptionNeedsDesc: 'в зависимости от ваших потребностей.',
        searchByParams: 'Поиск по вашим параметрам',
        searchByParamsDesc: 'Для точной оценки введите всю имеющуюся у вас информацию о книге: название, год издания, автора, особенности издания.',
        accurateResult: 'результат оценки',
        moreDetailsMoreAccurate: 'Чем больше деталей вы укажете, тем точнее будет',
        selfAppraisal: 'Самостоятельная оценка',
        selfAppraisalDesc: 'Анализируйте результаты поиска — изучайте аналогичные издания, которые были проданы ранее, их состояние, даты продаж и фактические цены.',
        determineSelf: 'самостоятельно определить',
        fairMarketValue: 'справедливую рыночную стоимость вашей книги.',
        serviceAdvantages: 'Преимущества нашего сервиса',
        tenYearArchive: 'Доступ к 10-летнему архиву аукционов',
        archiveRecords: 'Более 230 000 записей о реальных продажах антикварных книг за последнее десятилетие.',
        onlyRealSales: 'Только реальные продажи',
        realSalesExplanation: 'Все книги в нашей базе реально проданы на meshok.net — никаких теоретических оценок!',
        flexibleSearch: 'Гибкий поиск',
        flexibleSearchDesc: 'Ищите по названию, описанию и ценовому диапазону. База данных постоянно пополняется новыми лотами.',
        completeLotInfo: 'Полная информация о лотах',
        lotInfoDesc: 'Фотографии лотов и все подробные данные аукционов помогут вам точно оценить ваши книги.',
        importantInfo: 'Важная информация',
        serviceProvides: 'Наш сервис предоставляет детальные исторические данные о реальных продажах, но не делает автоматическую оценку вашей книги. Рыночная стоимость антикварных и редких изданий зависит от множества факторов: состояния экземпляра, редкости издания, исторической ценности, наличия автографов, иллюстраций и других особенностей.',
        compareBooks: 'Сопоставляя вашу книгу с аналогичными проданными экземплярами, вы можете сформировать наиболее объективное представление о ее реальной рыночной стоимости на текущий момент.',
        discoverValue: '💰 Узнайте, сколько действительно стоят редкие книги!',
        subscriptionFrom: '🎟 Подписка от 50 рублей',
        startAppraisal: 'Начать оценку антикварных книг'
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
        send: 'Send',
        
        // Antique Book Appraisal Block (renderAntiqueBooksValuationInfo)
        professionalAppraisal: 'Professional Antique Book Appraisal',
        collectorsIntro: 'Do you collect rare books or deal with antiques? Now you have a tool that reveals the real market value of rare books!',
        howItWorksTitle: 'How It Works',
        realSalesDatabase: 'Real Sales Database',
        realSalesDesc: 'Our service is a unique database of antique and rare book sales, collected from one of the most popular rare book trading platforms in Russia.',
        salesRecords: '230,000+ sales',
        salesRecordsDesc: 'with real prices and detailed descriptions of each lot.',
        subscription: 'Get a Subscription',
        subscriptionDesc: 'Access to the full database and appraisal tools requires a subscription. This ensures accuracy of results and constant updates.',
        fromPricePerMonth: 'from 50₽/month',
        subscriptionNeedsDesc: 'depending on your needs.',
        searchByParams: 'Search by Your Parameters',
        searchByParamsDesc: 'For accurate appraisal, enter all the information you have about the book: title, year of publication, author, and special features.',
        accurateResult: 'appraisal result',
        moreDetailsMoreAccurate: 'The more details you provide, the more accurate the',
        selfAppraisal: 'Self-Appraisal',
        selfAppraisalDesc: 'Analyze search results — study similar editions that were sold previously, their condition, sale dates, and actual prices.',
        determineSelf: 'determine yourself',
        fairMarketValue: 'the fair market value of your book.',
        serviceAdvantages: 'Our Service Advantages',
        tenYearArchive: 'Access to 10-Year Auction Archive',
        archiveRecords: 'Over 230,000 records of real antique book sales over the past decade.',
        onlyRealSales: 'Only Real Sales',
        realSalesExplanation: 'All books in our database were actually sold on meshok.net — no theoretical estimations!',
        flexibleSearch: 'Flexible Search',
        flexibleSearchDesc: 'Search by title, description, and price range. The database is constantly updated with new lots.',
        completeLotInfo: 'Complete Lot Information',
        lotInfoDesc: 'Photos of lots and all detailed auction data will help you accurately appraise your books.',
        importantInfo: 'Important Information',
        serviceProvides: 'Our service provides detailed historical data on real sales, but does not automatically appraise your book. The market value of antique and rare editions depends on many factors: condition, rarity, historical value, presence of autographs, illustrations, and other features.',
        compareBooks: 'By comparing your book with similar sold copies, you can form the most objective view of its real market value at the current time.',
        discoverValue: '💰 Find out how much rare books are really worth!',
        subscriptionFrom: '🎟 Subscription from 50 rubles',
        startAppraisal: 'Start Antique Book Appraisal'
    }
};

export default translations; 