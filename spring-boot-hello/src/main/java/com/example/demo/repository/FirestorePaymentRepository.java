package com.example.demo.repository;

import com.example.demo.dto.PaymentRequest;
import com.google.cloud.firestore.Firestore;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

@Repository
@Profile("gcp")
public class FirestorePaymentRepository implements PaymentRepository {

    private final Firestore firestore;

    public FirestorePaymentRepository(Firestore firestore) {
        this.firestore = firestore;
    }

    @Override
    public void save(PaymentRequest paymentRequest) {
        String transactionId = UUID.randomUUID().toString();
        if (transactionId == null) {
            throw new IllegalStateException("UUID cannot be null");
        }
        Map<String, Object> data = new HashMap<>();
        data.put("transactionId", transactionId);
        data.put("amount", paymentRequest.getAmount());
        data.put("currency", paymentRequest.getCurrency());
        data.put("sourceAccount", paymentRequest.getSourceAccount());
        data.put("destinationAccount", paymentRequest.getDestinationAccount());

        try {
            firestore.collection("payments").document(transactionId).set(data).get();
        } catch (InterruptedException | ExecutionException e) {
            throw new RuntimeException("Error saving to Firestore", e);
        }
    }
}
