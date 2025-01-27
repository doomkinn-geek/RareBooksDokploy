//src/api.js:
import axios from 'axios';
import Cookies from 'js-cookie';

export const API_URL = '/api';
//export const API_URL = 'https://localhost:7042/api';

// Получаем токен только из cookies
const getAuthHeaders = () => {
    const token = Cookies.get('token');
    return token ? { Authorization: `Bearer ${token}` } : {};
};

export const searchBooksByTitle = (title, exactPhrase = false, page = 1, pageSize = 10) =>
    axios.get(`${API_URL}/books/searchByTitle`, {
        params: { title, exactPhrase, page, pageSize },
        headers: getAuthHeaders(),
    });

export const searchBooksByDescription = (description, exactPhrase = false, page = 1, pageSize = 10) =>
    axios.get(`${API_URL}/books/searchByDescription`, {
        params: { description, exactPhrase, page, pageSize },
        headers: getAuthHeaders(),
    });


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

export const getUsers = () =>
    axios.get(`${API_URL}/admin/users`, {
        headers: getAuthHeaders(),
    });

export const getUserById = (userId) =>
    axios.get(`${API_URL}/admin/user/${userId}`, {
        headers: getAuthHeaders(),
    });

export const getUserSearchHistory = (userId) =>
    axios.get(`${API_URL}/admin/user/${userId}/searchHistory`, {
        headers: getAuthHeaders(),
    });

export const updateUserSubscription = async (userId, hasSubscription) => {
    console.log({ hasSubscription });
    try {
        // Передаем просто булево значение без объекта
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
        // Передаем просто строку роли без объекта
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


// -------- ДОБАВЛЕННЫЕ ФУНКЦИИ --------
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

// ------------------- ФУНКЦИИ ДЛЯ ИМПОРТА -------------------

/**
 * Инициализация задачи импорта. Сервер отдаёт importTaskId
 */
export async function initImport(fileSize = null) {
    const headers = getAuthHeaders();
    const url = fileSize
        ? `${API_URL}/import/init?fileSize=${fileSize}`
        : `${API_URL}/import/init`;

    const response = await axios.post(url, null, { headers });
    return response.data; // { importTaskId }
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

    // используем axios для POST
    return await axios.post(
        `${API_URL}/import/upload?importTaskId=${importTaskId}`,
        fileChunk,
        {
            headers,
            onUploadProgress, // отслеживаем прогресс отправки chunk'а
        }
    );
}

/**
 * После загрузки файла вызвать Finish, чтобы сервер запустил импорт
 */
export async function finishImport(importTaskId) {
    const headers = getAuthHeaders();
    await axios.post(`${API_URL}/import/finish?importTaskId=${importTaskId}`, null, {
        headers
    });
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

// Отправляет текст предложения на эндпоинт /api/feedback
export const sendFeedback = async (text) => {
    return axios.post(
        `${API_URL}/feedback`,
        { text }, // тело запроса
        { headers: getAuthHeaders() } // для Bearer-токена
    );
};

export function getSubscriptionPlans() {
    return axios.get(`${API_URL}/subscription/plans`);
}

export function createPayment(subscriptionPlanId, autoRenew) {    
    return axios.post(`${API_URL}/subscription/create-payment`,
        { subscriptionPlanId, autoRenew },
        { headers: { getAuthHeaders() } }
    );
}