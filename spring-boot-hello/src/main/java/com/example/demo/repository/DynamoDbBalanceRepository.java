package com.example.demo.repository;

import io.awspring.cloud.dynamodb.DynamoDbTemplate;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;

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
        UserBalance balance = dynamoDbTemplate.load(Key.builder().partitionValue(userId).build(), UserBalance.class);
        return balance != null ? balance.getBalance() : BigDecimal.ZERO;
    }

    @Override
    public void deductBalance(String userId, BigDecimal amount) {
        UserBalance balance = dynamoDbTemplate.load(Key.builder().partitionValue(userId).build(), UserBalance.class);
        if (balance == null) {
            balance = new UserBalance();
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
        UserBalance balance = dynamoDbTemplate.load(Key.builder().partitionValue(userId).build(), UserBalance.class);
        if (balance == null) {
            balance = new UserBalance();
            balance.setUserId(userId);
            balance.setBalance(BigDecimal.ZERO);
        }

        balance.setBalance(balance.getBalance().add(amount));
        dynamoDbTemplate.save(balance);
    }

    @DynamoDbBean
    public static class UserBalance {
        private String userId;
        private BigDecimal balance;

        @DynamoDbPartitionKey
        public String getUserId() {
            return userId;
        }

        public void setUserId(String userId) {
            this.userId = userId;
        }

        public BigDecimal getBalance() {
            return balance;
        }

        public void setBalance(BigDecimal balance) {
            this.balance = balance;
        }
    }
}
