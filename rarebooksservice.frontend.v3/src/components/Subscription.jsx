import React from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';

const Subscription = () => {
    const history = useNavigate();

    const handleSubscribe = async () => {
        try {
            const response = await axios.post('/api/subscription/create-payment', {}, {
                headers: {
                    'Authorization': `Bearer ${localStorage.getItem('token')}`
                }
            });
            window.location.href = response.data.RedirectUrl;
        } catch (error) {
            console.error('Subscription error:', error);
            // You might want to display an error message to the user here
        }
    };

    return (
        <div>
            <h2>Subscription</h2>
            <button onClick={handleSubscribe}>Subscribe</button>
        </div>
    );
};

export default Subscription;
