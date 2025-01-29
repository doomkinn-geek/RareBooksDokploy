// src/components/SubscriptionSuccess.jsx
import React, { useState, useEffect } from 'react';
import { API_URL } from '../api';
import axios from 'axios';
import Cookies from 'js-cookie';
import ErrorMessage from './ErrorMessage';

const SubscriptionSuccess = () => {
    const [error, setError] = useState('');
    const [checking, setChecking] = useState(true);
    const [success, setSuccess] = useState(false);

    // ��� �������� ���������� ������� ������ �� ������, ����� ��������, 
    // ������� �� ��������.
    useEffect(() => {
        checkSubscriptionStatus();
    }, []);

    const checkSubscriptionStatus = async () => {
        setChecking(true);
        setError('');
        try {
            const token = Cookies.get('token');
            if (!token) {
                setError('�� �� ������������');
                setChecking(false);
                return;
            }
            // ����������� /api/subscription/my-subscriptions
            const response = await axios.get(`${API_URL}/subscription/my-subscriptions`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            const subs = response.data;
            // ���� ����� �������� ���� IsActive=true � EndDate > Now - ������ �����
            const activeSub = subs.find((s) => s.isActive);
            if (activeSub) {
                setSuccess(true);
            } else {
                setError('�������� ���� �� ������������. ��������� ������� ��� ���������� � ���������.');
            }
        } catch (err) {
            console.error('Check subscription error:', err);
            setError('������ ��� �������� ��������.');
        } finally {
            setChecking(false);
        }
    };

    if (checking) {
        return <div className="container">��������� ������ ��������...</div>;
    }

    if (error) {
        return (
            <div className="container">
                <h2>��������� ������</h2>
                <ErrorMessage message={error} />
            </div>
        );
    }

    if (success) {
        return (
            <div className="container">
                <h2>������ ������� ���������!</h2>
                <p>���� �������� �������. ���������� �� ������������� Rare Books Service.</p>
            </div>
        );
    }

    return (
        <div className="container">
            <h2>������ ���������</h2>
            <p>�������� ���� �� �������. ����������, �������� �������� ����� ��� ��������� � ����������.</p>
        </div>
    );
};

export default SubscriptionSuccess;
