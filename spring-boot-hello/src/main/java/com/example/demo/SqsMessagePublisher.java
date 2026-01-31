package com.example.demo;

import io.awspring.cloud.sqs.operations.SqsTemplate;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile("aws")
public class SqsMessagePublisher implements MessagePublisher {

    private final SqsTemplate sqsTemplate;

    public SqsMessagePublisher(SqsTemplate sqsTemplate) {
        this.sqsTemplate = sqsTemplate;
    }

    @Override
    public void publish(String message) {
        sqsTemplate.send(to -> to.queue("hello-queue").payload(message));
    }
}
