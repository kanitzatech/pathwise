package com.pathwise.backend.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/")
    public Map<String, Object> root() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("service", "pathwise-backend");
        response.put("status", "ok");
        response.put("message", "Pathwise backend is running");
        return response;
    }

    @GetMapping("/api")
    public Map<String, Object> apiRoot() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("service", "pathwise-backend");
        response.put("status", "ok");
        response.put("message", "Pathwise API is running");
        return response;
    }
}
