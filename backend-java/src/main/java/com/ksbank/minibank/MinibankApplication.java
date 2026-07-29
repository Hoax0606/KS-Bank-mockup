package com.ksbank.minibank;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** KS-Bank mockup ASIS 백엔드 (Java / Spring Boot + PostgreSQL, RAW 바이트 보존). */
@SpringBootApplication
public class MinibankApplication {
    public static void main(String[] args) {
        SpringApplication.run(MinibankApplication.class, args);
    }
}
