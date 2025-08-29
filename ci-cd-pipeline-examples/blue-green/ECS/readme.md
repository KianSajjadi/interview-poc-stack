# ECS Blue/Green workflows

This triggers codedeploy to use a canary style traffic shifting pattern. CodeDeploy is is always blue/green (using two target groups) but I adopted a Canary-style traffic shift to the green tasks rather than all at once style