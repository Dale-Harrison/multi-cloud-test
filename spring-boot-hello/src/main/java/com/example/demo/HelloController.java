package com.example.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
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
        String sha = System.getenv("COMMIT_SHA");
        return String.format(
                "Welcome to the Multi-Cloud Spring Boot App! [Commit: %s] Use /publish?message=... to send a message.",
                sha);
    }

    @GetMapping("/publish")
    public String publish(@RequestParam(defaultValue = "Default message") String message) {
        String env = (System.getenv("AWS_EXECUTION_ENV") != null ? "AWS" : "GCP");
        String finalMsg = String.format("[%s] %s", env, message);
        logger.info("Publishing message: {}", finalMsg);
        messagePublisher.publish(finalMsg);
        return "Message published: " + finalMsg;
    }
}
