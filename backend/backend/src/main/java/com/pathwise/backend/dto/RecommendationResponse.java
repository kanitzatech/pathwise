package com.pathwise.backend.dto;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecommendationResponse {

    private String collegeName;
    private String courseName;
    private String district;
    private String collegeType;
    private Double cutoff;
    private Integer probability;
    private String category;

    // Legacy fields retained for backward compatibility with older clients.
    private Double score;
    private String recommendationType;
    private Integer collegeRank;
}
