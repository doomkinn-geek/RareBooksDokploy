//src/api.js:
import axios from 'axios';
import Cookies from 'js-cookie';

export const API_URL = '/api';
// Закомментируем localhost URL, так как он вызывает ошибку соединения
//export const API_URL = 'https://localhost:7042/api';






//export const API_URL = 'http://localhost:5000/api'; - не рабочая строка

// Глобальный обработчик ошибок для axios
axios.interceptors.response.use(
    response => response,
    error => {
        // Проверка на ошибки соединения
        if (!error.response) {
            console.error('Network error detected:', error.message);
            // Можно добавить глобальное уведомление о проблемах с соединением
        }
        
        // Проверка на ошибки аутентификации
        if (error.response && error.response.status === 403) {
            console.error('Access forbidden:', error.response.data);
            // Возможно, перенаправить пользователя на страницу авторизации
        }
        
        return Promise.reject(error);
    }
);

// получаем токен доступа из cookies
export const getAuthHeaders = () => {
    const token = Cookies.get('token');
    return token ? { Authorization: `Bearer ${token}` } : {};
};

//     Cookies.get('token'):
/*export const getAuthHeaders = () => {
    const token = localStorage.getItem('token');
    return token ? { Authorization: `Bearer ${token}` } : {};
};*/

export const searchBooksByTitle = (title, exactPhrase = false, page = 1, pageSize = 10, categoryIds = []) => {
    const params = { title, exactPhrase, page, pageSize };
    
    // Добавляем categoryIds только если они указаны
    if (categoryIds && categoryIds.length > 0) {
        // Передаем каждый элемент массива как отдельный параметр с одинаковым именем
        // для правильной обработки ASP.NET Core
        categoryIds.forEach((id, index) => {
            params[`categoryIds[${index}]`] = id;
        });
    }
    
    return axios.get(`${API_URL}/books/searchByTitle`, {
        params,
        headers: getAuthHeaders(),
        paramsSerializer: {
            indexes: null // Отключаем добавление индексов в квадратных скобках
        }
    });
};

export const searchBooksByDescription = (description, exactPhrase = false, page = 1, pageSize = 10, categoryIds = []) => {
    const params = { description, exactPhrase, page, pageSize };
    
    // Добавляем categoryIds только если они указаны
    if (categoryIds && categoryIds.length > 0) {
        // Передаем каждый элемент массива как отдельный параметр с одинаковым именем
        // для правильной обработки ASP.NET Core
        categoryIds.forEach((id, index) => {
            params[`categoryIds[${index}]`] = id;
        });
    }
    
    return axios.get(`${API_URL}/books/searchByDescription`, {
        params,
        headers: getAuthHeaders(),
        paramsSerializer: {
            indexes: null // Отключаем добавление индексов в квадратных скобках
        }
    });
};


export const searchBooksByCategory = (categoryId, page = 1, pageSize = 10) =>
    axios.get(`${API_URL}/books/searchByCategory`, {
        params: { categoryId, page, pageSize },
        headers: getAuthHeaders(),
    });

export const searchBooksByPriceRange = (minPrice, maxPrice, page = 1, pageSize = 10) =>
    axios.get(`${API_URL}/books/searchByPriceRange`, {
        params: { minPrice, maxPrice, page, pageSize },
        headers: getAuthHeaders(),
    });

export const searchBooksBySeller = (sellerName, page = 1, pageSize = 10) =>
    axios.get(`${API_URL}/books/searchBySeller`, {
        params: { sellerName, page, pageSize },
        headers: getAuthHeaders(),
    });

export const getBookById = (id) =>
    axios.get(`${API_URL}/books/${id}`, {
        headers: getAuthHeaders(),
    });

export const getBookImages = (id) =>
    axios.get(`${API_URL}/books/${id}/images`, {
        headers: getAuthHeaders(),
    });

export const getBookThumbnail = (id, thumbnailName) =>
    axios.get(`${API_URL}/books/${id}/thumbnails/${thumbnailName}`, {
        headers: getAuthHeaders(),
        responseType: 'blob',
    });

export const getBookImageFile = (id, imageName) =>
    axios.get(`${API_URL}/books/${id}/images/${imageName}`, {
        headers: getAuthHeaders(),
        responseType: 'blob',
    });

export const getCategories = () =>
    axios.get(`${API_URL}/categories`, {
        headers: getAuthHeaders(),
    });

