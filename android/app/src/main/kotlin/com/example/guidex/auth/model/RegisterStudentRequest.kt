package com.example.guidex.auth.model

data class RegisterStudentRequest(
    val name: String,
    val email: String,
    val password: String,
    val cutoff: Double,
    val category: String,
    val preferredCourse: String,
)
