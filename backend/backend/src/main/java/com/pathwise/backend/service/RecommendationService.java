package com.pathwise.backend.service;

import com.pathwise.backend.dto.RecommendationResponse;
import com.pathwise.backend.model.CutoffHistory;
import com.pathwise.backend.repository.CollegeRepository;
import com.pathwise.backend.repository.CutoffHistoryRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
public class RecommendationService {

    private final CutoffHistoryRepository cutoffHistoryRepository;
    private final CollegeRepository collegeRepository;

    /**
     * Maps a student's broad interest area to specific course-name keywords.
     * Keys are lowercase for case-insensitive matching.
     */
    private static final Map<String, List<String>> INTEREST_COURSE_MAP;

    static {
        Map<String, List<String>> map = new LinkedHashMap<>();
        map.put("software",    List.of("cse", "it", "computer science and engineering",
                                       "information technology"));
        map.put("electronics", List.of("ece", "eee", "electronics and communication engineering",
                                       "electrical and electronics engineering"));
        map.put("mechanical",  List.of("me", "mechanical engineering"));
        map.put("civil",       List.of("ce", "civil engineering"));
        map.put("biomedical",  List.of("bme", "biomedical engineering"));
        INTEREST_COURSE_MAP = Collections.unmodifiableMap(map);
    }

    public RecommendationService(CutoffHistoryRepository cutoffHistoryRepository, CollegeRepository collegeRepository) {
        this.cutoffHistoryRepository = cutoffHistoryRepository;
        this.collegeRepository = collegeRepository;
    }

    @Transactional(readOnly = true)
    public List<String> getAllDistricts() {
        return collegeRepository.findDistinctDistricts();
    }

    /**
     * Core recommendation logic:
     *  1. Resolve "interest" to a list of course name keywords.
     *  2. Query cutoff_history for matching category + cutoff + course names.
     *  3. Compute score = studentCutoff − closingCutoff.
     *  4. Sort ascending by score (closest match first).
     *  5. Return top results as DTOs.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getRecommendations(String category, Double cutoff, String interest, String district, String sortBy, int page, int size) {

        List<String> courseNames = resolveCourseNames(interest);

        if (courseNames.isEmpty()) {
            return Map.of("results", Collections.emptyList(), "totalElements", 0, "currentPage", page);
        }

        Double normalizedCutoff = cutoff / 2.0;
        Double lowerBound = Math.max(0.0, normalizedCutoff - 30.0);

        // Sorting
        Sort sort;
        if ("highest_cutoff".equalsIgnoreCase(sortBy)) {
            sort = Sort.by(Sort.Direction.DESC, "closingCutoff");
        } else {
            // Default best_match mapped safely natively if purely SQL paginated
            sort = Sort.by(Sort.Direction.DESC, "closingCutoff");
        }

        Pageable pageable = PageRequest.of(page, size, sort);

        Page<CutoffHistory> pagedRecords = cutoffHistoryRepository
                .findRecommendations(category, normalizedCutoff, lowerBound, courseNames, district, pageable);

        List<RecommendationResponse> results = pagedRecords.stream()
                .map(ch -> {
                    String type;
                    double cOff = ch.getClosingCutoff();
                    if (cOff >= normalizedCutoff) {
                        type = "DREAM";
                    } else if (cOff >= normalizedCutoff - 5) {
                        type = "TARGET";
                    } else {
                        type = "SAFE";
                    }

                    return RecommendationResponse.builder()
                            .collegeName(ch.getCollege().getCollegeName())
                            .courseName(mapToFullName(ch.getCourse().getCourseName()))
                            .district(ch.getCollege().getDistrict())
                            .collegeType(ch.getCollege().getCollegeType())
                            .cutoff(cOff)
                            .score(cOff)
                            .recommendationType(type)
                            .build();
                })
                .collect(Collectors.toList());

        // We must re-run mathematical sort for exact Best Match over the *current page* gracefully
        if ("best_match".equalsIgnoreCase(sortBy)) {
            results.sort((a, b) -> {
                double diffA = Math.abs(normalizedCutoff - a.getCutoff());
                double diffB = Math.abs(normalizedCutoff - b.getCutoff());
                return Double.compare(diffA, diffB);
            });
        }

        Map<String, Object> response = new HashMap<>();
        response.put("results", results);
        response.put("totalElements", pagedRecords.getTotalElements());
        response.put("currentPage", pagedRecords.getNumber());

        return response;
    }

    /**
     * Helper to map a raw string or code from DB to a clean, user-friendly full course name.
     */
    private String mapToFullName(String rawName) {
        if (rawName == null) return "Unknown Course";
        String lower = rawName.toLowerCase().trim();
        switch (lower) {
            case "cse":
            case "computer science and engineering":
                return "Computer Science Engineering";
            case "it":
            case "information technology":
                return "Information Technology";
            case "ece":
            case "electronics and communication engineering":
                return "Electronics and Communication Engineering";
            case "eee":
            case "electrical and electronics engineering":
                return "Electrical and Electronics Engineering";
            case "me":
            case "mechanical engineering":
                return "Mechanical Engineering";
            case "ce":
            case "civil engineering":
                return "Civil Engineering";
            case "bme":
            case "biomedical engineering":
                return "Biomedical Engineering";
            default:
                return rawName; // Fallback to raw DB name if not recognized
        }
    }

    /**
     * Resolves a broad interest keyword to a list of lowercase course-name search terms.
     *
     * @param interest  e.g. "Software", "Electronics", "Mechanical"
     * @return matching course name keywords, or empty list if interest is unknown
     */
    private List<String> resolveCourseNames(String interest) {
        if (interest == null || interest.isBlank()) {
            return Collections.emptyList();
        }
        List<String> mapped = INTEREST_COURSE_MAP.get(interest.trim().toLowerCase());
        return mapped != null ? mapped : Collections.emptyList();
    }
}
