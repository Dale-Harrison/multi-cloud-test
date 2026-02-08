package com.example.demo.repository;

import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.DocumentSnapshot;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutionException;

@Repository
@Profile("gcp")
public class FirestoreBalanceRepository implements BalanceRepository {

    private final Firestore firestore;

    public FirestoreBalanceRepository(Firestore firestore) {
        this.firestore = firestore;
    }

    @Override
    public BigDecimal getBalance(String userId) {
        try {
            DocumentSnapshot document = firestore.collection("user_balances").document(userId).get().get();
            if (document.exists() && document.contains("balance")) {
                Double balanceVal = document.getDouble("balance");
                return balanceVal != null ? BigDecimal.valueOf(balanceVal) : BigDecimal.ZERO;
            }
            return BigDecimal.ZERO;
        } catch (InterruptedException | ExecutionException e) {
            throw new RuntimeException("Error fetching balance from Firestore", e);
        }
    }

    @Override
    public void deductBalance(String userId, BigDecimal amount) {
        // In a real app, use transactions for atomicity
        BigDecimal currentBalance = getBalance(userId);
        if (currentBalance.compareTo(amount) < 0) {
            throw new IllegalArgumentException("Insufficient balance");
        }
        updateBalance(userId, currentBalance.subtract(amount));
    }

    @Override
    public void addBalance(String userId, BigDecimal amount) {
        BigDecimal currentBalance = getBalance(userId);
        updateBalance(userId, currentBalance.add(amount));
    }

    private void updateBalance(String userId, BigDecimal newBalance) {
        Map<String, Object> data = new HashMap<>();
        data.put("userId", userId);
        data.put("balance", newBalance.doubleValue()); // Firestore supports better indexing with native types

        try {
            firestore.collection("user_balances").document(userId).set(data).get();
        } catch (InterruptedException | ExecutionException e) {
            throw new RuntimeException("Error updating balance in Firestore", e);
        }
    }
}
