package com.example.demo.repository;

import com.example.demo.dto.PaymentRequest;
import io.awspring.cloud.dynamodb.DynamoDbTemplate;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
@Profile({ "aws", "gcp" })
public class DynamoDbPaymentRepository implements PaymentRepository {

    private final DynamoDbTemplate dynamoDbTemplate;

    public DynamoDbPaymentRepository(DynamoDbTemplate dynamoDbTemplate) {
        this.dynamoDbTemplate = dynamoDbTemplate;
    }

    @Override
    public void save(PaymentRequest paymentRequest) {
        Payments record = new Payments();
        record.setTransactionId(UUID.randomUUID().toString());
        record.setAmount(paymentRequest.getAmount());
        record.setCurrency(paymentRequest.getCurrency());
        record.setSourceAccount(paymentRequest.getSourceAccount());
        record.setDestinationAccount(paymentRequest.getDestinationAccount());

        dynamoDbTemplate.save(record);
    }

}
