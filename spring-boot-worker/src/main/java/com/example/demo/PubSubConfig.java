package com.example.demo;

import com.google.cloud.spring.pubsub.core.PubSubTemplate;
import com.google.cloud.spring.pubsub.integration.inbound.PubSubInboundChannelAdapter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.integration.channel.DirectChannel;
import org.springframework.messaging.MessageChannel;
import org.springframework.boot.CommandLineRunner;
import com.google.cloud.spring.pubsub.support.BasicAcknowledgeablePubsubMessage;
import com.google.cloud.spring.pubsub.support.GcpPubSubHeaders;
import org.springframework.integration.acks.AckUtils;
import org.springframework.integration.acks.AcknowledgmentCallback;

@Configuration
@Profile("gcp")
public class PubSubConfig {

    @Bean
    public MessageChannel inputMessageChannel() {
        return new DirectChannel();
    }

    /*
     * @Bean
     * public PubSubInboundChannelAdapter messageChannelAdapter(
     * 
     * @Qualifier("inputMessageChannel") MessageChannel inputChannel,
     * PubSubTemplate pubSubTemplate) {
     * PubSubInboundChannelAdapter adapter = new
     * PubSubInboundChannelAdapter(pubSubTemplate, "hello-sub");
     * adapter.setOutputChannel(inputChannel);
     * adapter.setAckMode(com.google.cloud.spring.pubsub.integration.AckMode.MANUAL)
     * ;
     * adapter.setAutoStartup(false); // Disable auto-startup to prevent blocking
     * return adapter;
     * }
     * 
     * @Bean
     * public CommandLineRunner startupRunner(PubSubInboundChannelAdapter adapter) {
     * return args -> {
     * new Thread(() -> {
     * System.out.println("Starting PubSubAdapter in background thread...");
     * adapter.start();
     * System.out.println("PubSubAdapter started.");
     * }).start();
     * };
     * }
     */
}
