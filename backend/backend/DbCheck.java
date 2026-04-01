import java.sql.*;
import java.util.Properties;

public class DbCheck {
    public static void main(String[] args) {
        String url = "jdbc:postgresql://34.14.221.0:5432/college_db?sslmode=require";
        Properties props = new Properties();
        props.setProperty("user", "postgres");
        props.setProperty("password", "vp0711");
        
        try (Connection conn = DriverManager.getConnection(url, props)) {
            System.out.println("--- DB CHECK ---");
            DatabaseMetaData meta = conn.getMetaData();
            
            System.out.println("Tables:");
            try (ResultSet rs = meta.getTables(null, "public", "%", new String[]{"TABLE"})) {
                while (rs.next()) {
                    System.out.println("- " + rs.getString("TABLE_NAME"));
                }
            }
            
            System.out.println("\nColumn types for 'colleges':");
            try (ResultSet rs = meta.getColumns(null, "public", "colleges", "college_id")) {
                if (rs.next()) {
                    System.out.println("college_id: " + rs.getString("TYPE_NAME"));
                }
            }
            
            System.out.println("\nSample cutoffs from 'cutoff_history':");
            try (Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery("SELECT closing_cutoff FROM cutoff_history WHERE closing_cutoff > 0 LIMIT 5")) {
                while (rs.next()) {
                    System.out.println("cutoff: " + rs.getDouble("closing_cutoff"));
                }
            }
            
            System.out.println("\nSample categories:");
            try (Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery("SELECT DISTINCT category FROM cutoff_history LIMIT 5")) {
                while (rs.next()) {
                    System.out.println("category: " + rs.getString("category"));
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
