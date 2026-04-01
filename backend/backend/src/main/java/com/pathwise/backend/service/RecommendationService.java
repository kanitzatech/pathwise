package com.pathwise.backend.service;

import com.pathwise.backend.dto.RecommendationResponse;
import com.pathwise.backend.repository.CollegeRepository;
import com.pathwise.backend.repository.CourseRepository;
import com.pathwise.backend.repository.CutoffHistoryRepository;
import com.pathwise.backend.repository.projection.RecommendationRow;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
public class RecommendationService {

    private final CutoffHistoryRepository cutoffHistoryRepository;
    private final CollegeRepository collegeRepository;
    private final CourseRepository courseRepository;

    /**
     * Maps a student's broad interest area to specific course-name keywords.
     * Keys are lowercase for case-insensitive matching.
     */
    private static final Map<String, List<String>> INTEREST_COURSE_MAP;

    static {
        Map<String, List<String>> map = new LinkedHashMap<>();
        map.put("software",    List.of("cse", "computer science", "computer science engineering", "it", "information technology"));
        map.put("electronics", List.of("ece", "eee", "electronics", "electrical"));
        map.put("mechanical",  List.of("me"));
        INTEREST_COURSE_MAP = Collections.unmodifiableMap(map);
    }

    public RecommendationService(
            CutoffHistoryRepository cutoffHistoryRepository,
            CollegeRepository collegeRepository,
            CourseRepository courseRepository
    ) {
        this.cutoffHistoryRepository = cutoffHistoryRepository;
        this.collegeRepository = collegeRepository;
        this.courseRepository = courseRepository;
    }

    @Transactional(readOnly = true)
    public List<String> getAllDistricts() {
        return collegeRepository.findDistinctDistricts();
    }

    @Transactional(readOnly = true)
    public List<String> getAllCourses() {
        return courseRepository.findDistinctCourseNames();
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
        Double normalizedCutoff = cutoff;
        Double lowerBound = normalizedCutoff - 20.0;

        List<String> rawCourseNames = resolveCourseNames(interest);

        String[] courseNamesArray = rawCourseNames.stream()
                .map(n -> "%" + n + "%")
                .toArray(String[]::new);

        if (rawCourseNames.isEmpty()) {
            return Map.of("results", Collections.emptyList(), "totalElements", 0, "currentPage", page);
        }

        Pageable pageable = PageRequest.of(page, size);

        final Page<RecommendationRow> pagedRows;
        if (district == null || district.isBlank()) {
            pagedRows = cutoffHistoryRepository.findRecommendationsAllDistricts(
                category,
                normalizedCutoff,
                lowerBound,
                courseNamesArray,
                pageable
            );
        } else {
            pagedRows = cutoffHistoryRepository.findRecommendationsByDistrict(
                category,
                normalizedCutoff,
                lowerBound,
                courseNamesArray,
                district,
                pageable
            );
        }

        List<RecommendationResponse> results = pagedRows.stream()
            .map(row -> {
                String type;
                double cOff = row.getClosingCutoff() == null ? 0.0 : row.getClosingCutoff();
                    double diff = normalizedCutoff - cOff;

                    if (diff <= 2) {
                        type = "DREAM";
                    } else if (diff <= 6) {
                        type = "TARGET";
                    } else {
                        type = "SAFE";
                    }

                    return RecommendationResponse.builder()
                            .collegeName(row.getCollegeName())
                            .courseName(mapToFullName(row.getCourseName()))
                            .district(row.getDistrict())
                            .collegeType(row.getCollegeType())
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
        response.put("totalElements", pagedRows.getTotalElements());
        response.put("currentPage", pagedRows.getNumber());

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
        if (mapped != null && !mapped.isEmpty()) {
            return mapped;
        }

        // If no broad mapping exists, treat user input as a direct course name filter.
        return List.of(interest.trim().toLowerCase());
    }
}
