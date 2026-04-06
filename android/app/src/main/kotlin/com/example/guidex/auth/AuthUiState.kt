package com.example.guidex.auth

import com.example.guidex.auth.model.StudentProfile

data class AuthUiState(
    val isLoading: Boolean = false,
    val isLoggedIn: Boolean = false,
    val profile: StudentProfile? = null,
    val error: AuthFailure? = null,
)
