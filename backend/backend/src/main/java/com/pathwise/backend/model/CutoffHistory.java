package com.pathwise.backend.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "cutoff_history")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CutoffHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "cutoff_id")
    private Integer cutoffId;

    @Column(name = "year")
    private Integer year;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "college_id", nullable = false)
    private College college;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @Column(name = "category")
    private String category;

    @Column(name = "opening_cutoff")
    private Double openingCutoff;

    @Column(name = "closing_cutoff")
    private Double closingCutoff;
}
