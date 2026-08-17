package com.ksbank.minibank.strict;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * KS-Bank mockup — COBOL to Java 1:1 구조 포팅 검증용 백엔드.
 *
 * <p>이 앱은 온라인(REST) 9개 CGI 프로그램의 진입점만 담당한다({@code online} 패키지).
 * 배치 10개 프로그램({@code batch} 패키지)은 이 Spring 컨텍스트와 무관하게 각자 자체
 * {@code main()}을 가진 독립 실행 클래스이며, {@code run_batch.sh}가 flat classpath로
 * 10번의 별도 JVM 프로세스로 실행한다(COBOL의 "프로그램 10개 = 실행파일 10개" 구조 대응).
 */
@SpringBootApplication
public class MinibankStrictApplication {
    public static void main(String[] args) {
        SpringApplication.run(MinibankStrictApplication.class, args);
    }
}
