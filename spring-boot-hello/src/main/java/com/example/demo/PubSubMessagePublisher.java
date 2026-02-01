package com.example.demo;

import com.google.cloud.spring.pubsub.core.PubSubTemplate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile("gcp")
public class PubSubMessagePublisher implements MessagePublisher {

    private static final Logger logger = LoggerFactory.getLogger(PubSubMessagePublisher.class);
    private final PubSubTemplate pubSubTemplate;

    public PubSubMessagePublisher(PubSubTemplate pubSubTemplate) {
        this.pubSubTemplate = pubSubTemplate;
    }

    @Override
    public void publish(String message) {
        logger.info("Publishing to Pub/Sub topic hello-topic: {}", message);
        pubSubTemplate.publish("hello-topic", message);
    }
}
