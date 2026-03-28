package com.pathwise.backend.controller;

import com.pathwise.backend.dto.RecommendationResponse;
import com.pathwise.backend.service.RecommendationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class RecommendationController {

    private final RecommendationService recommendationService;

    public RecommendationController(RecommendationService recommendationService) {
        this.recommendationService = recommendationService;
    }

    /**
     * GET /api/recommend?category=OC&cutoff=190&interest=Software
     *
     * @param category  e.g. OC, BC, MBC, SC, ST
     * @param cutoff    the student's cutoff mark
     * @param interest  broad interest area (Software, Electronics, Mechanical, etc.)
     * @return sorted list of college-course recommendations
     */
    @GetMapping("/districts")
    public ResponseEntity<List<String>> getDistricts() {
        return ResponseEntity.ok(recommendationService.getAllDistricts());
    }

    @GetMapping("/recommend")
    public ResponseEntity<Map<String, Object>> recommend(
            @RequestParam String category,
            @RequestParam Double cutoff,
            @RequestParam String interest,
            @RequestParam(required = false) String district,
            @RequestParam(required = false, defaultValue = "best_match") String sortBy,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Map<String, Object> response =
                recommendationService.getRecommendations(category, cutoff, interest, district, sortBy, page, size);

        return ResponseEntity.ok(response);
    }
}
