"""
    GitHubAPI
Module used by the Social Decision and Analytics Division (SDAD) of
the Biocomplexity Institute and Initiative of the University of Virginia.

This module was designed for the Open-Source Software (OSS) project.
"""
module GitHubAPI
    using ConfParser: ConfParse, parse_conf!, retrieve, save!, commit!
    using Diana: GraphQLClient,
                 # HTTP
                 HTTP.Messages.Response, HTTP.request
    using JSON3: JSON3
    using LibPQ: Connection, execute
    using Parameters: @unpack
    using TimeZones: localzone, now, today, yearmonthday, ZonedDateTime,
                     # Dates
                     @dateformat_str, Dates.format
    foreach(include,
            file for file ∈ readdir(@__DIR__) if !isequal("GitHubAPI.jl", file))
    export get_licenses, dbconnect, parse_repos!, parse_commits!, sdad_setup!
end