export const registerUser = (userData) =>
    axios.post(`${API_URL}/auth/register`, userData, {
        headers: {
            'Content-Type': 'application/json'
        }
    });



export const loginUser = (userData) =>
    axios.post(`${API_URL}/auth/login`, userData);

// Методы для AdminController (требуют права администратора)
export const getUsers = () =>
    axios.get(`${API_URL}/admin/users`, {
        headers: getAuthHeaders(),
    });

// Получение профиля пользователя через AdminController (требует права администратора)
export const getUserById = (userId) =>
    axios.get(`${API_URL}/admin/user/${userId}`, {
        headers: getAuthHeaders(),
    });

// Получение истории поиска через AdminController (требует права администратора)
export const getUserSearchHistory = (userId) =>
    axios.get(`${API_URL}/admin/user/${userId}/searchHistory`, {
        headers: getAuthHeaders(),
    });

// Методы для UserController (работают для всех авторизованных пользователей)

// Получение профиля пользователя (работает для своего профиля или для администратора)
export const getUserProfile = (userId) =>
    axios.get(`${API_URL}/user/${userId}`, {
        headers: getAuthHeaders(),
    });

// Получение истории поиска пользователя (работает для своей истории или для администратора)
export const getUserSearchHistoryNew = (userId) =>
    axios.get(`${API_URL}/user/${userId}/searchHistory`, {
        headers: getAuthHeaders(),
    });

// Получение профиля текущего пользователя
export const getCurrentUserProfile = () =>
    axios.get(`${API_URL}/user/profile`, {
        headers: getAuthHeaders(),
    });

export const updateUserSubscription = async (userId, hasSubscription) => {
    console.log({ hasSubscription });
    try {
        //      
        const response = await axios.post(`${API_URL}/admin/user/${userId}/subscription`, hasSubscription, {
            headers: {
                ...getAuthHeaders(),
                'Content-Type': 'application/json'
            }
        });
        console.log('Subscription updated successfully', response);
    } catch (error) {
        console.error('Error updating subscription', error);
    }
}


export const updateUserRole = async (userId, role) => {
    console.log({ role });
    try {
        //  
        const response = await axios.post(`${API_URL}/admin/user/${userId}/role`, role, {
            headers: {
                ...getAuthHeaders(),
                'Content-Type': 'application/json'
            }
        });
        console.log('Role assigned successfully', response);
    } catch (error) {
        console.error('Error assigning role', error);
    }
}

export const getCaptcha = () =>
    axios.get(`${API_URL}/auth/captcha`, {
        responseType: 'arraybuffer'
    });


// -------- 
export async function getAdminSettings() {
    const response = await axios.get(`${API_URL}/adminsettings`, {
        headers: getAuthHeaders()
    });
    return response.data;
}

export async function updateAdminSettings(settingsDto) {
    const response = await axios.post(`${API_URL}/adminsettings`, settingsDto, {
        headers: {
            ...getAuthHeaders(),
            'Content-Type': 'application/json'
        }
    });
    return response.data;
}

// ------------------- 

// ------------------- ФУНКЦИИ ДЛЯ ИМПОРТА -------------------

/**
 * Инициализация задачи импорта. Сервер отдаёт importTaskId
 */
export async function initImport(fileSize = null) {
    const headers = getAuthHeaders();
    let url;
    
    if (fileSize) {
        // Преобразуем размер файла в строку для избежания проблем с типами
        url = `${API_URL}/import/init?fileSize=${String(fileSize)}`;
        console.log(`Инициализация импорта с размером файла: ${fileSize} байт, URL: ${url}`);
    } else {
        url = `${API_URL}/import/init`;
        console.log(`Инициализация импорта без указания размера файла, URL: ${url}`);
    }

    try {
        const response = await axios.post(url, null, { headers });
        console.log('Успешная инициализация импорта, ответ:', response.data);
        return response.data; // { importTaskId }
    } catch (error) {
        console.error('Ошибка инициализации импорта:', error);
        if (error.response) {
            console.error('Ответ сервера:', error.response.status, error.response.data);
        }
        throw error;
    }
}

/**
 * Загрузка кусков файла (или всего файла целиком) - application/octet-stream
 * Параметр onUploadProgress позволяет отслеживать прогресс на клиенте.
 */
