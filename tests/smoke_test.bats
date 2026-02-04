#!/usr/bin/env bats

setup() {
    # Load the main script in a way we can test its parts
    # Mocking log/die functions
    source "lib/core/logger.sh"
    source "lib/core/utils.sh"
}

@test "validate_port accepts correct ports" {
    run validate_port 8080
    [ "$status" -eq 0 ]
    
    run validate_port 65535
    [ "$status" -eq 0 ]
}

@test "validate_port rejects invalid ports" {
    run validate_port 70000
    [ "$status" -ne 0 ]
    
    run validate_port "abc"
    [ "$status" -ne 0 ]
}

@test "parse_proxy_url handles basic URL" {
    result=$(parse_proxy_url "http://localhost:8080")
    [ "$result" == "http|||localhost|8080" ]
}

@test "parse_proxy_url handles authentication" {
    result=$(parse_proxy_url "http://user:pass@1.2.3.4:1234")
    [ "$result" == "http|user|pass|1.2.3.4|1234" ]
}

@test "parse_proxy_url handles complex passwords with @" {
    result=$(parse_proxy_url "socks5://user:p@ssw@rd@proxy.com:1080")
    [ "$result" == "socks5|user|p@ssw@rd|proxy.com|1080" ]
}
