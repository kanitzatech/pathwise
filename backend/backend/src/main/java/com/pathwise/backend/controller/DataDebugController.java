package com.pathwise.backend.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/debug")
public class DataDebugController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @GetMapping("/counts")
    public Map<String, Object> getCounts() {
        Map<String, Object> debug = new HashMap<>();
        try {
            debug.put("database", jdbcTemplate.queryForObject("SELECT current_database()", String.class));
            debug.put("schema", jdbcTemplate.queryForObject("SELECT current_schema()", String.class));
            
            debug.put("colleges_count", jdbcTemplate.queryForObject("SELECT COUNT(*) FROM colleges", Integer.class));
            debug.put("courses_count", jdbcTemplate.queryForObject("SELECT COUNT(*) FROM courses", Integer.class));
            debug.put("cutoff_history_count", jdbcTemplate.queryForObject("SELECT COUNT(*) FROM cutoff_history", Integer.class));
            
            // Sample categories
            debug.put("sample_categories", jdbcTemplate.queryForList("SELECT DISTINCT category FROM cutoff_history LIMIT 10", String.class));
            
            // Sample cutoffs
            debug.put("sample_cutoffs", jdbcTemplate.queryForList("SELECT closing_cutoff FROM cutoff_history WHERE closing_cutoff IS NOT NULL LIMIT 10", Double.class));
            
            // Available tables
            debug.put("available_tables", jdbcTemplate.queryForList("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'", String.class));
            
            // Table details
            debug.put("colleges_columns", jdbcTemplate.queryForList("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'colleges'"));
            
            // Available DBs on server
            debug.put("available_databases", jdbcTemplate.queryForList("SELECT datname FROM pg_database WHERE datistemplate = false", String.class));
            
        } catch (Exception e) {
            debug.put("error", e.getMessage());
        }
        return debug;
    }
}
