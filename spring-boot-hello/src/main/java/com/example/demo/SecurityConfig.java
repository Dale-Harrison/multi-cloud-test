package com.example.demo;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;

import static org.springframework.security.config.Customizer.withDefaults;

import org.springframework.security.oauth2.client.oidc.web.logout.OidcClientInitiatedLogoutSuccessHandler;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http, ClientRegistrationRepository clientRegistrationRepository)
            throws Exception {
        OidcClientInitiatedLogoutSuccessHandler logoutSuccessHandler = new OidcClientInitiatedLogoutSuccessHandler(
                clientRegistrationRepository);

        // Sets the `returnTo` query parameter to the base URL of the application
        logoutSuccessHandler.setPostLogoutRedirectUri("{baseUrl}");

        http
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/error", "/favicon.ico").permitAll()
                        .requestMatchers("/actuator/health").permitAll()
                        .anyRequest().authenticated())
                .csrf(csrf -> csrf.disable())
                .oauth2Login(withDefaults())
                .oauth2ResourceServer(oauth2 -> oauth2.jwt(withDefaults()))
                .logout(logout -> logout
                        .logoutSuccessHandler(logoutSuccessHandler)
                        .invalidateHttpSession(true)
                        .clearAuthentication(true)
                        .permitAll());
        return http.build();
    }
}
