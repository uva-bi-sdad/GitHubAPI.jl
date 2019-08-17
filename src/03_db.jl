# PostGIS
"""
    dbconnect()::Connection
Returns a connection to the `postgis_1` OSS [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe) (i.e., your UVA computing ID).

# Example

```
conn = dbconnect()
```
"""
function dbconnect()
    (@isdefined(db_user) && @isdefined(db_pwd)) ||
        throw(ArgumentError("Run sdad_setup! before making a connection."))
    Connection("""
               host = $db_host
               port = $db_port
               dbname = $dbname
               user = $db_user
               password = $db_pwd
               """)
end
"""
    get_licenses()::Vector{String}
List of SPDX ID for every OSI-approved license. (source: [SPDX](https://github.com/spdx/license-list-data))
"""
function get_licenses()
    conn = dbconnect()
    output = execute(conn, "select id from licenses where osi") |>
        (licenses -> getproperty.(licenses, :id))
    close(conn)
    output
end
# execute(conn,
#         """
#         create table universe.github_repos(
#           id int not null,
#           slug varchar not null,
#           created_at timestamptz not null,
#           is_archived bool not null,
#           is_fork bool not null,
#           is_mirror bool not null,
#           spdx varchar not null,
#           query char(52) not null,
#           as_of timestamptz not null,
#           primary key (id)
#         )
#         """)
# execute(conn,
#         """
#         create table universe.github_repos_tracker(
#           spdx varchar(36) not null,
#           query char(52) not null,
#           total int not null,
#           primary key (spdx, query)
#         )
#         """)
# execute(conn, "drop table universe.github_commits")
# execute(conn, "truncate table universe.github_commits")
# execute(conn,
#         """
#         create table universe.github_commits(
#           slug text not null,
#           author text,
#           sha char(40) not null,
#           additions int not null,
#           deletions int not null,
#           datetime timestamptz not null,
#           primary key (slug, sha)
#         )
#         """)
"""
    insert_record_repos_by_license!(conn::Connection,
                                    license::AbstractString,
                                    created_at::AbstractString,
                                    as_of::AbstractString,
                                    node)
It inserts each record to the `universe.github_repos` table.
"""
function insert_record_repos_by_license!(conn::Connection,
                                         license::AbstractString,
                                         created_at::AbstractString,
                                         as_of::AbstractString,
                                         node)
    @unpack isPrivate, databaseId, nameWithOwner, createdAt,
            isArchived, isFork, isMirror = node
    node.isPrivate && return
    execute(conn,
            """insert into universe.github_repos values(
               '$databaseId', '$nameWithOwner', '$createdAt',
               $isArchived, $isFork, $isMirror,
               '$license', '$created_at', '$as_of'
               )
               on conflict (id) do update set
               slug = excluded.slug,
               is_archived = excluded.is_archived,
               is_fork = excluded.is_fork,
               is_mirror = excluded.is_mirror,
               spdx = excluded.spdx,
               created_at = excluded.created_at,
               as_of = excluded.as_of
            """)
end
"""
    insert_commit!(conn::Connection, slug::AbstractString, node)
It inserts each record to the `universe.github_commits` table.
"""
function insert_commit!(conn::Connection, slug::AbstractString, node)
    @unpack author, oid, committedDate, additions, deletions = node
    user = author.user
    login = isnothing(user) ? "null" : "'$(user.login)'"
    execute(conn,
            """insert into universe.github_commits values(
               '$slug', $login, '$oid',
               $additions, $deletions, '$committedDate'
               )
               on conflict (slug, sha) do nothing
            """)
end
