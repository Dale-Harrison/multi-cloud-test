package com.example.demo.repository;

import io.awspring.cloud.dynamodb.DynamoDbTemplate;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.Key;

import java.math.BigDecimal;

@Repository
@Profile("aws")
public class DynamoDbBalanceRepository implements BalanceRepository {

    private final DynamoDbTemplate dynamoDbTemplate;

    public DynamoDbBalanceRepository(DynamoDbTemplate dynamoDbTemplate) {
        this.dynamoDbTemplate = dynamoDbTemplate;
    }

    @Override
    public BigDecimal getBalance(String userId) {
        UserBalances balance = dynamoDbTemplate.load(Key.builder().partitionValue(userId).build(), UserBalances.class);
        return balance != null ? balance.getBalance() : BigDecimal.ZERO;
    }

    @Override
    public void deductBalance(String userId, BigDecimal amount) {
        UserBalances balance = dynamoDbTemplate.load(Key.builder().partitionValue(userId).build(), UserBalances.class);
        if (balance == null) {
            balance = new UserBalances();
            balance.setUserId(userId);
            balance.setBalance(BigDecimal.ZERO);
        }

        if (balance.getBalance().compareTo(amount) < 0) {
            throw new IllegalArgumentException("Insufficient balance");
        }

        balance.setBalance(balance.getBalance().subtract(amount));
        dynamoDbTemplate.save(balance);
    }

    @Override
    public void addBalance(String userId, BigDecimal amount) {
        UserBalances balance = dynamoDbTemplate.load(Key.builder().partitionValue(userId).build(), UserBalances.class);
        if (balance == null) {
            balance = new UserBalances();
            balance.setUserId(userId);
            balance.setBalance(BigDecimal.ZERO);
        }

        balance.setBalance(balance.getBalance().add(amount));
        dynamoDbTemplate.save(balance);
    }

}
