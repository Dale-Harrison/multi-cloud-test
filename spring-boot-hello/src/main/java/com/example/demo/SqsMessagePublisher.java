package com.example.demo;

import io.awspring.cloud.sqs.operations.SqsTemplate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile("aws")
public class SqsMessagePublisher implements MessagePublisher {

    private static final Logger logger = LoggerFactory.getLogger(SqsMessagePublisher.class);
    private final SqsTemplate sqsTemplate;

    public SqsMessagePublisher(SqsTemplate sqsTemplate) {
        this.sqsTemplate = sqsTemplate;
    }

    @Override
    public void publish(String message) {
        logger.info("Publishing to SQS queue hello-queue: {}", message);
        sqsTemplate.send(to -> to.queue("hello-queue").payload(message));
    }
}
