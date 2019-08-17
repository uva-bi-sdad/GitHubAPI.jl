# GitHubAPI.jl
SDAD internal application for GitHub data (OSS project)

[![License: ISC - Permissive License](https://img.shields.io/badge/License-ISC-green.svg)](https://img.shields.io/github/license/uva-bi-sdad/GitHubAPI.jl)
[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![Build Status](https://travis-ci.com/uva-bi-sdad/GitHubAPI.jl.svg?branch=master)](https://travis-ci.com/uva-bi-sdad/GitHubAPI.jl)
[![Documentation: dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://uva-bi-sdad.github.io/GitHubAPI.jl/dev)

Author/Maintainer: [José Bayoán Santiago Calderón](https://jbsc.netlify.com) ([Nosferican](https://github.com/Nosferican))

This application is developed by the Social and Decision Analytics Division of the [Biocomplexity Institute and Initiative](https://biocomplexity.virginia.edu/), University of Virginia.

[GitHubAPI.jl](https://github.com/uva-bi-sdad/GitHubAPI.jl) is an application to collect GitHub data on open-source projects (i.e., commit data for repositories with OSI-approved licenses).

## Prerequisites

- [Julia](https://julialang.org/)
- Internet access
- Access to the SDAD `postgis_1/oss` database (contact [Aaron Schroeder](mailto:ads7fg@virginia.edu))
- A [GitHub](https://Github.com/) account
- A GitHub [personal access token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line)

**Currently the application assumes one is working locally. This will change once the containers are set up.**

## Guide
- Check out documentation for learning how to use it and for reference.

*While the application is meant for internal use. The code is ISC licensed and may be useful for other people. Do feel free to fork the project / re-use the code for your purposes.*
