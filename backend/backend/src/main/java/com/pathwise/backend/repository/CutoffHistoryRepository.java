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
    @Query(value = "SELECT ch.* FROM cutoff_history ch " +
           "JOIN colleges c ON ch.college_id = c.college_id " +
           "JOIN courses cr ON ch.course_id = cr.course_id " +
           "WHERE (LOWER(ch.category) = LOWER(:category)) " +
           "AND (ch.closing_cutoff <= :normalizedCutoff) " +
           "AND (ch.closing_cutoff >= :lowerBound) " +
           "AND (cr.course_name ILIKE ANY (CAST(:courseNames AS text[]))) " +
           "AND (:district IS NULL OR :district = '' OR c.district ILIKE '%' || :district || '%')",
           countQuery = "SELECT COUNT(*) FROM cutoff_history ch " +
           "JOIN colleges c ON ch.college_id = c.college_id " +
           "JOIN courses cr ON ch.course_id = cr.course_id " +
           "WHERE (LOWER(ch.category) = LOWER(:category)) " +
           "AND (ch.closing_cutoff <= :normalizedCutoff) " +
           "AND (ch.closing_cutoff >= :lowerBound) " +
           "AND (cr.course_name ILIKE ANY (CAST(:courseNames AS text[]))) " +
           "AND (:district IS NULL OR :district = '' OR c.district ILIKE '%' || :district || '%')",
           nativeQuery = true)
    Page<CutoffHistory> findRecommendations(
            @Param("category") String category,
            @Param("normalizedCutoff") Double normalizedCutoff,
            @Param("lowerBound") Double lowerBound,
            @Param("courseNames") String[] courseNames,
            @Param("district") String district,
            Pageable pageable
    );
}
