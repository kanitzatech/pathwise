package com.pathwise.backend.repository.projection;

public interface RecommendationRow {
    String getCollegeName();
    String getCourseName();
    String getDistrict();
    String getCollegeType();
    Double getClosingCutoff();
}