export async function uploadImportChunk(importTaskId, fileChunk, onUploadProgress) {
    const headers = {
        ...getAuthHeaders(),
        'Content-Type': 'application/octet-stream'
    };

    const url = `${API_URL}/import/upload?importTaskId=${importTaskId}`;
    console.log(`Загрузка куска файла: importTaskId=${importTaskId}, размер=${fileChunk.size} байт`);

    try {
        // используем axios для POST
        const response = await axios.post(
            url,
            fileChunk,
            {
                headers,
                onUploadProgress, // отслеживаем прогресс отправки chunk'а
            }
        );
        return response;
    } catch (error) {
        console.error('Ошибка загрузки куска файла:', error);
        if (error.response) {
            console.error('Ответ сервера:', error.response.status, error.response.data);
        }
        throw error;
    }
}

/**
 * После загрузки файла вызвать Finish, чтобы сервер запустил импорт
 */
export async function finishImport(importTaskId) {
    const headers = getAuthHeaders();
    const url = `${API_URL}/import/finish?importTaskId=${importTaskId}`;
    console.log(`Завершение импорта: importTaskId=${importTaskId}`);

    try {
        const response = await axios.post(url, null, { headers });
        console.log('Импорт успешно завершен');
        return response;
    } catch (error) {
        console.error('Ошибка завершения импорта:', error);
        if (error.response) {
            console.error('Ответ сервера:', error.response.status, error.response.data);
        }
        throw error;
    }
}

/**
 * Запрос прогресса импортной задачи
 */
export async function getImportProgress(importTaskId) {
    const headers = getAuthHeaders();
    const response = await axios.get(`${API_URL}/import/progress/${importTaskId}`, { headers });
    return response.data; // { uploadProgress, importProgress, ... }
}

/**
 * Отмена
 */
export async function cancelImport(importTaskId) {
    const headers = getAuthHeaders();
    await axios.post(`${API_URL}/import/cancel?importTaskId=${importTaskId}`, null, { headers });
}

// 
export const sendFeedback = async (text) => {
    return axios.post(
        `${API_URL}/feedback`,
        { text }, // 
        { headers: getAuthHeaders() } // 
    );
}

export function getSubscriptionPlans() {
    return axios.get(`${API_URL}/subscription/plans`);
}

export function createPayment(subscriptionPlanId, autoRenew) {    
    return axios.post(`${API_URL}/subscription/create-payment`,
        { subscriptionPlanId, autoRenew },
        { headers: getAuthHeaders() }
    );
}

export function subscribeUser(subscriptionPlanId) {
    const token = Cookies.get('token');
    return axios.post(
        `${API_URL}/subscription/create-payment`,
        { subscriptionPlanId, autoRenew: false },
        { headers: { Authorization: `Bearer ${token}` } }
    ).then(response => {
        // Если API возвращает URL для редиректа, перенаправляем пользователя
        if (response.data && response.data.redirectUrl) {
            window.location.href = response.data.redirectUrl;
        }
        return response;
    });
}

export function cancelSubscription() {
    return axios.post(`${API_URL}/subscription/cancel`, 
        {},
        { headers: getAuthHeaders() }
    );
}

export function checkSubscriptionStatus() {
    return axios.get(`${API_URL}/subscription/check-status`, 
        { headers: getAuthHeaders() }
    );
}

// Функции для оценки стоимости антикварных книг
export function getPriceStatistics(categoryId = null) {
    console.log(`[API] Начало запроса getPriceStatistics с categoryId=${categoryId}`);
    
    // URL с поддержкой обоих эндпоинтов (старого и нового)
    let url;
    try {
        // Сначала пробуем новый endpoint (Statistics контроллер)
        url = `${API_URL}/statistics/prices`;
        if (categoryId) {
            url += `?categoryId=${categoryId}`;
        }
        
        console.log(`[API] Запрос к endpoint: ${url}`);
        
        return axios.get(url, {
            headers: getAuthHeaders(),
            timeout: 10000
        })
        .then(response => {
            console.log(`[API] Успешно получены данные статистики цен:`, response.data);
            return response;
        })
        .catch(error => {
            console.warn(`[API] Ошибка при обращении к новому endpoint, пробуем старый:`, error.message);
            
            // Если новый эндпоинт недоступен - пробуем старый
            url = `${API_URL}/books/price-statistics`;
            if (categoryId) {
                url += `?categoryId=${categoryId}`;
            }
            
            console.log(`[API] Запрос к запасному endpoint: ${url}`);
            
            return axios.get(url, { 
                headers: getAuthHeaders(),
                timeout: 10000
            })
            .then(response => {
                console.log(`[API] Успешно получены данные статистики цен через запасной endpoint:`, response.data);
                return response;
            })
            .catch(secondError => {
                // Детальное логирование ошибок при второй попытке
                console.error(`[API] Ошибка при получении статистики цен через запасной endpoint:`, secondError);
                
                if (secondError.response) {
                    console.error(`[API] Статус ответа: ${secondError.response.status}`);
                    console.error(`[API] Данные ответа:`, secondError.response.data);
                } else if (secondError.request) {
                    console.error('[API] Нет ответа от сервера:', secondError.request);
                } else {
                    console.error('[API] Ошибка при настройке запроса:', secondError.message);
                }
                
                throw secondError;
            });
        });
    } catch (error) {
        console.error(`[API] Критическая ошибка в getPriceStatistics:`, error);
        return Promise.reject(error);
    }
}

