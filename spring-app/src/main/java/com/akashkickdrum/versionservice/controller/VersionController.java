package com.akashkickdrum.versionservice.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Simple endpoint that returns the running version string. */
@RestController
public class VersionController {

    private static final String APP_VERSION = "Hey there!! This is Akash";

    @GetMapping("/version")
    public String version() {
        return APP_VERSION;
    }
}
