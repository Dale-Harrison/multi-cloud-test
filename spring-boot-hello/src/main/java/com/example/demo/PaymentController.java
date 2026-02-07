package com.example.demo;

import com.example.demo.dto.PaymentRequest;
import com.example.demo.repository.PaymentRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/payment")
public class PaymentController {

    private static final Logger logger = LoggerFactory.getLogger(PaymentController.class);

    private final MessagePublisher messagePublisher;
    private final ObjectMapper objectMapper;
    private final PaymentRepository paymentRepository;

    @Value("${spring.profiles.active:local}")
    private String activeProfile;

    public PaymentController(MessagePublisher messagePublisher, ObjectMapper objectMapper,
            PaymentRepository paymentRepository) {
        this.messagePublisher = messagePublisher;
        this.objectMapper = objectMapper;
        this.paymentRepository = paymentRepository;
    }

    @PostMapping
    public ResponseEntity<String> processPayment(@RequestBody PaymentRequest paymentRequest) {
        try {
            // Save to Database (DynamoDB or Firestore based on profile)
            paymentRepository.save(paymentRequest);

            // but we might want to preserve the environment indicator.
            // Actually, the requirement says "the worker service should log the payment
            Map<String, Object> paymentEvent = new HashMap<>();
            paymentEvent.put("eventId", UUID.randomUUID().toString());
            paymentEvent.put("eventType", "PAYMENT_INITIATED");
            paymentEvent.put("timestamp", LocalDateTime.now().toString());
            paymentEvent.put("data", paymentRequest);
            paymentEvent.put("source", activeProfile.contains("aws") ? "AWS-Fargate" : "GCP-CloudRun");

            String jsonMessage = objectMapper.writeValueAsString(paymentEvent);

            logger.info("Processing payment request: {}", jsonMessage);

            // Publish to Message Queue (SQS or Pub/Sub)
            messagePublisher.publish(jsonMessage);

            return ResponseEntity.ok(jsonMessage);
        } catch (JsonProcessingException e) {
            logger.error("Error serializing payment request", e);
            return ResponseEntity.internalServerError().body("Error processing payment");
        }
    }
}
