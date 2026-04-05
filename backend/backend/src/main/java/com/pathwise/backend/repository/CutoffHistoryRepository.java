package com.pathwise.backend.repository;

import com.pathwise.backend.model.CutoffHistory;
import com.pathwise.backend.model.CutoffHistoryId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CutoffHistoryRepository extends JpaRepository<CutoffHistory, CutoffHistoryId> {

          @Query(value = "SELECT * " +
           "FROM cutoff_history ch " +
              "WHERE ((:category = 'OC' AND ch.oc_min <= :cutoff) " +
              "OR (:category = 'BC' AND ch.bc_min <= :cutoff) " +
              "OR (:category = 'BCM' AND ch.bcm_min <= :cutoff) " +
              "OR (:category = 'MBC' AND ch.mbc_min <= :cutoff) " +
              "OR (:category = 'SC' AND ch.sc_min <= :cutoff) " +
              "OR (:category = 'SCA' AND ch.sca_min <= :cutoff) " +
              "OR (:category = 'ST' AND ch.st_min <= :cutoff)) " +
              "ORDER BY CASE " +
              "WHEN :category = 'OC' THEN ch.oc_min " +
              "WHEN :category = 'BC' THEN ch.bc_min " +
              "WHEN :category = 'BCM' THEN ch.bcm_min " +
              "WHEN :category = 'MBC' THEN ch.mbc_min " +
              "WHEN :category = 'SC' THEN ch.sc_min " +
              "WHEN :category = 'SCA' THEN ch.sca_min " +
              "WHEN :category = 'ST' THEN ch.st_min " +
           "END DESC",
           nativeQuery = true)
    List<CutoffHistory> findRecommendationsByCategoryAndCutoff(
        @Param("category") String category,
        @Param("cutoff") Double cutoff
    );

    @Query(value = "SELECT DISTINCT ch.branch " +
            "FROM cutoff_history ch " +
            "WHERE ((:category = 'OC' AND ch.oc_min <= :cutoff) " +
            "OR (:category = 'BC' AND ch.bc_min <= :cutoff) " +
            "OR (:category = 'BCM' AND ch.bcm_min <= :cutoff) " +
            "OR (:category = 'MBC' AND ch.mbc_min <= :cutoff) " +
            "OR (:category = 'SC' AND ch.sc_min <= :cutoff) " +
            "OR (:category = 'SCA' AND ch.sca_min <= :cutoff) " +
            "OR (:category = 'ST' AND ch.st_min <= :cutoff)) " +
            "ORDER BY ch.branch",
            nativeQuery = true)
    List<String> findAvailableBranchesByCategoryAndCutoff(
            @Param("category") String category,
            @Param("cutoff") Double cutoff
    );
}
