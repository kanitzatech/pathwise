package com.pathwise.backend.service;

import com.pathwise.backend.dto.RecommendationResponse;
import com.pathwise.backend.model.College;
import com.pathwise.backend.model.CutoffHistory;
import com.pathwise.backend.repository.CollegeRepository;
import com.pathwise.backend.repository.CourseRepository;
import com.pathwise.backend.repository.CutoffHistoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Service
public class RecommendationService {

    private final CutoffHistoryRepository cutoffHistoryRepository;
    private final CollegeRepository collegeRepository;
    private final CourseRepository courseRepository;

    private static final Pattern NON_ALNUM_PATTERN = Pattern.compile("[^a-z0-9]+");
    private static final Pattern SPACE_PATTERN = Pattern.compile("\\s+");

    private static final String DREAM = "dream";
    private static final String TARGET = "target";
    private static final String SAFE = "safe";

    private static final Map<String, List<String>> STRICT_COURSE_EQUIVALENTS = buildStrictCourseEquivalents();

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

    @Transactional(readOnly = true)
    public List<String> getAvailableCourses(String category, Double cutoff) {
        String normalizedCategory = normalizeCategory(category);
        if (normalizedCategory == null || cutoff == null) {
            return Collections.emptyList();
        }

        return cutoffHistoryRepository
                .findAvailableBranchesByCategoryAndCutoff(normalizedCategory, cutoff)
                .stream()
                .filter(Objects::nonNull)
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .map(this::mapToFullName)
                .distinct()
                .sorted(String::compareToIgnoreCase)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<RecommendationResponse> getRecommendations(String category, Double cutoff, String courseName, String district) {
        return flattenGrouped(getGroupedRecommendations(category, cutoff, courseName, district));
    }

    @Transactional(readOnly = true)
    public Map<String, List<RecommendationResponse>> getGroupedRecommendations(
            String category,
            Double cutoff,
            String courseName,
            String district
    ) {
        final Map<String, List<RecommendationResponse>> grouped = emptyGroupedResult();
        String normalizedCategory = normalizeCategory(category);
        if (normalizedCategory == null || cutoff == null || cutoff <= 0) {
            return grouped;
        }

        List<String> exactCourseCandidates = resolveExactCourseCandidates(courseName);
        if (exactCourseCandidates.isEmpty()) {
            return grouped;
        }

        final double maxEligibleCutoff = cutoff + 5.0;
        final String requestedDistrict = normalizeText(district);
        final Map<String, College> collegeByName = buildCollegeLookup();

        final Map<String, RecommendationResponse> uniqueByCollegeCourse = new LinkedHashMap<>();

        for (String candidate : exactCourseCandidates) {
            List<CutoffHistory> rows = cutoffHistoryRepository
                    .findRankedRecommendationsByCategoryCourseAndCutoff(normalizedCategory, candidate, maxEligibleCutoff);

            for (CutoffHistory row : rows) {
                double selectedCutoff = getCutoffByCategory(row, normalizedCategory);
                if (Double.isNaN(selectedCutoff)) {
                    continue;
                }

                String categoryBucket = classifyRecommendationType(cutoff, selectedCutoff);
                if (categoryBucket == null) {
                    continue;
                }

                College college = findCollegeDetails(row.getCollegeName(), collegeByName);
                String collegeDistrict = college == null ? null : safeTrim(college.getDistrict());
                String collegeType = college == null ? null : safeTrim(college.getCollegeType());

                if (!districtMatches(requestedDistrict, collegeDistrict, row.getCollegeName())) {
                    continue;
                }

                int collegeRank = resolveCollegeRank(row.getCollegeName(), collegeType);
                int probability = calculateProbability(cutoff, selectedCutoff);

                RecommendationResponse dto = RecommendationResponse.builder()
                        .collegeName(row.getCollegeName())
                        .courseName(mapToFullName(row.getBranch()))
                        .district(collegeDistrict)
                        .collegeType(collegeType)
                        .cutoff(selectedCutoff)
                        .probability(probability)
                        .category(categoryBucket)
                        .score((double) probability)
                        .recommendationType(categoryBucket)
                        .collegeRank(collegeRank)
                        .build();

                String uniqueKey = buildUniqueKey(dto.getCollegeName(), dto.getCourseName());
                RecommendationResponse existing = uniqueByCollegeCourse.get(uniqueKey);
                if (existing == null || compareRecommendations(dto, existing) < 0) {
                    uniqueByCollegeCourse.put(uniqueKey, dto);
                }
            }
        }

        List<RecommendationResponse> sorted = uniqueByCollegeCourse.values().stream()
                .sorted(this::compareRecommendations)
                .collect(Collectors.toList());

        grouped.put(DREAM, sorted.stream().filter(item -> DREAM.equals(resolveCategory(item))).collect(Collectors.toList()));
        grouped.put(TARGET, sorted.stream().filter(item -> TARGET.equals(resolveCategory(item))).collect(Collectors.toList()));
        grouped.put(SAFE, sorted.stream().filter(item -> SAFE.equals(resolveCategory(item))).collect(Collectors.toList()));

        return grouped;
    }

    private Map<String, List<RecommendationResponse>> emptyGroupedResult() {
        Map<String, List<RecommendationResponse>> result = new LinkedHashMap<>();
        result.put(DREAM, new ArrayList<>());
        result.put(TARGET, new ArrayList<>());
        result.put(SAFE, new ArrayList<>());
        return result;
    }

    private List<RecommendationResponse> flattenGrouped(Map<String, List<RecommendationResponse>> grouped) {
        List<RecommendationResponse> flat = new ArrayList<>();
        flat.addAll(grouped.getOrDefault(DREAM, Collections.emptyList()));
        flat.addAll(grouped.getOrDefault(TARGET, Collections.emptyList()));
        flat.addAll(grouped.getOrDefault(SAFE, Collections.emptyList()));
        return flat;
    }

    private int compareRecommendations(RecommendationResponse left, RecommendationResponse right) {
        int rankCompare = Integer.compare(safeRank(left), safeRank(right));
        if (rankCompare != 0) {
            return rankCompare;
        }

        int cutoffCompare = Double.compare(safeDouble(right.getCutoff()), safeDouble(left.getCutoff()));
        if (cutoffCompare != 0) {
            return cutoffCompare;
        }

        int scoreCompare = Integer.compare(safeProbability(right), safeProbability(left));
        if (scoreCompare != 0) {
            return scoreCompare;
        }

        return safeTrim(left.getCollegeName()).compareToIgnoreCase(safeTrim(right.getCollegeName()));
    }

    private int safeRank(RecommendationResponse value) {
        return value == null || value.getCollegeRank() == null ? 3 : value.getCollegeRank();
    }

    private double safeDouble(Double value) {
        return value == null ? 0.0 : value;
    }

    private int safeProbability(RecommendationResponse value) {
        if (value == null) {
            return 0;
        }
        if (value.getProbability() != null) {
            return value.getProbability();
        }

        double legacy = safeDouble(value.getScore());
        if (legacy >= 0.0 && legacy <= 1.0) {
            legacy = legacy * 100.0;
        }
        return (int) Math.round(Math.max(0.0, Math.min(100.0, legacy)));
    }

    private String resolveCategory(RecommendationResponse item) {
        if (item == null) {
            return SAFE;
        }

        String category = safeTrim(item.getCategory()).toLowerCase(Locale.ROOT);
        if (DREAM.equals(category) || TARGET.equals(category) || SAFE.equals(category)) {
            return category;
        }

        String legacyType = safeTrim(item.getRecommendationType()).toLowerCase(Locale.ROOT);
        if (DREAM.equals(legacyType) || TARGET.equals(legacyType) || SAFE.equals(legacyType)) {
            return legacyType;
        }

        return SAFE;
    }

    private String buildUniqueKey(String collegeName, String courseName) {
        return normalizeText(collegeName) + "|" + normalizeText(courseName);
    }

    private String classifyRecommendationType(double studentCutoff, double closingCutoff) {
        double margin = studentCutoff - closingCutoff;
        if (margin >= 10.0) {
            return SAFE;
        }
        if (margin >= 0.0) {
            return TARGET;
        }
        if (margin >= -5.0) {
            return DREAM;
        }
        return null;
    }

    private int calculateProbability(double studentCutoff, double closingCutoff) {
        double diff = studentCutoff - closingCutoff;
        double raw;

        if (diff >= 0.0) {
            raw = 85.0 - (diff * 1.5);
        } else {
            raw = 50.0 + (diff * 2.5);
        }

        double bounded = Math.max(5.0, Math.min(95.0, raw));
        return (int) Math.round(bounded);
    }

    private Map<String, College> buildCollegeLookup() {
        return collegeRepository.findAll().stream()
                .filter(Objects::nonNull)
                .filter(college -> college.getCollegeName() != null && !college.getCollegeName().isBlank())
                .collect(Collectors.toMap(
                        college -> normalizeText(college.getCollegeName()),
                        college -> college,
                        (left, right) -> left,
                        LinkedHashMap::new
                ));
    }

    private College findCollegeDetails(String rawCollegeName, Map<String, College> collegeByName) {
        if (rawCollegeName == null || rawCollegeName.isBlank() || collegeByName.isEmpty()) {
            return null;
        }

        String normalizedRaw = normalizeText(rawCollegeName);
        College exact = collegeByName.get(normalizedRaw);
        if (exact != null) {
            return exact;
        }

        String primaryName = normalizeText(extractPrimaryCollegeName(rawCollegeName));
        College primaryExact = collegeByName.get(primaryName);
        if (primaryExact != null) {
            return primaryExact;
        }

        return collegeByName.entrySet().stream()
                .filter(entry -> normalizedRaw.contains(entry.getKey())
                        || (!primaryName.isBlank() && entry.getKey().contains(primaryName)))
                .max(Comparator.comparingInt(entry -> entry.getKey().length()))
                .map(Map.Entry::getValue)
                .orElse(null);
    }

    private boolean districtMatches(String requestedDistrict, String collegeDistrict, String rawCollegeName) {
        if (requestedDistrict == null || requestedDistrict.isBlank()) {
            return true;
        }

        if (collegeDistrict != null && !collegeDistrict.isBlank()) {
            return normalizeText(collegeDistrict).equals(requestedDistrict);
        }

        String normalizedCollegeName = normalizeText(rawCollegeName);
        return normalizedCollegeName.contains(requestedDistrict);
    }

    private int resolveCollegeRank(String collegeName, String collegeType) {
        String normalizedName = normalizeText(collegeName);
        String normalizedType = normalizeText(collegeType);

        if (normalizedName.contains("anna university")
                || normalizedName.contains("ceg")
                || normalizedName.contains("mit campus")
                || normalizedName.contains("act campus")
                || normalizedName.contains("ssn")
                || normalizedName.contains("psg")
                || normalizedName.contains("coimbatore institute of technology")
                || normalizedName.equals("cit")
                || normalizedName.contains("srm institute of science and technology")
                || normalizedName.contains("srm university kattankulathur")) {
            return 1;
        }

        if (normalizedType.contains("autonomous") || normalizedName.contains("autonomous")) {
            return 2;
        }

        return 3;
    }

    private String extractPrimaryCollegeName(String collegeName) {
        String firstLine = safeTrim(collegeName).split("\\n")[0];
        return firstLine.split(",")[0].trim();
    }

    private String safeTrim(String value) {
        return value == null ? "" : value.trim();
    }

    private String normalizeText(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        String lower = value.toLowerCase(Locale.ROOT);
        String alnum = NON_ALNUM_PATTERN.matcher(lower).replaceAll(" ");
        return SPACE_PATTERN.matcher(alnum).replaceAll(" ").trim();
    }

    public double getCutoffByCategory(CutoffHistory ch, String category) {
        if (ch == null || category == null) {
            return Double.NaN;
        }

        switch (category.toUpperCase(Locale.ROOT)) {
            case "OC":
                return ch.getOcMin() == null ? Double.NaN : ch.getOcMin();
            case "BC":
                return ch.getBcMin() == null ? Double.NaN : ch.getBcMin();
            case "BCM":
                return ch.getBcmMin() == null ? Double.NaN : ch.getBcmMin();
            case "MBC":
                return ch.getMbcMin() == null ? Double.NaN : ch.getMbcMin();
            case "SC":
                return ch.getScMin() == null ? Double.NaN : ch.getScMin();
            case "SCA":
                return ch.getScaMin() == null ? Double.NaN : ch.getScaMin();
            case "ST":
                return ch.getStMin() == null ? Double.NaN : ch.getStMin();
            default:
                return Double.NaN;
        }
    }

    private String normalizeCategory(String category) {
        if (category == null || category.isBlank()) {
            return null;
        }
        String normalized = category.trim().toUpperCase(Locale.ROOT);
        switch (normalized) {
            case "OC":
            case "BC":
            case "BCM":
            case "MBC":
            case "SC":
            case "SCA":
            case "ST":
                return normalized;
            default:
                return null;
        }
    }

    private List<String> resolveExactCourseCandidates(String courseInput) {
        if (courseInput == null || courseInput.isBlank()) {
            return Collections.emptyList();
        }

        String cleaned = courseInput.trim();
        String normalized = normalizeText(cleaned);

        LinkedHashSet<String> candidates = new LinkedHashSet<>();
        candidates.add(cleaned);

        List<String> mapped = STRICT_COURSE_EQUIVALENTS.get(normalized);
        if (mapped != null) {
            candidates.addAll(mapped);
        }

        return candidates.stream()
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .collect(Collectors.toList());
    }

    private static Map<String, List<String>> buildStrictCourseEquivalents() {
        Map<String, List<String>> map = new LinkedHashMap<>();

        putCourseAliases(map,
                Arrays.asList("cse", "cs", "computer science engineering", "computer science and engineering"),
                Arrays.asList("CSE", "CS", "Computer Science Engineering", "Computer Science and Engineering"));

        putCourseAliases(map,
                Arrays.asList("it", "information technology"),
                Arrays.asList("IT", "Information Technology"));

        putCourseAliases(map,
                Arrays.asList("ece", "ec", "electronics and communication engineering"),
                Arrays.asList("ECE", "EC", "Electronics and Communication Engineering"));

        putCourseAliases(map,
                Arrays.asList("eee", "ee", "electrical and electronics engineering"),
                Arrays.asList("EEE", "EE", "Electrical and Electronics Engineering"));

        putCourseAliases(map,
                Arrays.asList("ad", "ai ds", "ai and data science", "artificial intelligence and data science", "ai&ds"),
                Arrays.asList("AD", "AI&DS", "Artificial Intelligence and Data Science"));

        putCourseAliases(map,
                Arrays.asList("am", "ai ml", "ai and machine learning", "artificial intelligence and machine learning"),
                Arrays.asList("AM", "Artificial Intelligence and Machine Learning"));

        putCourseAliases(map,
                Arrays.asList("me", "mechanical engineering"),
                Arrays.asList("ME", "Mechanical Engineering"));

        putCourseAliases(map,
                Arrays.asList("ce", "civil engineering", "civil"),
                Arrays.asList("CE", "Civil Engineering"));

        putCourseAliases(map,
                Arrays.asList("bme", "biomedical engineering", "biomedical"),
                Arrays.asList("BME", "Biomedical Engineering"));

        return Collections.unmodifiableMap(map);
    }

    private static void putCourseAliases(
            Map<String, List<String>> target,
            List<String> keys,
            List<String> aliases
    ) {
        for (String key : keys) {
            String normalized = key.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", " ").trim();
            target.put(normalized, aliases);
        }
    }

    private String mapToFullName(String rawName) {
        if (rawName == null) return "Unknown Course";
        String trimmed = rawName.trim();
        String lower = trimmed.toLowerCase(Locale.ROOT);
        switch (lower) {
            case "cs":
            case "cse":
            case "computer science engineering":
            case "computer science and engineering":
                return "Computer Science Engineering";
            case "ad":
            case "ai&ds":
            case "ai ds":
            case "artificial intelligence and data science":
                return "Artificial Intelligence and Data Science";
            case "am":
            case "ai ml":
            case "artificial intelligence and machine learning":
                return "Artificial Intelligence and Machine Learning";
            case "it":
            case "information technology":
                return "Information Technology";
            case "ec":
            case "ece":
            case "electronics and communication engineering":
                return "Electronics and Communication Engineering";
            case "ee":
            case "eee":
            case "electrical and electronics engineering":
                return "Electrical and Electronics Engineering";
            case "ei":
            case "eie":
                return "Electronics and Instrumentation Engineering";
            case "ce":
            case "ci":
            case "cl":
            case "civil":
                return "Civil Engineering";
            case "me":
            case "mechanical engineering":
                return "Mechanical Engineering";
            case "bm":
            case "bme":
            case "biomedical engineering":
                return "Biomedical Engineering";
            default:
                if (trimmed.length() <= 3 && !trimmed.contains(" ")) {
                    return "Specialization (" + trimmed.toUpperCase(Locale.ROOT) + ")";
                }
                return trimmed;
        }
    }
}
