package com.pathwise.backend.repository;

import com.pathwise.backend.model.CutoffHistory;
import com.pathwise.backend.repository.projection.RecommendationRow;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface CutoffHistoryRepository extends JpaRepository<CutoffHistory, Integer> {

    @Query(value = "SELECT c.college_name AS collegeName, " +
           "cr.course_name AS courseName, " +
           "c.district AS district, " +
           "c.college_type AS collegeType, " +
           "ch.closing_cutoff AS closingCutoff " +
           "FROM cutoff_history ch " +
           "JOIN colleges c ON ch.college_id = c.college_id " +
           "JOIN courses cr ON ch.course_id = cr.course_id " +
           "WHERE (LOWER(ch.category) = LOWER(:category)) " +
           "AND (ch.closing_cutoff <= :normalizedCutoff) " +
           "AND (ch.closing_cutoff >= :lowerBound) " +
           "AND (cr.course_name ILIKE ANY (CAST(:courseNames AS text[])))",
           countQuery = "SELECT COUNT(*) FROM cutoff_history ch " +
           "JOIN colleges c ON ch.college_id = c.college_id " +
           "JOIN courses cr ON ch.course_id = cr.course_id " +
           "WHERE (LOWER(ch.category) = LOWER(:category)) " +
           "AND (ch.closing_cutoff <= :normalizedCutoff) " +
           "AND (ch.closing_cutoff >= :lowerBound) " +
           "AND (cr.course_name ILIKE ANY (CAST(:courseNames AS text[])))",
           nativeQuery = true)
    Page<RecommendationRow> findRecommendationsAllDistricts(
        @Param("category") String category,
        @Param("normalizedCutoff") Double normalizedCutoff,
        @Param("lowerBound") Double lowerBound,
        @Param("courseNames") String[] courseNames,
        Pageable pageable
    );

    @Query(value = "SELECT c.college_name AS collegeName, " +
           "cr.course_name AS courseName, " +
           "c.district AS district, " +
           "c.college_type AS collegeType, " +
           "ch.closing_cutoff AS closingCutoff " +
           "FROM cutoff_history ch " +
           "JOIN colleges c ON ch.college_id = c.college_id " +
           "JOIN courses cr ON ch.course_id = cr.course_id " +
           "WHERE (LOWER(ch.category) = LOWER(:category)) " +
           "AND (ch.closing_cutoff <= :normalizedCutoff) " +
           "AND (ch.closing_cutoff >= :lowerBound) " +
           "AND (cr.course_name ILIKE ANY (CAST(:courseNames AS text[]))) " +
           "AND (LOWER(c.district) = LOWER(:district))",
           countQuery = "SELECT COUNT(*) FROM cutoff_history ch " +
           "JOIN colleges c ON ch.college_id = c.college_id " +
           "JOIN courses cr ON ch.course_id = cr.course_id " +
           "WHERE (LOWER(ch.category) = LOWER(:category)) " +
           "AND (ch.closing_cutoff <= :normalizedCutoff) " +
           "AND (ch.closing_cutoff >= :lowerBound) " +
           "AND (cr.course_name ILIKE ANY (CAST(:courseNames AS text[]))) " +
           "AND (LOWER(c.district) = LOWER(:district))",
           nativeQuery = true)
    Page<RecommendationRow> findRecommendationsByDistrict(
        @Param("category") String category,
        @Param("normalizedCutoff") Double normalizedCutoff,
        @Param("lowerBound") Double lowerBound,
        @Param("courseNames") String[] courseNames,
        @Param("district") String district,
        Pageable pageable
    );
}
