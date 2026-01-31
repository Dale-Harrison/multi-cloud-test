package com.example.demo;

import com.google.cloud.spring.pubsub.core.PubSubTemplate;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile("gcp")
public class PubSubMessagePublisher implements MessagePublisher {

    private final PubSubTemplate pubSubTemplate;

    public PubSubMessagePublisher(PubSubTemplate pubSubTemplate) {
        this.pubSubTemplate = pubSubTemplate;
    }

    @Override
    public void publish(String message) {
        pubSubTemplate.publish("hello-topic", message);
    }
}
