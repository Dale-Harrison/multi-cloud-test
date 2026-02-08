package com.example.demo;

import com.example.demo.dto.PaymentRequest;
import com.example.demo.repository.BalanceRepository;
import com.example.demo.repository.PaymentRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.security.Principal;
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
    private final BalanceRepository balanceRepository;

    // Inject specific repositories. We use Optional because they might not be
    // available in all profiles.
    // However, with our profile setup:
    // AWS Profile: DynamoDbPaymentRepository is active. FirestorePaymentRepository
    // is inactive.
    // GCP Profile: DynamoDbPaymentRepository is active. FirestorePaymentRepository
    // is active.
    private final PaymentRepository dynamoDbPaymentRepository;
    private final PaymentRepository firestorePaymentRepository;

    @Value("${spring.profiles.active:local}")
    private String activeProfile;

    public PaymentController(MessagePublisher messagePublisher, ObjectMapper objectMapper,
            BalanceRepository balanceRepository,
            // Inject all available PaymentRepositories. Since we have multiple of the same
            // type in GCP profile,
            // we need to be careful. The cleanest way is to inject by name or qualifier if
            // we name them,
            // or just inject the specific implementations if we changed the interface
            // injection.
            //
            // Given we haven't named beans explicitly, Spring uses class name (camelCase).
            // Let's use @Qualifier or just inject the list and filter?
            // Actually, simpler: define them as fields and use constructor injection with
            // @Qualifier if needed,
            // but since they are different classes, we can't inject by interface unless we
            // use @Qualifier.
            //
            // Let's rely on the fact that we have class-based injection if we cast? No,
            // that's bad.
            //
            // Best approach: Inject the interface with @Qualifier.
            // Note: If a bean is not active (profile), it won't be in the context.
            // So we use Optional.
            @org.springframework.beans.factory.annotation.Qualifier("dynamoDbPaymentRepository") java.util.Optional<PaymentRepository> dynamoDbPaymentRepository,
            @org.springframework.beans.factory.annotation.Qualifier("firestorePaymentRepository") java.util.Optional<PaymentRepository> firestorePaymentRepository) {
        this.messagePublisher = messagePublisher;
        this.objectMapper = objectMapper;
        this.balanceRepository = balanceRepository;
        this.dynamoDbPaymentRepository = dynamoDbPaymentRepository.orElse(null);
        this.firestorePaymentRepository = firestorePaymentRepository.orElse(null);
    }

    @GetMapping("/balance")
    public ResponseEntity<BigDecimal> getBalance(Principal principal) {
        String userId = principal.getName();
        return ResponseEntity.ok(balanceRepository.getBalance(userId));
    }

    @PostMapping("/add-funds")
    public ResponseEntity<String> addFunds(Principal principal, @RequestBody Map<String, BigDecimal> payload) {
        String userId = principal.getName();
        BigDecimal amount = payload.get("amount");
        balanceRepository.addBalance(userId, amount);
        return ResponseEntity.ok("Funds added");
    }

    @PostMapping
    public ResponseEntity<String> processPayment(@RequestBody PaymentRequest paymentRequest, Principal principal) {
        try {
            String userId = principal.getName();

            // Check and Deduct Balance
            try {
                balanceRepository.deductBalance(userId, paymentRequest.getAmount());
            } catch (IllegalArgumentException e) {
                return ResponseEntity.badRequest().body("Insufficient balance");
            }

            paymentRequest.setSourceAccount(userId);

            // Save to Database
            if (activeProfile.contains("gcp")) {
                // Primary: Firestore
                if (firestorePaymentRepository != null) {
                    firestorePaymentRepository.save(paymentRequest);
                } else {
                    logger.warn("Firestore repository not found in GCP profile!");
                }

                // Replication: DynamoDB
                if (dynamoDbPaymentRepository != null) {
                    try {
                        dynamoDbPaymentRepository.save(paymentRequest);
                    } catch (Exception e) {
                        logger.error("Replication to DynamoDB failed", e);
                        // We do NOT fail the request, as primary write succeeded.
                    }
                } else {
                    logger.warn("DynamoDB repository not found for replication in GCP profile!");
                }
            } else {
                // Default / AWS: DynamoDB
                if (dynamoDbPaymentRepository != null) {
                    dynamoDbPaymentRepository.save(paymentRequest);
                } else {
                    logger.error("DynamoDB repository not found in AWS profile!");
                    return ResponseEntity.internalServerError().body("Database unavailable");
                }
            }

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
