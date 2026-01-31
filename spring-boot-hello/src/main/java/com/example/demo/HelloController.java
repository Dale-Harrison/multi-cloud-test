package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import com.example.demo.MessagePublisher;

@RestController
public class HelloController {

    private final MessagePublisher messagePublisher;

    public HelloController(MessagePublisher messagePublisher) {
        this.messagePublisher = messagePublisher;
    }

    @GetMapping("/")
    public String home() {
        messagePublisher.publish("Hello from " + System.getenv("AWS_EXECUTION_ENV"));
        return "Hello World from Cloud Run!";
    }
}
