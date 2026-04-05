package com.pathwise.backend.service;

import com.pathwise.backend.dto.RecommendationResponse;
import com.pathwise.backend.model.College;
import com.pathwise.backend.model.CutoffHistory;
import com.pathwise.backend.repository.CollegeRepository;
import com.pathwise.backend.repository.CourseRepository;
import com.pathwise.backend.repository.CutoffHistoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.regex.Pattern;
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

    private static final Pattern NON_ALNUM_PATTERN = Pattern.compile("[^a-z0-9]+");
    private static final Pattern SPACE_PATTERN = Pattern.compile("\\s+");

    static {
        Map<String, List<String>> map = new LinkedHashMap<>();
        map.put("software",    List.of(
                "cs", "cse", "computer science", "computer science engineering",
                "cb", "cd", "cg", "co", "cn", "cr", "cw", "cy", "cz", "sc",
                "csbs", "cst",
                "ad", "am", "artificial intelligence", "ai", "data science", "cyber security"
        ));
        map.put("computer science engineering", List.of(
                "cs", "cse", "computer science", "computer science engineering",
                "computer science and business systems", "csbs", "cst",
                "cb", "cd", "cg", "co", "cn", "cr", "cw", "cy", "cz", "sc",
                "cys", "artificial intelligence", "ai", "machine learning", "ai ml",
                "ai ds", "artificial intelligence and data science", "ad", "am",
                "data science", "cyber security", "iot"
        ));
        map.put("information technology", List.of("information technology", "it", "im", "iy", "information science", "ise"));
        map.put("electronics", List.of("ec", "ee", "ei", "ece", "eee", "eie", "electronics", "electrical", "communication"));
        map.put("electronics and communication engineering", List.of("ec", "ece", "electronics", "communication"));
        map.put("electrical and electronics engineering", List.of("ee", "eee", "electrical", "electronics"));
        map.put("mechanical",  List.of("me", "ma", "mc", "md", "mf", "mg", "mm", "mn", "mr", "ms", "mt", "mz", "mechanical"));
        map.put("mechanical engineering", List.of("me", "ma", "mc", "md", "mf", "mg", "mm", "mn", "mr", "ms", "mt", "mz", "mechanical"));
        map.put("civil", List.of("ce", "ci", "cl", "civil"));
        map.put("civil engineering", List.of("ce", "ci", "cl", "civil"));
        map.put("biomedical", List.of("bm", "bme", "bs", "by", "biomedical"));
        map.put("biomedical engineering", List.of("bm", "bme", "bs", "by", "biomedical"));
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
    public List<RecommendationResponse> getRecommendations(String category, Double cutoff, String interest, String district) {
        String normalizedCategory = normalizeCategory(category);
        if (normalizedCategory == null || cutoff == null) {
            return Collections.emptyList();
        }

        List<String> courseKeywords = resolveCourseNames(interest);
        if (courseKeywords.isEmpty()) {
            return Collections.emptyList();
        }

        String requestedDistrict = normalizeText(district);
        Map<String, College> collegeByName = buildCollegeLookup();

        List<CutoffHistory> rows = cutoffHistoryRepository.findRecommendationsByCategoryAndCutoff(normalizedCategory, cutoff);

        return rows.stream()
                .filter(ch -> branchMatchesInterest(ch.getBranch(), courseKeywords))
                .map(ch -> {
                    double selectedCutoff = getCutoffByCategory(ch, normalizedCategory);
                    if (Double.isNaN(selectedCutoff)) {
                        return null;
                    }

                    College college = findCollegeDetails(ch.getCollegeName(), collegeByName);
                    String collegeDistrict = college == null ? null : safeTrim(college.getDistrict());
                    String collegeType = college == null ? null : safeTrim(college.getCollegeType());

                    if (!districtMatches(requestedDistrict, collegeDistrict, ch.getCollegeName())) {
                        return null;
                    }

                    double score = calculateMatchScore(cutoff, selectedCutoff);

                    return RecommendationResponse.builder()
                            .collegeName(ch.getCollegeName())
                            .courseName(mapToFullName(ch.getBranch()))
                            .district(collegeDistrict)
                            .cutoff(selectedCutoff)
                            .score(score)
                            .collegeType(collegeType)
                            .build();
                })
                .filter(Objects::nonNull)
                .filter(dto -> dto.getCollegeName() != null && dto.getCourseName() != null && dto.getCutoff() != null)
                .sorted(Comparator
                        .comparing(RecommendationResponse::getScore, Comparator.nullsLast(Comparator.reverseOrder()))
                        .thenComparing(RecommendationResponse::getCutoff, Comparator.nullsLast(Comparator.reverseOrder())))
                .collect(Collectors.toList());
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

    private double calculateMatchScore(double studentCutoff, double collegeCutoff) {
        if (studentCutoff <= 0) {
            return 0.0;
        }

        double gap = Math.max(0.0, studentCutoff - collegeCutoff);
        double relativeGap = gap / studentCutoff;
        double score = (1.0 - relativeGap) * 100.0;
        return Math.max(0.0, Math.min(100.0, roundToTwoDecimals(score)));
    }

    private double roundToTwoDecimals(double value) {
        return Math.round(value * 100.0) / 100.0;
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

    /**
     * Helper to map a raw string or code from DB to a clean, user-friendly full course name.
     */
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
            case "cb":
            case "csbs":
            case "computer science and business systems":
                return "Computer Science and Business Systems";
            case "cd":
                return "Computer Science and Design";
            case "cg":
                return "Computer Science and Engineering (AI and ML)";
            case "co":
                return "Computer Science and Engineering (IoT)";
            case "cn":
                return "Computer Science and Engineering (Networks)";
            case "cr":
            case "sc":
                return "Computer Science and Engineering (Cyber Security)";
            case "cw":
                return "Computer Science and Engineering (Data Science)";
            case "cz":
                return "Computer Science and Engineering (Specialization)";
            case "cst":
                return "Computer Science and Technology";
            case "cys":
            case "cy":
                return "Cyber Security";
            case "ad":
            case "ai&ds":
            case "ai ds":
            case "artificial intelligence and data science":
                return "Artificial Intelligence and Data Science";
            case "am":
            case "cse (ai&ml)":
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
            case "ma":
            case "mc":
            case "md":
            case "mf":
            case "mg":
            case "mm":
            case "mn":
            case "mr":
            case "ms":
            case "mt":
            case "mz":
            case "mechanical engineering":
                return "Mechanical Engineering";
            case "ae":
                return "Aeronautical Engineering";
            case "ag":
                return "Agricultural Engineering";
            case "au":
                return "Automobile Engineering";
            case "bt":
                return "Biotechnology";
            case "ch":
                return "Chemical Engineering";
            case "bm":
            case "bme":
            case "bs":
            case "by":
            case "biomedical engineering":
                return "Biomedical Engineering";
            case "ra":
            case "rm":
                return "Robotics and Automation";
            case "tc":
                return "Textile Chemistry";
            case "tx":
            case "tt":
            case "ht":
                return "Textile Technology";
            case "pc":
            case "pm":
            case "pa":
            case "petro":
            case "petrochemical e":
                return "Petrochemical Engineering";
            case "ph":
                return "Pharmaceutical Technology";
            case "pt":
            case "pp":
            case "rp":
                return "Polymer and Plastics Technology";
            default:
                if (trimmed.length() <= 3 && !trimmed.contains(" ")) {
                    return "Specialization (" + trimmed.toUpperCase(Locale.ROOT) + ")";
                }
                return rawName; // Fallback to raw DB name if not recognized
        }
    }

    private boolean branchMatchesInterest(String branch, List<String> courseKeywords) {
        if (branch == null || courseKeywords == null || courseKeywords.isEmpty()) {
            return false;
        }
        String normalizedBranch = normalizeText(branch);

        for (String keyword : courseKeywords) {
            String normalizedKeyword = normalizeText(keyword);
            if (normalizedKeyword.isBlank()) {
                continue;
            }

            if (normalizedKeyword.length() <= 2) {
                List<String> branchTokens = Arrays.asList(normalizedBranch.split(" "));
                if (branchTokens.contains(normalizedKeyword)) {
                    return true;
                }
                continue;
            }

            if (normalizedBranch.contains(normalizedKeyword)) {
                return true;
            }
        }

        return false;
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

        String normalizedInterest = normalizeText(interest);
        List<String> mapped = INTEREST_COURSE_MAP.get(normalizedInterest);
        if (mapped != null && !mapped.isEmpty()) {
            return mapped.stream().map(this::normalizeText).distinct().collect(Collectors.toList());
        }

        for (Map.Entry<String, List<String>> entry : INTEREST_COURSE_MAP.entrySet()) {
            if (normalizedInterest.contains(entry.getKey()) || entry.getKey().contains(normalizedInterest)) {
                return entry.getValue().stream().map(this::normalizeText).distinct().collect(Collectors.toList());
            }
        }

        // If no broad mapping exists, treat user input as a direct course name filter.
        return List.of(normalizedInterest);
    }
}