export function getRecentSales(limit = 5) {
    const url = `${API_URL}/books/recent-sales?limit=${limit}`;
    const headers = getAuthHeaders();
    
    console.log('API getRecentSales - URL:', url);
    console.log('API getRecentSales - Headers:', headers);
    
    return axios.get(url, { headers });
}

export function getPriceHistory(bookId) {
    return axios.get(`${API_URL}/books/${bookId}/price-history`, { headers: getAuthHeaders() });
}

export function getBookValueEstimate(params) {
    return axios.post(`${API_URL}/books/estimate-value`, params, { headers: getAuthHeaders() });
}

// ===== Функции для управления категориями (очистка нежелательных категорий) =====
export function getAllCategoriesWithBooksCount() {
    const token = Cookies.get('token');
    console.log('Вызов getAllCategoriesWithBooksCount. Токен:', token ? 'Присутствует' : 'Отсутствует');
    
    if (!token) {
        console.error('Токен авторизации отсутствует!');
        return Promise.reject(new Error('Токен авторизации отсутствует'));
    }
    
    // Не пытаемся анализировать токен, а просто используем его для авторизации
    const headers = { Authorization: `Bearer ${token}` };
    console.log('Заголовки запроса:', headers);
    
    return axios.get(`${API_URL}/CategoryCleanup/categories`, { headers })
        .catch(error => {
            console.error('Ошибка запроса к CategoryCleanup/categories:', error);
            console.log('Статус ошибки:', error.response?.status);
            console.log('Данные ошибки:', error.response?.data);
            
            if (error.response?.status === 403) {
                console.error('Доступ запрещен. Проверьте права пользователя.');
            }
            
            throw error;
        });
}

export function analyzeCategoriesByNames(categoryNames) {
    return axios.post(`${API_URL}/CategoryCleanup/analyze`, categoryNames, {
        headers: {
            ...getAuthHeaders(),
            'Content-Type': 'application/json'
        }
    });
}

export function analyzeUnwantedCategories() {
    return axios.get(`${API_URL}/CategoryCleanup/analyze-unwanted`, {
        headers: getAuthHeaders()
    });
}

export function deleteCategoriesByNames(categoryNames) {
    return axios.delete(`${API_URL}/CategoryCleanup/byNames`, {
        headers: {
            ...getAuthHeaders(),
            'Content-Type': 'application/json'
        },
        data: categoryNames
    });
}

export function deleteUnwantedCategories() {
    return axios.delete(`${API_URL}/CategoryCleanup/unwanted`, {
        headers: getAuthHeaders()
    });
}

// Методы для работы с избранными книгами
export const addBookToFavorites = (bookId) =>
    axios.post(`${API_URL}/books/${bookId}/favorite`, {}, {
        headers: getAuthHeaders()
    });

export const removeBookFromFavorites = (bookId) =>
    axios.delete(`${API_URL}/books/${bookId}/favorite`, {
        headers: getAuthHeaders()
    });

export const checkIfBookIsFavorite = (bookId) =>
    axios.get(`${API_URL}/books/${bookId}/is-favorite`, {
        headers: getAuthHeaders()
    });

export const getFavoriteBooks = (page = 1, pageSize = 10) =>
    axios.get(`${API_URL}/books/favorites`, {
        params: { page, pageSize },
        headers: getAuthHeaders()
    });