package com.example.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    private static final Logger logger = LoggerFactory.getLogger(HelloController.class);
    private final MessagePublisher messagePublisher;

    public HelloController(MessagePublisher messagePublisher) {
        this.messagePublisher = messagePublisher;
    }

    @GetMapping("/")
    public String home() {
        String msg = "Hello from "
                + (System.getenv("AWS_EXECUTION_ENV") != null ? System.getenv("AWS_EXECUTION_ENV") : "GCP");
        logger.info("Triggered home endpoint. Publishing message: {}", msg);
        messagePublisher.publish(msg);
        return "Hello World from Cloud Run!";
    }
}
