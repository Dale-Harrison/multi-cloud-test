package com.example.demo;

import com.example.demo.dto.PaymentRequest;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/payment")
public class PaymentController {

    private static final Logger logger = LoggerFactory.getLogger(PaymentController.class);
    private final MessagePublisher messagePublisher;
    private final ObjectMapper objectMapper;

    public PaymentController(MessagePublisher messagePublisher, ObjectMapper objectMapper) {
        this.messagePublisher = messagePublisher;
        this.objectMapper = objectMapper;
    }

    @PostMapping
    public ResponseEntity<String> processPayment(@RequestBody PaymentRequest paymentRequest) {
        try {
            String eventId = UUID.randomUUID().toString();
            String timestamp = Instant.now().toString();

            Map<String, Object> message = new HashMap<>();
            message.put("eventId", eventId);
            message.put("eventType", "PAYMENT_INITIATED");
            message.put("timestamp", timestamp);
            message.put("payload", paymentRequest);
            message.put("version", "1.0");

            String jsonMessage = objectMapper.writeValueAsString(message);

            // Prefix specifically for cross-cloud visibility if needed, but the structure
            // is JSON
            // Keeping the prefix helps distinguish environment in logs if that's desired,
            // but the requirement was "dummy payment using the data structure".
            // Let's wrap it in the environment prefix to be consistent with existing
            // logging patterns
            // or just send the raw JSON. The user prompt said "message structure that
            // represents a payment",
            // implying the whole thing is the message.
            // However, existing HelloController adds [AWS] prefix.
            // Let's stick to the JSON structure as the primary message content,
            // but we might want to preserve the environment indicator.
            // Actually, the requirement says "the worker service should log the payment
            // request".
            // The worker logs whatever it receives.
            // Let's prepend the environment tag to the JSON string so we know where it came
            // from,
            // consistent with HelloController.

            String env = (System.getenv("AWS_EXECUTION_ENV") != null ? "AWS" : "GCP");
            String finalMsg = String.format("[%s] %s", env, jsonMessage);

            logger.info("Publishing payment event: {}", finalMsg);
            messagePublisher.publish(finalMsg);

            return ResponseEntity.ok(jsonMessage);
        } catch (JsonProcessingException e) {
            logger.error("Error serializing payment request", e);
            return ResponseEntity.internalServerError().body("Error processing payment");
        }
    }
}
