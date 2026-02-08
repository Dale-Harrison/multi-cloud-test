package com.example.demo.repository;

import java.math.BigDecimal;

public interface BalanceRepository {
    BigDecimal getBalance(String userId);

    void deductBalance(String userId, BigDecimal amount);

    void addBalance(String userId, BigDecimal amount);
}
