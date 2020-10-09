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
# This must be safe to include in %sh(...) expansions.
# See also: %val(runtime)/tools/doc.kak
declare-option -hidden str search_doc_candidates %(
    find -L \
        "${kak_config}/autoload/" \
        "${kak_runtime}/doc/" \
        "${kak_runtime}/rc/" \
        -type f -name "*.asciidoc" \
        -exec $kak_opt_search_doc_command '^\*.*[^:](?=::)|^=+ .*' '{}' + |
        ruby --disable-gems -e '
            strings_to_delete = ["*", "`", "'"'"'"]
            puts(
                STDIN.each_line.map do |line|
                    /^.*\/(.*?)\.asciidoc:\d+:(.*)/.match(line).to_a[1..-1]
                end.group_by(&:first).flat_map do |file, file_and_content_pairs|
                    most_recent_title = nil
                    file_and_content_pairs.map do |_, content|
                        if title = content[/^=+ (.*)/, 1]
                            most_recent_title = title
                            nil
                        elsif most_recent_title
                            strings_to_delete.each {|s| content.gsub!(s, "")}
                            [file, content, most_recent_title]
                        end
                    end.compact
                end.map do |file, content, title|
                    "#{content} (#{file}: #{title})"
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
