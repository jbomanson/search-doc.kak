provide-module search-doc %~

declare-option -hidden str search_doc_docstring "search-doc <topic>: search kak documentation for a topic"

# A shell script that returns kakoune command parameter completion options,
# one option per line.
# This must be safe to include in %sh(...) expansions.
# See also: %val(runtime)/tools/doc.kak
declare-option -hidden str search_doc_candidates %(
    set --
    for directory in \
        "${kak_config}/autoload/" \
        "${kak_runtime}/doc/" \
        "${kak_runtime}/rc/"
    do
        test -d "$directory" && set -- "$@" "$directory"
    done
    if test $# -eq 0; then
        printf '%s\n' 'search-doc: found no documentation files'
        exit 1
    fi | tee /dev/stderr
    find -L "$@" -type f -name "*.asciidoc" |
        ruby --disable-gems -e '
            strings_to_delete = ["*", "`", "'"'"'"]
            puts(
              STDIN.each_line(chomp: true).flat_map do |filename|
                simplified_file = filename[/([^\/]*)\.asciidoc$/, 1]
                most_recent_title = nil
                File.open(filename) do |io|
                  io.each_line.map do |content|
                    next unless content = content[/^\*.*[^:](?=::)|^=+ .*/]
                    if title = content[/^=+ (.*)/, 1]
                      most_recent_title = title
                      nil
                    elsif most_recent_title
                      strings_to_delete.each {|s| content.gsub!(s, "")}
                      [simplified_file, content, most_recent_title]
                    end
                  end.compact
                end
              end.map do |simplified_file, content, title|
                "#{content} (#{simplified_file}: #{title})"
              end.to_a
            )
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
%[
    search-doc-impl-impl %sh[
        content_and_title="${1##* (}"
        content_and_title="${content_and_title%)}"
        printf "%s" "${content_and_title%: *}"
    ] %sh[
        content_and_title="${1##* (}"
        content_and_title="${content_and_title%)}"
        printf "%s" "${content_and_title##*: }"
    ] %sh[
        printf "%s" "${1% (*}"
    ]
]

# A helper command used by 'search-doc' to go to the desired documentation.
# Arguments: <filename> <coarse-topic> <fine-topic>
define-command search-doc-impl-impl -hidden -params 3 %(
    doc "%arg(1)"
    evaluate-commands %(
        try %(
            # At the time of writing, this fails for (mapping: Mappable keys), which is
            # curiously missing from rendered kakoune documentation.
            set-register / "^\Q%arg(2)\E$"
            execute-keys /<ret>
        )
        set-register / "^\Q%arg(3)\E$"
        execute-keys /<ret>vv
    )
)

# A helper command that precomputes parameter candidates and then overrides the
# 'search-doc' command to use those candidates.
define-command search-doc-redefine -hidden %(
    evaluate-commands \
        declare-option -hidden str search_doc_evaluated_candidates \
            "%%sh(%opt(search_doc_candidates))"
    define-command search-doc \
        -params 1 \
        -docstring "%opt(search_doc_docstring)" \
        -override \
        -shell-script-candidates %(
            printf "%s\n" "$kak_opt_search_doc_evaluated_candidates"
        ) %(search-doc-impl %arg(@))
)

~
