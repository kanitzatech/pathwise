package com.pathwise.backend.controller;

import com.pathwise.backend.dto.RecommendationResponse;
import com.pathwise.backend.service.RecommendationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

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

    @GetMapping("/courses")
    public ResponseEntity<List<String>> getCourses() {
        return ResponseEntity.ok(recommendationService.getAllCourses());
    }

    @GetMapping("/available-courses")
    public ResponseEntity<List<String>> getAvailableCourses(
            @RequestParam String category,
            @RequestParam Double cutoff) {
        return ResponseEntity.ok(recommendationService.getAvailableCourses(category, cutoff));
    }

    @GetMapping("/recommend")
    public ResponseEntity<List<RecommendationResponse>> recommend(
            @RequestParam String category,
            @RequestParam Double cutoff,
            @RequestParam String interest,
            @RequestParam(required = false) String district) {

        List<RecommendationResponse> response = recommendationService.getRecommendations(category, cutoff, interest, district);

        return ResponseEntity.ok(response);
    }
}
