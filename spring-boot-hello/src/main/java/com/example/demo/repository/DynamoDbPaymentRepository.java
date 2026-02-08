package com.example.demo.repository;

import com.example.demo.dto.PaymentRequest;
import io.awspring.cloud.dynamodb.DynamoDbTemplate;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;

import java.util.UUID;
import java.math.BigDecimal;

@Repository
@Profile({ "aws", "gcp" })
public class DynamoDbPaymentRepository implements PaymentRepository {

    private final DynamoDbTemplate dynamoDbTemplate;

    public DynamoDbPaymentRepository(DynamoDbTemplate dynamoDbTemplate) {
        this.dynamoDbTemplate = dynamoDbTemplate;
    }

    @Override
    public void save(PaymentRequest paymentRequest) {
        PaymentRecord record = new PaymentRecord();
        record.setTransactionId(UUID.randomUUID().toString());
        record.setAmount(paymentRequest.getAmount());
        record.setCurrency(paymentRequest.getCurrency());
        record.setSourceAccount(paymentRequest.getSourceAccount());
        record.setDestinationAccount(paymentRequest.getDestinationAccount());

        dynamoDbTemplate.save(record);
    }

    @DynamoDbBean
    public static class PaymentRecord {
        private String transactionId;
        private BigDecimal amount;
        private String currency;
        private String sourceAccount;
        private String destinationAccount;

        @DynamoDbPartitionKey
        public String getTransactionId() {
            return transactionId;
        }

        public void setTransactionId(String transactionId) {
            this.transactionId = transactionId;
        }

        public BigDecimal getAmount() {
            return amount;
        }

        public void setAmount(BigDecimal amount) {
            this.amount = amount;
        }

        public String getCurrency() {
            return currency;
        }

        public void setCurrency(String currency) {
            this.currency = currency;
        }

        public String getSourceAccount() {
            return sourceAccount;
        }

        public void setSourceAccount(String sourceAccount) {
            this.sourceAccount = sourceAccount;
        }

        public String getDestinationAccount() {
            return destinationAccount;
        }

        public void setDestinationAccount(String destinationAccount) {
            this.destinationAccount = destinationAccount;
        }
    }
}
