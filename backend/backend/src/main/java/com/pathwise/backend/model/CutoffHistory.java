package com.pathwise.backend.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "cutoff_history")
@IdClass(CutoffHistoryId.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CutoffHistory {

    @Id
    @Column(name = "college_code")
    private String collegeCode;

    @Id
    @Column(name = "branch")
    private String branch;

    @Column(name = "college_name")
    private String collegeName;

    @Column(name = "oc_max")
    private Double ocMax;

    @Column(name = "oc_min")
    private Double ocMin;

    @Column(name = "bcm_max")
    private Double bcmMax;

    @Column(name = "bcm_min")
    private Double bcmMin;

    @Column(name = "bc_max")
    private Double bcMax;

    @Column(name = "bc_min")
    private Double bcMin;

    @Column(name = "mbc_max")
    private Double mbcMax;

    @Column(name = "mbc_min")
    private Double mbcMin;

    @Column(name = "sc_max")
    private Double scMax;

    @Column(name = "sc_min")
    private Double scMin;

    @Column(name = "sca_max")
    private Double scaMax;

    @Column(name = "sca_min")
    private Double scaMin;

    @Column(name = "st_max")
    private Double stMax;

    @Column(name = "st_min")
    private Double stMin;
}
