provide-module search-doc %~

declare-option str search_doc_command %sh(
    if command -v "ag" >/dev/null 2>/dev/null; then
        printf "%s" "ag --only-matching --recurse --all-text"
    else
        printf "%s" "grep -RHnPo"
    fi
)

declare-option -hidden str search_doc_docstring "search-doc <topic>: search kak documentation for a topic"

# A shell script that returns kakoune command parameter completion options,
# one option per line.
declare-option -hidden str search_doc_candidates %(
    $kak_opt_search_doc_command '^\*.*[^:](?=::)' "$kak_runtime/doc/"*.asciidoc |
        ruby --disable-gems -e '
            strings_to_delete = ["*", "`", "'"'"'"]
            puts STDIN.each_line.map {|line|
                everything, file, needle = /^.*\/(\w+)\.asciidoc:\d+:(.*)/.match(line).to_a
                strings_to_delete.each {|s| needle.gsub!(s, "")}
                "#{file}:#{needle}"
            }
        '
)

# Define the 'search-doc' command in such a way that it computes parameter
# candidates on demand and then redefines itself.
define-command search-doc \
    -params 1 \
    -docstring "%opt(search_doc_docstring)" \
    -shell-script-candidates "%opt(search_doc_candidates)" \
%(
    search-doc-impl %arg(@)
    search-doc-redefine
)

# The actual implementation of the 'search-doc' command.
define-command search-doc-impl -hidden -params 1 \
%(
    search-doc-impl-impl "%sh(printf ""%s"" ""${1%%:*}"")" "%sh(printf ""%s"" ""${1#*:}"")"
)

# A helper command used by 'search-doc' to go to the desired documentation.
define-command search-doc-impl-impl -hidden -params 2 %(
    doc "%arg(1)"
    execute-keys "/^\Q%sh(echo ""$2"" | sed 's,<,SEARCH_DOC_LT,g; s,>,<gt>,g; s,SEARCH_DOC_LT,<lt>,g')\E$<ret>vv"
)

# A helper command that precomputes parameter candidates and then overrides the
# 'search-doc' command to use those candidates.
define-command search-doc-redefine -hidden %(
    declare-option -hidden str search_doc_evaluated_candidates %sh(
        # kak_opt_search_doc_command
        # kak_runtime
        eval "$kak_opt_search_doc_candidates" \
            | ruby --disable-gems -e '
                require "shellwords"
                puts STDIN.readlines.map(&:chomp).shelljoin
            '
    )
    define-command search-doc \
        -params 1 \
        -docstring "%opt(search_doc_docstring)" \
        -override \
        -shell-script-candidates %(
            eval set -- "$kak_opt_search_doc_evaluated_candidates"
            printf "%s\n" "$@"
        ) %(search-doc-impl %arg(@))
)

~
