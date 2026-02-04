package com.example.demo;

import io.awspring.cloud.sqs.operations.SqsTemplate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class ReplayService {

    private static final Logger logger = LoggerFactory.getLogger(ReplayService.class);

    @Autowired(required = false)
    private SqsTemplate sqsTemplate;

    public void replay(String message) {
        if (sqsTemplate != null) {
            try {
                sqsTemplate.send("replay-queue", message);
                logger.info("Message successfully replayed to AWS SQS");
            } catch (Exception e) {
                logger.error("Failed to replay message to AWS SQS: {}", e.getMessage());
            }
        } else {
            logger.warn(
                    "SqsTemplate not available, skipping replay. (This is expected if AWS credentials are missing on GCP)");
        }
    }
}
