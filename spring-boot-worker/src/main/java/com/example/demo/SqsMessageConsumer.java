package com.example.demo;

import io.awspring.cloud.sqs.annotation.SqsListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile("aws")
public class SqsMessageConsumer {

    private static final Logger logger = LoggerFactory.getLogger(SqsMessageConsumer.class);

    @SqsListener("hello-queue")
    public void listen(String message) {
        logger.info("AWS Worker received message: {}", message);
    }
}
