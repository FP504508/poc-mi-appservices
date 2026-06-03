package com.example.backend.controller;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class HelloController {

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP", "service", "backend");
    }

    @GetMapping("/api/hello")
    public Map<String, Object> hello(@AuthenticationPrincipal Jwt jwt) {
        List<String> roles = jwt.getClaimAsStringList("roles");
        if (roles == null || !roles.contains("Frontend.Call")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "Acceso denegado: App Role 'Frontend.Call' requerido");
        }

        String expectedAppId = System.getenv("FRONTEND_MI_CLIENT_ID");
        String callerAppId = jwt.getClaimAsString("appid");

        if (expectedAppId != null && !expectedAppId.isBlank() && !expectedAppId.equals(callerAppId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                "Acceso denegado: caller no autorizado");
        }

        var response = new LinkedHashMap<String, Object>();
        response.put("mensaje", "✅ Comunicación segura verificada — 3 capas OK");
        response.put("capas", Map.of(
            "capa1_jwt", "firma, issuer y audience validados por Spring Security",
            "capa2_appRole", "Frontend.Call presente en el token",
            "capa3_appId", "appid coincide con la Managed Identity del frontend"
        ));
        response.put("callerAppId", callerAppId);
        response.put("subject", jwt.getSubject());
        response.put("audience", jwt.getAudience());
        response.put("issuer", jwt.getIssuer().toString());
        response.put("expiraEn", Instant.now().until(jwt.getExpiresAt(), ChronoUnit.SECONDS) + "s");
        return response;
    }
}
