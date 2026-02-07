package com.example.demo.repository;

import com.example.demo.dto.PaymentRequest;

public interface PaymentRepository {
    void save(PaymentRequest paymentRequest);
}
