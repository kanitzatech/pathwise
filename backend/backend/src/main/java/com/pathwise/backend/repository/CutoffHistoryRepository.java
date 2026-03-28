package com.pathwise.backend.repository;

import com.pathwise.backend.model.CutoffHistory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CutoffHistoryRepository extends JpaRepository<CutoffHistory, Integer> {

    /**
     * Finds cutoff records where:
     *   - category matches (case-insensitive)
     *   - closing_cutoff <= the student's cutoff mark
     *   - closing_cutoff >= lowerBound (avoids suggesting extremely low tiered colleges)
     *   - course_name is in the given list of mapped courses
     *
     * Results are eagerly joined with College and Course to avoid N+1 and sorted automatically via DB.
     */
    @Query(value = "SELECT ch FROM CutoffHistory ch " +
           "JOIN FETCH ch.college c " +
           "JOIN FETCH ch.course cr " +
           "WHERE LOWER(ch.category) = LOWER(:category) " +
           "AND ch.closingCutoff <= :normalizedCutoff " +
           "AND ch.closingCutoff >= :lowerBound " +
           "AND LOWER(cr.courseName) IN :courseNames " +
           "AND (COALESCE(:district, '') = '' OR LOWER(c.district) = LOWER(:district))",
           countQuery = "SELECT COUNT(ch) FROM CutoffHistory ch " +
           "JOIN ch.college c " +
           "JOIN ch.course cr " +
           "WHERE LOWER(ch.category) = LOWER(:category) " +
           "AND ch.closingCutoff <= :normalizedCutoff " +
           "AND ch.closingCutoff >= :lowerBound " +
           "AND LOWER(cr.courseName) IN :courseNames " +
           "AND (COALESCE(:district, '') = '' OR LOWER(c.district) = LOWER(:district))")
    Page<CutoffHistory> findRecommendations(
            @Param("category") String category,
            @Param("normalizedCutoff") Double normalizedCutoff,
            @Param("lowerBound") Double lowerBound,
            @Param("courseNames") List<String> courseNames,
            @Param("district") String district,
            Pageable pageable
    );
}
