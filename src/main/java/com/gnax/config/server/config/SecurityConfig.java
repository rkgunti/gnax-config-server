package com.gnax.config.server.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

	// Stateless Basic-auth API: CSRF must be off, otherwise POST /encrypt and /decrypt are rejected.
	@Bean
	SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
		return http
				.authorizeHttpRequests(auth -> auth
						.requestMatchers("/actuator/health/**", "/actuator/info").permitAll()
						.anyRequest().authenticated())
				.httpBasic(Customizer.withDefaults())
				.csrf(AbstractHttpConfigurer::disable)
				.build();
	}

}
