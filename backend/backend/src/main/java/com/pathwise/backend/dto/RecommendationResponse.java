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
    private Double score;
    private String recommendationType;
}
