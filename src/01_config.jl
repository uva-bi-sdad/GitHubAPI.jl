# Configuration Parameters
"""
    sdad_setup!(;db_user::AbstractString = "",
                 db_pwd::AbstractString = "",
                 github_login::AbstractString = "",
                 github_token::AbstractString = "",
                 inserver::Bool = false)
This function writes the configurations to `confs/config.simple`
# Arguments
- `db_user`: Your username for the `postgis_1` [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe) (i.e., your UVA computing ID).
- `db_pwd`: The password for the `postgis_1` [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe).
- `github_login`: Your GitHub login (handle).
- `github_token`: A 40 alphanumeric characters string. Obtain a GitHub personal access token [here](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line) (only select read-access is required).
- `inserver`: Whether the project is being used within the server (container) or not.
# Examples
## Good!
```
julia> sdad_setup!(db_user = "jbs3hp",
                   db_pwd = "MyVerySafePwd",
                   github_login = "Nosferican",
                   github_token = "0ipg0jvonteb54lv7j6cbgwn2snq3d3ac1pthxvz",
                   inserver = true)
😃
```
## Incomplete!
```
julia> sdad_setup!(db_user = "jbs3hp",
                   db_pwd = "MyVerySafePwd",
                   github_login = "Nosferican")
Warning: github_login has not been defined.
😞
```
# Updating the configuration file.
```
julia> using GitHubAPI
julia> sdad_setup!(db_user = "jbs3hp",
                   db_pwd = "MyVerySafePwd",
                   github_login = "Nosferican",
                   github_token = "0ipg0jvonteb54lv7j6cbgwn2snq3d3ac1pthxvz",
                   inserver = true)
julia> exit()
> julia
julia> using GitHubAPI # config up-to-date
```
!!! note
    Updating the configuration file requires a restart of the session.
"""
function sdad_setup!(;db_user::AbstractString = "",
                      db_pwd::AbstractString = "",
                      github_login::AbstractString = "",
                      github_token::AbstractString = "",
                      inserver::Bool = false)
    args = ["db_user", "db_pwd", "github_login", "github_token", "inserver"]
    isdir(joinpath(dirname(@__FILE__), "..", "confs")) || mkdir(joinpath(dirname(@__FILE__), "..", "confs"))
    isfile(joinpath(dirname(@__FILE__), "..", "confs", "config.simple")) ||
        touch(joinpath(dirname(@__FILE__), "..", "confs", "config.simple"))
    conf = ConfParse(joinpath(dirname(@__FILE__), "..", "confs", "config.simple"),
                     "simple")
    parse_conf!(conf)
    for (key, val) ∈ zip(args, [db_user, db_pwd, github_login, github_token, inserver])
        isempty(val) || commit!(conf, key, val)
    end
    save!(conf)
    notdefined = filter(key -> !haskey(conf, key),
                        args)
    foreach(key -> @warn("$key has not been defined."),
            notdefined)
    if isinteractive()
        if isempty(notdefined)
            println("😃")
        else
            println("😞")
        end
    end
end
isfile(joinpath(dirname(@__FILE__), "..", "confs", "config.simple")) ||
    sdad_setup!(db_user = get(ENV, "db_user", ""),
                db_pwd = get(ENV, "db_pwd", ""),
                github_login = get(ENV, "github_login", ""),
                github_token = get(ENV, "github_token", ""),
                inserver = get(ENV, "inserver", false))
const conf = ConfParse(joinpath(dirname(@__FILE__), "..", "confs", "config.simple"),
                       "simple");
parse_conf!(conf);
"""
    db_user::String
The username for the [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe) (i.e., your UVA computing ID).
"""
const db_user = haskey(conf, "db_user") ? retrieve(conf, "db_user") : "";
"""
    db_pwd::String
The password for the [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe).
"""
const db_pwd = haskey(conf, "db_pwd") ? retrieve(conf, "db_pwd") : "";
"""
    github_login::String
Your GitHub handle.
"""
const github_login = haskey(conf, "github_login") ? retrieve(conf, "github_login") : "";
"""
    github_header = Dict("User-Agent" => github_login)
Header for the GitHub API.
"""
const github_header = Dict("User-Agent" => github_login);
const github_token = haskey(conf, "github_token") ? retrieve(conf, "github_token") : "";
"""
    db_host = "postgis_1" | "sdad.policy-analytics.net"
Host for the [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe).
"""
const db_host = (haskey(conf, "inserver") &&
    retrieve(conf, "inserver") == "true") ? "postgis_1" : "sdad.policy-analytics.net";
"""
    db_port = 5432 | 5434
Port for the `postgis_1` in the [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe).
"""
const db_port = (haskey(conf, "inserver") &&
    retrieve(conf, "inserver") == "true") ? 5432 : 5434;
"""
    dbname = "oss"
Database for the Open-Source Software project.
"""
const dbname = "oss";
"""
    response_dtf = dateformat"d u y H:M:S Z"
HTTP responses require this datetime format.
"""
const response_dtf = dateformat"d u y H:M:S Z";
"""
    postgis_dtf = dateformat"yyyy-mm-dd HH:MM:SSzzzz"
HTTP responses require this datetime format.
"""
const postgis_dtf = dateformat"yyyy-mm-dd HH:MM:SSzzzz";
"""
    github_dtf = "yyyy-mm-ddTHH:MM:SSzzzz"
GitHub zoned datetime format.
"""
const github_dtf = "yyyy-mm-ddTHH:MM:SSzzzz";
# until = today() |>
#     yearmonthday |>
#     (dt -> ZonedDateTime(dt..., localzone()))
#     (td -> ZonedDateTime(year(td), month(td), day(td), localzone()));
"""
    until::ZonedDateTime
Until when should the scrapper query data. Currently at `"2019-08-15T00:00:00-04:00"`.
"""
const until = ZonedDateTime("2019-08-15T00:00:00-04:00",
                            github_dtf)
