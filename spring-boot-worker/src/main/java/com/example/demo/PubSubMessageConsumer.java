package com.example.demo;

import com.google.cloud.spring.pubsub.support.BasicAcknowledgeablePubsubMessage;
import com.google.cloud.spring.pubsub.support.GcpPubSubHeaders;
import org.slf4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Profile;
import org.springframework.integration.annotation.ServiceActivator;
import org.springframework.messaging.MessageHandler;
import org.springframework.stereotype.Service;

@Service
@Profile("gcp")
public class PubSubMessageConsumer {

    private static final Logger logger = LoggerFactory.getLogger(PubSubMessageConsumer.class);

    @Autowired
    private ReplayService replayService;

    @Bean
    @ServiceActivator(inputChannel = "inputMessageChannel")
    public MessageHandler messageReceiver() {
        return message -> {
            String payload = message.getPayload().toString();
            replayService.replay(payload);
            logger.info("GCP Worker received message: {}", payload);
            BasicAcknowledgeablePubsubMessage originalMessage = message.getHeaders()
                    .get(GcpPubSubHeaders.ORIGINAL_MESSAGE, BasicAcknowledgeablePubsubMessage.class);
            if (originalMessage != null) {
                originalMessage.ack();
            }
        };
    }
}
